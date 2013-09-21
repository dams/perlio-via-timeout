use strict;
use warnings;

use Test::More;
use PerlIO::via::Timeout qw(timeout_strategy);

use Test::TCP;

sub create_server {
    my $delay = shift;
    Test::TCP->new(
        code => sub {
            my $port   = shift;
            my $socket = IO::Socket::INET->new(
                Listen    => 5,
                Reuse     => 1,
                Blocking  => 1,
                LocalPort => $port
            ) or die "ops $!";
    
            my $buffer;
            while (1) {
               # First, establish connection
                my $client = $socket->accept();
                $client or next;
    
                # Then get data (with delay)
                if ( defined (my $message = <$client>) ) {
                    my $response = "S" . $message;
                    sleep($delay);
                    print $client $response;
                }
                $client->close();
            }
        },
    );
    
}


subtest 'socket without timeout' => sub {
    my $server = create_server(1);
    my $client = IO::Socket::INET->new(
        PeerHost        => '127.0.0.1',
        PeerPort        => $server->port,
    );
    
    binmode($client, ':via(Timeout)');
    my $strategy = timeout_strategy($client);
    is ref $strategy, 'PerlIO::via::Timeout::Strategy::NoTimeout', 'strategy is of type NoTimeout';
    is $strategy->read_timeout, 0, 'strategy has default 0 read timeout';
    is $strategy->write_timeout, 0, 'strategy has default 0 write timeout';
    
    $client->print("OK\n");
    my $response = $client->getline;
    is $response, "SOK\n", "got proper response 1";

};

subtest 'socket with timeout' => sub {
    my $server = create_server(2);
    my $client = IO::Socket::INET->new(
        PeerHost        => '127.0.0.1',
        PeerPort        => $server->port,
    );
    
    binmode($client, ':via(Timeout)');
    timeout_strategy($client, 'Select', read_timeout => 0.5);

    my $strategy = timeout_strategy($client);
    is ref $strategy, 'PerlIO::via::Timeout::Strategy::Select', 'strategy is of type Select';
    is $strategy->read_timeout, 0.5, 'strategy has proper read timeout';
    is $strategy->write_timeout, 0, 'strategy has default 0 write timeout';

    print $client ("OK\n");
    my $response = <$client>;
    is $response, undef, "got undef response";
    like $!, qr/timed out/, "error is timeout";
};

done_testing;
