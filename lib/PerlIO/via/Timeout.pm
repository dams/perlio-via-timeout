package PerlIO::via::Timeout;

use PerlIO::via::Timeout::Strategy::Default;

use Module::Load;

=head1 SYNOPSIS

  use PerlIO::via::Timeout;
  open my $file, '<:via(Timeout)', 'foo.html'
    or die "Can't open foo.html: $!\n";

  # set read timeout to 0.5
  handle_timeout_read($file, 0.5);
  # enable timeout
  enable_handle_timeout($file);

  use Errno qw(ETIMEDOUT);
  while (<$fh>) { ... }
  if ($! == ETIMEDOUT) { ... }

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

#use Scalar::Util qw(reftype);

#use Exporter 'import'; # gives you Exporter's import() method directly
#our @EXPORT_OK = ( qw(timeout_enabled timeout_strategy), map { $_ . "_timeout" } qw(enable disable read write));
#our %EXPORT_TAGS = (all => [ @EXPORT_OK ]);

my %strategy;

# my %fd_to_properties;
# my $READ = 0;
# my $WRITE = 1;
# my $ENABLED = 2;
# my $STRATEGY = 3;
# my $STRAT_INST = 4;

sub PUSHED {
    my ($class, $mode, $fh) = @_;

    my $fd = fileno $fh;
    unless (defined $fd && $fd >= 0) {
        $! = EBADF;
        return -1;
    }

    # default values

#    $fd_to_properties{$fd}
      # = [ 3, # read_timeout
      #     3, # write_timeout
      #     0, # enabled
      #     $class->_default_strategy, # strategy_timeout
      #     undef, # strategy_instance
      #   ];

    return bless({ mode => $mode }, $class);
}

sub POPPED {
    my ($self, $fh) = @_;
    defined $fh or return;
    my $fd = fileno $fh;
    defined $fd or return;
    delete $strategy{$fd};
#    my $properties = delete $fd_to_properties{$fd}
#      or return;
#    $properties->[$STRAT_INST]->cleanup($fh, $fd);
}

sub CLOSE {
    my ($self, $fh) = @_;
    defined $fh or return;
    my $fd = fileno $fh;
    defined $fd or return;
    delete $strategy{$fd};
#    my $properties = delete $fd_to_properties{$fd}
#      or return;
#    $properties->[$STRAT_INST]->cleanup($fh, $fd);
    close($fh);
}

# # Exported functions
# sub read_timeout     { unshift @_, $READ; goto &_getter_setter }
# sub write_timeout    { unshift @_, $WRITE; goto &_getter_setter }
# sub timeout_enabled  { unshift @_, $ENABLED; goto &_getter_setter }
# sub enable_timeout   { timeout_enabled($_[0], 1) }
# sub disable_timeout  { timeout_enabled($_[0], 0) }

# sub _getter_setter {
#     my $pos = shift;
#     reftype $_[0] eq 'GLOB' or croak 'bad usage. parameters: $fh, [ $value ]';
#     my $fd = fileno $_[0];
#     defined $fd or croak 'bad file descriptor for handle';
#     @_ > 1 and $fd_to_properties{$fd}[$pos] = $_[1];
#     $fd_to_properties{$fd}[$pos];
# }

# sub timeout_strategy {
#     reftype $_[0] eq 'GLOB' or croak 'bad usage. parameters: $fh, [ $value ]';
#     my $fd = fileno $_[0];
#     defined $fd or croak 'bad file descriptor for handle';
#     @_ > 1 and $fd_to_properties{$fd}[$STRAT] = $_[1], $fd_to_properties{$fd}[$STRAT_INST] = undef;
#     $fd_to_properties{$fd}[$STRAT];
# }

# made to be overridden
#sub _default_strategy { 'Select' }

sub READ {
    # my ($self, undef, $len, $fh) = @_;
    my $self = shift;
    my $fd = fileno $_[2];
    unless (defined $fd && $fd >= 0) {
        $! = EBADF;
        return 0;
    }

    my $strategy = ($strategy{$fd} ||= PerlIO::via::Timeout::Strategy::Default->new());
    
    $strategy->READ(@_);
}

sub WRITE {
#    my ($self, undef, $fh) = @_;

    my $self = shift;
    my $fd = fileno $_[1];
    unless (defined $fd && $fd >= 0) {
        $! = EBADF;
        return -1;
    }

    my $strategy = ($strategy{$fd} ||= PerlIO::via::Timeout::Strategy::Default->new());
    
    $strategy->WRITE(@_);
}

sub timeout_strategy {
     reftype $_[0] eq 'GLOB' or croak 'bad usage. parameters: $fh, [ $value ]';
     my $fd = fileno $_[0];
     defined $fd or croak 'bad file descriptor for handle';
     if (@_ > 1) {
         $strategy =~ s/^+//
           or $strategy = 'PerlIO::via::Timeout::Strategy::' . $strategy;
         load $strategy;
         $strategy{$fd} = $strategy->new();
     }
     return $strategy{$fd};
}

1;

=head1 SEE ALSO

PerlIO::via

=cut
