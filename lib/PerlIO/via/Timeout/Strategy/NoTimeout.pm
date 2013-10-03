package PerlIO::via::Timeout::Strategy::NoTimeout;

# ABSTRACT: a L<PerlIO::via::Timeout> strategy that don't do any timeout

=DESCRIPTION

This class is the default strategy used by L<PerlIO::via::Timeout> if none is
provided. It inherits L<PerlIO::via::Timeout::Strategy>. This strategy does
B<not> apply any timeout on the filehandle.

This strategy is only useful for other strategies to inherit from. It should B<not>
be used directly.

=head1 CONSTRUCTOR

See L<PerlIO::via::Timeout::Strategy>.

=head1 METHODS

See L<PerlIO::via::Timeout::Strategy>.

=cut

require 5.008;
use strict;
use warnings;
use Errno qw(EINTR);

use PerlIO::via::Timeout::Strategy;
our @ISA = qw(PerlIO::via::Timeout::Strategy);


sub READ {
    my ($self, undef, $len, $fh, $fd) = @_;
    my $offset = 0;
    while () {
        my $r = sysread($fh, $_[1], $len, $offset);
        if (defined $r) {
            last unless $r;
            $len -= $r;
            $offset += $r;
        }
        elsif ($! != EINTR) {
            # There is a bug in PerlIO::via (possibly in PerlIO ?). We would like
            # to return -1 to signify error, but doing so doesn't work (it usually
            # segfault), it looks like the implementation is not complete. So we
            # return 0.
            return 0;
        }
    }
    return $offset;
}

sub WRITE {
    my ($self, undef, $fh, $fd) = @_;
    my $rv = syswrite($fh, $_[1]);
    defined $rv
      or return -1;
    return $rv;
}

1;
