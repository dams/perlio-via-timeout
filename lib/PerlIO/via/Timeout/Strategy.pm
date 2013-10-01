package PerlIO::via::Timeout::Strategy;

# ABSTRACT: base class for a L<PerlIO::via::Timeout> strategies

require 5.008;
use strict;
use warnings;
use Carp;

=head1 DESCRIPTION

This package implements the virtual class from which all timeout strategies are
supposed to inherit from.

=head1 CONSTRUCTOR

=head2 new

  my $strategy = PerlIO::via::Timeout::Strategy::Alarm->new(write_timeout => 2)

Creates a new timeout strategy. Takes in argument a hash, which keys can be:

=over

=item read_timeout

the read timeout in second. Float >= 0. Defaults to 0

=item write_timeout

the write timeout in second. Float >= 0. Defaults to 0

=item timeout_enabled

sets/unset timeout. Boolean. Defaults to 1

=back

=cut

sub new {
    my $class = shift;
    @_ % 2 and croak "parameters should be key value pairs";
    my $self = bless { read_timeout => 0, write_timeout => 0, timeout_enabled => 1, @_ }, $class;
    $self->_check_attributes;
    $self;
}

sub _check_attributes {
    grep { $_[0]->{$_} < 0 } qw(read_timeout write_timeout)
      and croak "if defined, 'read_timeout' and 'write_timeout' attributes should be >= 0";
}

=method read_timeout

Getter / setter of the read timeout value.

=cut

sub read_timeout {
    @_ > 1 and $_[0]{read_timeout} = $_[1], $_[0]->_check_attributes;
    $_[0]{read_timeout};
}

=method write_timeout

Getter / setter of the write timeout value.

=cut

sub write_timeout {
    @_ > 1 and $_[0]{write_timeout} = $_[1], $_[0]->_check_attributes;
    $_[0]{write_timeout};    
}

=method timeout_enabled

Getter / setter of the timeout enabled flag.

=cut

sub timeout_enabled {
    @_ > 1 and $_[0]{timeout_enabled} = !!$_[1];
    $_[0]{timeout_enabled};
}

=method enable_timeout

equivalent to setting timeout_enabled to 1

=cut

sub enable_timeout { $_[0]->timeout_enabled(1) }

=method disable_timeout

equivalent to setting timeout_enabled to 0

=cut

sub disable_timeout { $_[0]->timeout_enabled(0) }

sub READ { croak "READ is not implemented by this strategy" }

sub WRITE { croak "WRITE is not implemented by this strategy" }

1;

=head1 SEE ALSO

=over

=item L<PerlIO::via::Timeout>

=back
