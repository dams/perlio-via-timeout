package PerlIO::via::Timeout::Strategy;

sub new {
    my $class = shift;
    bless { @_ }, $class;
}

1;
