package PerlIO::via::Timeout;

# ABSTRACT: a PerlIO layer that adds read & write timeout to a handle

require 5.008;
use strict;
use warnings;
use Carp;
use Errno qw(EBADF EINTR ETIMEDOUT);
use Scalar::Util qw(reftype blessed weaken);

use PerlIO::via::Timeout::Strategy::NoTimeout;

use Exporter 'import'; # gives you Exporter's import() method directly
our @EXPORT_OK = qw(read_timeout write_timeout enable_timeout disable_timeout timeout_enabled);
our %EXPORT_TAGS = (all => [@EXPORT_OK]);

=head1 DESCRIPTION

This package implements a PerlIO layer, that adds read / write timeout. This
can be useful to avoid blocking while accessing a handle (file, socket, ...),
and fail after some time.

=head1 SYNOPSIS

  use Errno qw(ETIMEDOUT);
  use PerlIO::via::Timeout qw(:all);
  open my $fh, '<:via(Timeout)', 'foo.html';

  # set the timeout layer to be 0.5 second read timeout
  read_timeout($fh, 0.5);

  my $line = <$fh>;
  if ($line == undef && 0+$! == ETIMEDOUT) {
    # timed out
    ...
  }

=cut

my %fd2prop;

sub _get_fd {
    # params: FH
    $_[0] or return;
    my $fd = fileno($_[0]);
    defined $fd && $fd >= 0
      or croak "failed to get file descriptor from filehandle";
    $fd;
}

sub PUSHED {
    # params CLASS, MODE, FH
    $fd2prop{_get_fd $_[2]} = { timeout_enabled => 1, read_timeout => 0, write_timeout => 0};
    bless {}, $_[0];
}

sub POPPED {
    # params: SELF [, FH ]
    delete $fd2prop{_get_fd $_[1] or return};
}

sub CLOSE {
    # params: SELF, FH
    delete $fd2prop{_get_fd $_[1]};
    close $_[1];
}

sub READ {
    # params: SELF, BUF, LEN, FH
    my ($self, undef, $len, $fh) = @_;

    # There is a bug in PerlIO::via (possibly in PerlIO ?). We would like
    # to return -1 to signify error, but doing so doesn't work (it usually
    # segfault), it looks like the implementation is not complete. So we
    # return 0.
    my $fd = _get_fd $fh;

    my $timeout_enabled = $fd2prop{$fd}->{timeout_enabled};
    my $read_timeout = $fd2prop{$fd}->{read_timeout};

    my $offset = 0;
    while () {
        if ( $timeout_enabled && $read_timeout && $len && ! _can_read_write($fh, $fd, $read_timeout, 0)) {
            $! = ETIMEDOUT unless $!;
            return 0;
        }
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
    # params: SELF, BUF, FH
    my ($self, undef, $fh) = @_;

    my $fd = _get_fd $fh;

    my $timeout_enabled = $fd2prop{$fd}->{timeout_enabled};
    my $write_timeout = $fd2prop{$fd}->{write_timeout};

    my $len = length $_[1];
    my $offset = 0;
    while () {
        if ( $len && $timeout_enabled && $write_timeout && ! _can_read_write($fh, $fd, $write_timeout, 1)) {
            $! = ETIMEDOUT unless $!;
            return -1;
        }
        my $r = syswrite($fh, $_[1], $len, $offset);
        if (defined $r) {
            $len -= $r;
            $offset += $r;
            last unless $len;
        }
        elsif ($! != EINTR) {
            return -1;
        }
    }
    return $offset;
}

sub _can_read_write {
    my ($fh, $fd, $timeout, $type) = @_;
    # $type: 0 = read, 1 = write
    my $initial = time;
    my $pending = $timeout;
    my $nfound;

    vec(my $fdset = '', $fd, 1) = 1;

    while () {
        if ($type) {
            # write
            $nfound = select(undef, $fdset, undef, $pending);
        } else {
            # read
            $nfound = select($fdset, undef, undef, $pending);
        }
        if ($nfound == -1) {
            $! == EINTR
              or croak(qq/select(2): '$!'/);
            redo if !$timeout || ($pending = $timeout - (time -
            $initial)) > 0;
            $nfound = 0;
        }
        last;
    }
    $! = 0;
    return $nfound;
}

=func read_timeout

  # set a read timeout of 2.5 seconds
  read_timeout($fh, 2.5);
  # get the current read timeout
  my $secs = read_timeout($fh);

Getter / setter of the read timeout value.

=cut

sub read_timeout {
    my $prop = $fd2prop{_get_fd $_[0]};
    @_ > 1 and $prop->{read_timeout} = $_[1], _check_attributes($prop);
    $prop->{read_timeout};
}

=func write_timeout

  # set a write timeout of 2.5 seconds
  timeout_layer($fh)->write_timeout(2.5);
  # get the current write timeout
  my $secs = timeout_layer($fh)->write_timeout();

Getter / setter of the write timeout value.

=cut

sub write_timeout {
    my $prop = $fd2prop{_get_fd $_[0]};
    @_ > 1 and $prop->{write_timeout} = $_[1], _check_attributes($prop);
    $prop->{write_timeout};
}


sub _check_attributes {
    grep { $_[0]->{$_} < 0 } qw(read_timeout write_timeout)
      and croak "if defined, 'read_timeout' and 'write_timeout' attributes should be >= 0";
}

=func enable_timeout

  enable_timeout($fh);

Equivalent to setting timeout_enabled to 1

=cut

sub enable_timeout { timeout_enabled($_[0], 1) }

=func disable_timeout

  timeout_layer($fh)->disable_timeout();

Equivalent to setting timeout_enabled to 0

=cut

sub disable_timeout { timeout_enabled($_[0], 0) }

=func timeout_enabled

  # disable timeout
  timeout_enabled($fh, 0);
  # enable timeout
  timeout_enabled($fh, 1);
  # get the current status
  my $is_enabled = timeout_enabled($fh);

Getter / setter of the timeout enabled flag.

=cut

sub timeout_enabled {
    my $prop = $fd2prop{_get_fd $_[0]};
    @_ > 1 and $prop->{timeout_enabled} = !!$_[1];
    $prop->{timeout_enabled};
}

1;

=head1 SEE ALSO

=over

=item L<PerlIO::via>

=back

=head1 THANKS TO

=over

=item Vincent Pit

=item Christian Hansen

=item Leon Timmmermans

=back

=cut
