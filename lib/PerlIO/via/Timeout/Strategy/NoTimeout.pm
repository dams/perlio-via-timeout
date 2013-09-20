package PerlIO::via::Timeout::Strategy::NoTimeout;

# ABSTRACT: a L<PerlIO::via::Timeout> strategy that don't do any timeout

=DESCRIPTION

This class is the default strategy used by L<PerlIO::via::Timeout> if none is
provided. This strategy does B<not> apply any timeout on the filehandle.

This strategy is only useful for other strategies to herit from. It should not
be used directly.

=cut

require 5.008;
use strict;
use warnings;

use PerlIO::via::Timeout::Strategy;
our @ISA = qw(PerlIO::via::Timeout::Strategy);

sub READ {
    my ($self, undef, $len, $fh, $fd) = @_;
    return sysread($fh, $_[1], $len);
}

sub WRITE {
    my ($self, undef, $fh, $fd) = @_;
    return syswrite($fh, $_[1]);
}

1;
