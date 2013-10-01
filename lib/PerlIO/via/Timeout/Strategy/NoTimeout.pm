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
    my $rv = sysread($fh, $_[1], $len);
    if (! defined $rv) {
        # There is a bug in PerlIO::via (possibly in PerlIO ?). We would like
        # to return -1 to signify error, but doing so doesn't work (it usually
        # segfault), it looks like the implementation is not complete. So we
        # return 0.
        $rv = 0;
    }
    return $rv;
}

sub WRITE {
    my ($self, undef, $fh, $fd) = @_;
    my $rv syswrite($fh, $_[1]);
    defined $rv
      or return -1;
    return $rv;
}

1;
