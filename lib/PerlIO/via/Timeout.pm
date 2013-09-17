package PerlIO::via::Timeout;

=head1 SYNOPSIS

    use PerlIO::via::Timeout;
    open my $file, '<:via(Timeout)', 'foo.html'
	or die "Can't open foo.html: $!\n";


=head1 DESCRIPTION

This package implements a PerlIO layer, for reading files only. It
strips HTML tags from the input, leaving only plain text. This can be
useful, for example, to find something in the text of a HTML page.

=cut

require 5.008;
use strict;
use warnings;

use Carp;
use Errno qw(EBADF EINTR ETIMEDOUT);

use Scalar::Util qw(blessed);

use PerlIO::via::Timeout::Handle;
my $handle_class = 'PerlIO::via::Timeout::Handle';

sub PUSHED {
    # $_[0] eq __PACKAGE__
    #   and croak "Don't use 'via' directly on " . __PACKAGE__ . ". Use the 'new' constructor";
    my ($class, $mode, $fh) = @_;

    my $current_class = blessed $fh;

    if (defined $current_class) {
        my $new_class = $handle_class . '__WITH__' . $current_class;
        bless $fh, $new_class;
        push @{"${new_class}::ISA"}, $current_class;
    } else {
        bless $fh, $handle_class;
    }

    $fh->isa($handle_class)
      or push @{blessed($fh) . '::ISA'}, $handle_class;

    my $fd = fileno $fh;
    unless (defined $fd && $fd >= 0) {
        $! = EBADF;
        return -1;
    }

    # default values

    @{*$fh}{qw(_timeout_read _timeout_write _timeout_strategy _timeout_enabled)}
      = (3, 3, $class->_default_strategy, 0);

    return bless({ mode => $mode,
                 }, $class);
}

# made to be overridden
sub _default_strategy { 'Select' }

sub READ {
    my ($self, undef, $len, $fh) = @_;

    my $off = 0;
    while () {
        unless (can_read($fh, ${*$fh}{_timeout_read})) {
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
        unless (can_write($fh, ${*$fh}{_timeout_write})) {
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

# sub new {
#     @_ % 2
#       and croak 'usage: ' . __PACKAGE__ . '->new($fh, %optional_args)';
#     my ($self, $fh, %args) = @_;
#     timeout_read => 1,
#     timeout_write => 1,
#     timeout_strategy => undef,                   
#     timeout_enabled => 1,

# }

1;

=head1 SEE ALSO

PerlIO::via

=cut
