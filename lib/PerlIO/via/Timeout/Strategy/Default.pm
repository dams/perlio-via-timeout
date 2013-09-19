package PerlIO::via::Timeout::Strategy::Default;

use parent 'PerlIO::via::Timeout::Strategy';

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
}

sub READ {
    my ($self, undef, $len, $fh) = @_;
    return sysread($fh, $_[1], $len, $offset);
}

sub WRITE {
    my ($self, undef, $fh) = @_;
    return syswrite($fh, $_[1]);
}
1;
