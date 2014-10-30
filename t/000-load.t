#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use lib 't/lib';

BEGIN {
    use_ok('Foo');
    use_ok('Bar');
    use_ok('Baz');
}

can_ok('Foo', 'bar');
can_ok('Foo', 'baz');
can_ok('Foo', 'gorch');
can_ok('Foo', 'bling');

is(Foo->bar,   'Foo::bar',   '... got the expected results');
is(Foo->baz,   'Bar::baz',   '... got the expected results');
is(Foo->gorch, 'Bar::gorch', '... got the expected results');
is(Foo->bling, 'Baz::bling', '... got the expected results');

like(
    exception { no strict 'refs'; *{'Foo::bar'} = sub { 'Foo::bar::2' } }, 
    qr/^Modification of a read-only value attempted/, 
    '... got the expected exception (for attempting to replace a method)'
);

is(Foo->bar, 'Foo::bar', '... got the expected results (still)');

is(
    exception { eval "package Foo::Gorch; sub ahhh { 'Foo::Gorch::ahhh' }"; die $@ if $@ },
    undef, 
    '... got no exception (sub-packages are allowed)'
);

like(
    exception { Foo->woot }, 
    qr/^\[PACKAGE FINALIZED\] The package \(Foo\) has been finalized, attempt to store into key \(woot\) is not allowed/, 
    '... got the expected exception (for calling a method that does not exist)'
);

like(
    exception { no strict 'refs'; ${'Foo::BAR'} }, 
    qr/^\[PACKAGE FINALIZED\] The package \(Foo\) has been finalized, attempt to store into key \(BAR\) is not allowed/, 
    '... got the expected exception (for attempting to access a fully qualified variable that does not exist)'
);

like(
    exception { no strict 'refs'; ${'Foo::'}{BAR} = 10; }, 
    qr/^\[PACKAGE FINALIZED\] The package \(Foo\) has been finalized, attempt to store into key \(BAR\) is not allowed/, 
    '... got the expected exception (for attempting to store into a stash key using hash access)'
);

like(
    exception { no strict 'refs'; ${'Foo::'}{BAR} }, 
    qr/^\[PACKAGE FINALIZED\] The package \(Foo\) has been finalized, attempt to access key \(BAR\) is not allowed/, 
    '... got the expected exception (for attempting to store into a stash key using hash access)'
);

like(
    exception { eval "sub Foo::beep {}"; die $@ if $@ }, 
    qr/^\[PACKAGE FINALIZED\] The package \(Foo\) has been finalized, attempt to store into key \(beep\) is not allowed/, 
    '... got the expected exception (for adding a fully qualified method)'
);

like(
    exception { no strict 'refs'; my $x = delete ${'Foo::'}{BAZ} }, 
    qr/^\[PACKAGE FINALIZED\] The package \(Foo\) has been finalized, attempt to delete key \(BAZ\) is not allowed/, 
    '... got the expected exeption (for deleting a key in the stash)'
);

is(
    exception { no strict 'refs'; delete ${'Foo::'}{BAZ} }, 
    undef,
    '... failed to get the expected exeption (for deleting a key in the stash), because this perl does not call `delete` magic in void context'
);

done_testing;