use Cro::HTTP::BodyParserSelector;
use Cro::HTTP::Message;
use Cro::Uri::HTTP;

class X::Cro::HTTP::Request::Incomplete is Exception {
    has $.missing;
    method message() {
        "Cannot serialize a HTTP request missing its $!missing"
    }
}

class Cro::HTTP::Request does Cro::HTTP::Message {
    has Cro::Uri::HTTP $!cached-uri;
    has Str $!cached-uri-target = '';
    has Cro::HTTP::BodyParserSelector $.body-parser-selector is rw =
        Cro::HTTP::BodyParserSelector::RequestDefault;

    # This one is a little interesting. Per RFC 7230, "The method token
    # indicates the request method to be performed on the target resource.
    # The request method is case-sensitive." All of the registered names are
    # uppercase. While it is feasible that some day somebody might decide to
    # introduce a custom lower-case one, that seems massively less likely
    # than somebody sticking 'get' instead of 'GET' into a request and having
    # a server (quite rightly) choke on it. So, we'll limit it here. Also, in
    # theory a whole bunch of other chars can be in the method, but again, that
    # seems relatively unlikley to happen in reality.
    subset Method of Str where /^<[A..Z]>+$/;
    has Method $.method is rw;

    # This is relativley liberal, just enforcing Latin-1 and no controls. As it
    # rules out space, we can't malform messages.
    subset Target of Str where /^<[\x21..\xFF]>+$/;
    has Target $.target is rw;

    multi method Str(Cro::HTTP::Request:D:) {
        die X::Cro::HTTP::Request::Incomplete.new(:missing<method>) unless $!method;
        die X::Cro::HTTP::Request::Incomplete.new(:missing<target>) unless $!target;
        my $version = self.http-version // (self.has-header('Host') ?? '1.1' !! '1.0');
        my $headers = self!headers-str();
        "$.method $.target HTTP/$version\r\n$headers\r\n"
    }

    method path() {
        self!ensure-cached-uri();
        $!cached-uri.path
    }

    method path-segments() {
        self!ensure-cached-uri();
        $!cached-uri.path-segments
    }

    method !ensure-cached-uri(--> Nil) {
        if $!cached-uri-target ne $!target {
            $!cached-uri = Cro::Uri::HTTP.parse-request-target($!target);
            $!cached-uri-target = $!target;
        }
    }

    method query() {
        self!ensure-cached-uri();
        $!cached-uri.query
    }

    method query-hash() {
        self!ensure-cached-uri();
        $!cached-uri.query-hash
    }

    method query-value(Str() $key) {
        self.query-hash.{$key}
    }
}