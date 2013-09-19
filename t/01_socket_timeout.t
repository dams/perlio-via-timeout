use strict;
use warnings;

use Test::More;
use PerlIO::via::Timeout qw(:all);

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
    my $server = create_server(2);
    my $client = IO::Socket::INET->new(
        PeerHost        => '127.0.0.1',
        PeerPort        => $server->port,
    );
    
    binmode($client, ':via(Timeout)');

    print STDERR Dumper({%{*$client}}); use Data::Dumper;
    
    $client->print("OK\n");
    my $response = $client->getline;
    print STDERR " --> $!\n";
    is $response, "SOK\n", "got proper response 1";
};

subtest 'socket with timeout' => sub {
    my $server = create_server(2);
    my $client = IO::Socket::INET->new(
        PeerHost        => '127.0.0.1',
        PeerPort        => $server->port,
    );
    
    use Scalar::Util qw(refaddr);
    binmode($client, ':via(Timeout)');

#    set_timeout_strategy($client, PerlIO::via::Timeout::Strategy::Select->new(read_timeout => 1));

#    enable_timeout($client);
#    read_timeout($client, 1);
#    write_timeout($client, 1);

#    print STDERR Dumper({%{*$client}}); use Data::Dumper;
    
    $client->print("OK\n");
    my $response = $client->getline;
    is $response, undef, "got undef response";
    is $!, 'Operation timed out', "error is timeout";
};

# $client->print("OK\n");
# $response = $client->getline;
# print STDERR " --> $!\n";
# is $response, "SOK\n", "got proper response 1";



#    $p{callback}->($client, $etimeout, $ereset);

# subtest 'test with no delays and no timeouts', sub {
# TestTimeout->test( provider => 'SetSockOpt',
#                    connection_delay => 0,
#                    read_delay => 0,
#                    write_delay => 0,
#                    callback => sub {
#                        my ($client) = @_;
#                        $client->print("OK\n");
#                        my $response = $client->getline;
#                        is $response, "SOK\n", "got proper response 1";
#                        $client->print("OK2\n");
#                        $response = $client->getline;
#                        is $response, "SOK2\n", "got proper response 2";
#                    },
#                  );
# };


# my $test_tempdir = temp_root();



# my $directory_scratch_obj = scratch();
