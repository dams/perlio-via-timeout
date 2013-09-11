package PerlIO::via::Timeout;

=head1 SYNOPSIS

    use PerlIO::via::StripHTML;
    open my $file, '<:via(StripHTML)', 'foo.html'
	or die "Can't open foo.html: $!\n";

=head1 DESCRIPTION

This package implements a PerlIO layer, for reading files only. It
strips HTML tags from the input, leaving only plain text. This can be
useful, for example, to find something in the text of a HTML page.

=cut

require 5.008;
use strict;
use warnings;

use Carp  qw[croak];
use Errno qw[EBADF EINTR ETIMEDOUT];

sub PUSHED {
    my ($class, $mode, $fh) = @_;

    my $fd = fileno $fh;
    unless (defined $fd && $fd >= 0) {
        $! = EBADF;
        return -1;
    }
    return bless({ mode => $mode,
                   timeout_read => 0,
                   timeout_write => 0,
                   timeout_strategy => undef,                   
                   timeout_enabled => 1,
                 }, $class);
}

sub READ {
    my ($self, undef, $len, $fh) = @_;

    my $off = 0;
    while () {
        unless (can_read($fh, $self->{timeout})) {
            $! = ETIMEDOUT unless $!;
            return 0;
        }
        my $r = sysread($fh, $_[1], $len, $off);
        if (defined $r) {
            last unless $r;
            $len -= $r;
            $off += $r;
        }
        elsif ($! != EINTR) {
            return 0;
        }
    }
    return $off;
}

sub WRITE {
    my ($self, undef, $fh) = @_;

    my $len = length $_[1];
    my $off = 0;
    while () {
        unless (can_write($fh, $self->{timeout})) {
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
    my ($fh, $timeout) = @_;

    my $fd = fileno $fh;
    unless (defined $fd && $fd >= 0) {
        $! = EBADF;
        return 0;
    }

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
    my ($fh, $timeout) = @_;

    my $fd = fileno $fh;
    unless (defined $fd && $fd >= 0) {
        $! = EBADF;
        return 0;
    }

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

=head1 SEE ALSO

PerlIO::via

=cut
