package PerlIO::via::Timeout::Strategy::Select;

use Moo;

use parent 'PerlIO::via::Timeout::Strategy';

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
}

sub READ {
    my ($self, undef, $len, $fh) = @_;

    while () {
        if ( $enabled && ! can_read($fh, $fd, $read_timeout)) {
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
            return 0;
        }
    }
    return $offset;
}

sub WRITE {
    my ($self, undef, $fh) = @_;

    my $fd = fileno $fh;
    unless (defined $fd && $fd >= 0) {
        $! = EBADF;
        return -1;
    }

    my (undef, $write_timeout, $strategy_timeout, $enabled) = @{$fd_to_properties{$fd}};

    my $len = length $_[1];
    my $off = 0;
    while () {
        unless (can_write($fh, $fd, $write_timeout)) {
            $! = ETIMEDOUT unless $!;
            return -1;
        }
        my $r = syswrite($fh, $_[1], $len, $off);
        if (defined $r) {
            $len -= $r;
            $off += $r;
            last unless $len;
        }
        elsif ($! != EINTR) {
            return -1;
        }
    }
    return $off;
}

sub can_read {
    my ($fh, $fd, $timeout) = @_;

    my $initial = time;
    my $pending = $timeout;
    my $nfound;

    vec(my $fdset = '', $fd, 1) = 1;

    while () {
        $nfound = select($fdset, undef, undef, $pending);
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

sub can_write {
    my ($fh, $fd, $timeout) = @_;

    my $initial = time;
    my $pending = $timeout;
    my $nfound;

    vec(my $fdset = '', $fd, 1) = 1;

    while () {
        $nfound = select(undef, $fdset, undef, $pending);
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

1;
