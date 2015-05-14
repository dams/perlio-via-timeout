package PerlIO::via::Timeout;

# ABSTRACT: a PerlIO layer that adds read & write timeout to a handle

require 5.008;
use Time::HiRes;
use strict;
use warnings;
use Carp;
use Errno qw(EBADF EINTR ETIMEDOUT EAGAIN EWOULDBLOCK);
use Fcntl qw(F_GETFL F_SETFL O_NONBLOCK);


use Exporter 'import'; # gives you Exporter's import() method directly

our @EXPORT_OK = qw(read_timeout write_timeout enable_timeout disable_timeout timeout_enabled);

our %EXPORT_TAGS = (all => [@EXPORT_OK]);

=head1 DESCRIPTION

This package implements a PerlIO layer, that adds read / write timeout. This
can be useful to avoid blocking while accessing a handle (file, socket, ...),
and fail after some time.

The timeout is implemented by using C<<select>> on the handle before
reading/writing.

B<WARNING> the handle won't timeout if you use C<sysread> or C<syswrite> on it,
because these functions works at a lower level. However if you're trying to
implement a timeout for a socket, see L<IO::Socket::Timeout> that implements
exactly that.

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

sub _get_fd {
    # params: FH
    $_[0] or return;
    my $fd = fileno $_[0];
    defined $fd && $fd >= 0
      or return;
    $fd;
}

my %fd2prop;

sub _fh2prop {
    # params: self, $fh
    my $prop = $fd2prop{ my $fd = _get_fd $_[1]
                         or croak 'failed to get file descriptor for filehandle' };
    wantarray and return ($prop, $fd);
    return $prop;
}

sub PUSHED {
    # params CLASS, MODE, FH
    $fd2prop{_get_fd $_[2]} = { timeout_enabled => 1, read_timeout => 0, write_timeout => 0};
    bless {}, $_[0];
}

sub POPPED {
    # params: SELF [, FH ]
    delete $fd2prop{_get_fd($_[1]) or return};
}

sub CLOSE {
    # params: SELF, FH
    delete $fd2prop{_get_fd($_[1]) or return -1};
    close $_[1] or -1;
}

sub _set_flags {
    # params: FH, FLAGS
    local $!;
    fcntl($_[0], F_SETFL, $_[1])
      or die "Can't set flags for the filehandle: $!\n";

}

sub _get_flags {
    # params: FH
    local $!;
    my $flags = fcntl($_[0], F_GETFL, 0)
      or die "Can't get flags for the filehandle: $!\n";
    return $flags;
}

sub READ {
    # params: SELF, BUF, LEN, FH
    my ($self, undef, $len, $fh) = @_;

    my ($prop, $fd) = __PACKAGE__->_fh2prop($fh);

    my $timeout_enabled = $prop->{timeout_enabled};
    my $read_timeout    = $prop->{read_timeout};

    my $offset = 0;

    if ( ! $timeout_enabled || ! $read_timeout) {
        while ($len) {
            my $r = sysread($fh, $_[1], $len, $offset);
            if (defined $r) {
                last unless $r;
                $len -= $r;
                $offset += $r;
            } elsif ($! != EINTR) {
                # There is a bug in PerlIO::via (possibly in PerlIO ?). We would
                # like to return -1 to signify error, but doing so doesn't work (it
                # usually segfaults), it looks like the implementation is not
                # complete. So we return 0.
                return 0;
            }
        }
        return $offset;
    } else {
        my $flags = _get_flags($fh);
        _set_flags($fh, $flags | O_NONBLOCK);
        while ($len) {
            if ($len && ! _can_read_write($fh, $fd, $read_timeout, 0)) {
                $! ||= ETIMEDOUT;
                $offset = 0;
                last;
            }
            my $r = sysread($fh, $_[1], $len, $offset);
            if (defined $r) {
                last unless $r; #EOF
                $len -= $r;
                $offset += $r;
            } elsif ($! != EINTR && $! != EAGAIN && $! != EWOULDBLOCK) {
                # There is a bug in PerlIO::via (possibly in PerlIO ?). We would
                # like to return -1 to signify error, but doing so doesn't work (it
                # usually segfaults), it looks like the implementation is not
                # complete. So we return 0.
                $offset = 0;
                last;
            }
        }
        _set_flags($fh, $flags);
        return $offset;
    }
}

sub WRITE {
    # params: SELF, BUF, FH
$DB::single = 1;
    my ($self, undef, $fh) = @_;

    my ($prop, $fd) = __PACKAGE__->_fh2prop($fh);

    my $timeout_enabled = $prop->{timeout_enabled};
    my $write_timeout   = $prop->{write_timeout};

    my $len = length $_[1];
    my $offset = 0;

    if ( ! $timeout_enabled || ! $write_timeout) {
        while ($len) {
            my $r = syswrite($fh, $_[1], $len, $offset);
            if (defined $r) {
                $len -= $r;
                $offset += $r;
            } elsif ($! != EINTR) {
                return -1;
            }
        }
    } else {
        my $flags = _get_flags($fh);
        _set_flags($fh, $flags | O_NONBLOCK);
        while ($len) {
            if ( $len && ! _can_read_write($fh, $fd, $write_timeout, 1)) {
                $! ||= ETIMEDOUT;
                $offset = -1;
                last;
            }
            my $r = syswrite($fh, $_[1], $len, $offset);
            if (defined $r) {
                $len -= $r;
                $offset += $r;
                last unless $len; # EOF
            } elsif ($! != EINTR && $! != EAGAIN && $! != EWOULDBLOCK) {
                $offset = -1;
                last
            }
        }
        _set_flags($fh, $flags);
        return $offset;
    }
}

sub _can_read_write {
    my ($fh, $fd, $timeout, $type) = @_;
    # $type: 0 = read, 1 = write
    my $initial = Time::HiRes::time;
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
            !$timeout || ($pending -= Time::HiRes::time - $initial) > 0
              and next;
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
    my $prop = __PACKAGE__->_fh2prop($_[0]);
    @_ > 1 and $prop->{read_timeout} = $_[1] || 0, _check_attributes($prop);
    $prop->{read_timeout};
}

=func write_timeout

  # set a write timeout of 2.5 seconds
  write_timeout($fh, 2.5);
  # get the current write timeout
  my $secs = write_timeout($fh);

Getter / setter of the write timeout value.

=cut

sub write_timeout {
    my $prop = __PACKAGE__->_fh2prop($_[0]);
    @_ > 1 and $prop->{write_timeout} = $_[1] || 0, _check_attributes($prop);
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

  disable_timeout($fh);

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
    my $prop = __PACKAGE__->_fh2prop($_[0]);
    @_ > 1 and $prop->{timeout_enabled} = !!$_[1];
    $prop->{timeout_enabled};
}

=func has_timeout_layer

  if (has_timeout_layer($fh)) {
    # set a write timeout of 2.5 seconds
    write_timeout($fh, 2.5);
  }

Returns wether the given filehandle is managed by PerlIO::via::Timeout.

=cut

sub has_timeout_layer {
    defined (my $fd = _get_fd($_[0]))
      or return;
    exists $fd2prop{$fd};
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
