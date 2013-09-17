# internal package, don't get indexed by CPAN
package
PerlIO::via::Timeout::Handle;

sub timeout_read {
    @_ > 1 and ${*{$_[0]}}{_timeout_read} = $_[1];
    ${*{$_[0]}}->{_timeout_read};
}

sub timeout_write {
    @_ > 1 and ${*{$_[0]}}{_timeout_write} = $_[1];
    ${*{$_[0]}}->{_timeout_write};
}

sub timeout_strategy {
    @_ > 1 and ${*{$_[0]}}{_timeout_strategy} = $_[1];
    ${*{$_[0]}}->{_timeout_strategy};
}

sub timeout_enabled {
    @_ > 1 and ${*{$_[0]}}{_timeout_enabled} = $_[1];
    ${*{$_[0]}}->{_timeout_enabled};
}

sub enable_timeout { $_[0]->timeout_enabled(1) }

sub disable_timeout { $_[0]->timeout_enabled(0) }

1;
