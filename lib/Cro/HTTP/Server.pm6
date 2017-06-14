use Cro;
use Cro::HTTP::RequestParser;
use Cro::HTTP::ResponseSerializer;
use Cro::SSL;
use Cro::TCP;

my class RequestParserExtension does Cro::Transform {
    has @!parsers;
    has @!additional-parsers;

    method consumes() { Cro::HTTP::Request }
    method produces() { Cro::HTTP::Request }

    method transformer(Supply $pipeline --> Supply) {
        supply {
            whenever $pipeline -> $request {
                if @!parsers.elems != 0 {
                    $request.body-parser-selector = Cro::HTTP::BodyParserSelector::List.new(parsers => @!parsers);
                }
                if @!additional-parsers.elems != 0 {
                    $request.body-parser-selector = Cro::HTTP::BodyParserSelector::Prepend.new(parsers => @!additional-parsers,
                                                                                               next => $request.body-parser-selector);
                }
                emit $request;
            }
        }
    }
}

class Cro::HTTP::Server does Cro::Service {
    only method new(Cro::Transform :$application!,
                    :$host, :$port, :%ssl,
                    :$before, :$after,
                    :@add-body-parsers, :@body-parsers) {
        my $listener = %ssl
            ?? Cro::SSL::Listener.new(
                  |(:$host with $host),
                  |(:$port with $port),
                  |%ssl
               )
            !! Cro::TCP::Listener.new(
                  |(:$host with $host),
                  |(:$port with $port)
               );

        my @after = $after ~~ Iterable ?? $after.List !! ($after === Any ?? () !! $after);
        my @before = $before ~~ Iterable ?? $before.List !! ($before === Any ?? () !! $before);

        return Cro.compose(
            service-type => self.WHAT,
            $listener,
            Cro::HTTP::RequestParser.new,
            RequestParserExtension.new(:@add-body-parsers, :@body-parsers),
            |@before,
            $application,
            # serialization
            |@after,
            Cro::HTTP::ResponseSerializer.new
        )
    }
}
