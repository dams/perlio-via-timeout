use strict;
use warnings;

use Test::More;

use File::Temp qw/ tempfile  /;

my ( undef, $file_name ) = tempfile();

print STDERR $file_name . "\n";

use PerlIO::via::Timeout;

push @{MyHandle::ISA}, 'IO::Handle';

open my $fh, '>', $file_name;

print STDERR ref($fh) . "\n";

bless $fh, 'MyHandle';

print STDERR ref($fh) . "\n";

binmode($fh, ':via(Timeout)');

use Data::Dumper;
print STDERR Dumper($fh);
print $fh "some_stuff\n";
print $fh "plop\n";


system "echo; cat $file_name";
