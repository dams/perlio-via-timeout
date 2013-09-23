package PerlIO::via::Timeout::Strategy;

# ABSTRACT: base class for a L<PerlIO::via::Timeout> strategies

require 5.008;
use strict;
use warnings;
use Carp;

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

sub read_timeout {
    @_ > 1 and $_[0]{read_timeout} = $_[1], $_[0]->_check_attributes;
    $_[0]{read_timeout};
}

sub write_timeout {
    @_ > 1 and $_[0]{write_timeout} = $_[1], $_[0]->_check_attributes;
    $_[0]{write_timeout};    

sub timeout_enabled {
    @_ > 1 and $_[0]{timeout_enabled} = !!$_[1];
    $_[0]{timeout_enabled};
}

sub enable_timeout { $_[0]->timeout_enabled(1) }
sub disable_timeout { $_[0]->timeout_enabled(0) }
}

sub READ { croak "READ is not implemented by this strategy" }

sub WRITE { croak "WRITE is not implemented by this strategy" }

1;
