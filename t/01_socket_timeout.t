use strict;
use warnings;

use Test::More;
use PerlIO::via::Timeout;


#    my $etimeout = strerror(ETIMEDOUT);
#    my $ereset   = strerror(ECONNRESET);

use Test::TCP;

sub create_server {
    my $delay = 2;
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


# subtest 'socket without timeout' => sub {
#     my $server = create_server();
#     my $client = IO::Socket::INET->new(
#         PeerHost        => '127.0.0.1',
#         PeerPort        => $server->port,
#     );
    
#     binmode($client, ':via(Timeout)');
    
    
#     $client->print("OK\n");
#     my $response = $client->getline;
#     print STDERR " --> $!\n";
#     is $response, "SOK\n", "got proper response 1";
# };

subtest 'socket with timeout' => sub {
    my $server = create_server();
    my $client = IO::Socket::INET->new(
        PeerHost        => '127.0.0.1',
        PeerPort        => $server->port,
    );
    
    print STDERR Dumper($client); use Data::Dumper;
    binmode($client, ':via(Timeout)');
    print STDERR Dumper($client); use Data::Dumper;
$DB::single = 1;
    $client->enable_timeout;
    $client->timeout_read(1);
    
    $client->print("OK\n");
    my $response = $client->getline;
    print STDERR " --> $!\n";
    is $response, "SOK\n", "got proper response 1";
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
