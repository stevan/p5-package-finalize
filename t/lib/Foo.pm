package Foo;

use strict;
use warnings;
use Package::Finalize;

use parent 'Bar';

sub bar { 'Foo::bar' }

FINALIZE {
    require Baz;
    push @Foo::ISA => 'Baz';
};

1;

__END__