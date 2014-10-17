#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use lib 't/lib';

use_ok('Foo');
use_ok('Bar');
use_ok('Baz');

is(Foo->bar,   'Foo::bar',   '... got the expected results');
is(Foo->baz,   'Bar::baz',   '... got the expected results');
is(Foo->gorch, 'Bar::gorch', '... got the expected results');
is(Foo->bling, 'Baz::bling', '... got the expected results');

like(exception { Foo->woot }, qr/^Attempt to access disallowed key \'woot\' in a restricted hash/, '... got the exception we expected');
like(exception { no strict 'refs'; ${'Foo::'}{BAR} }, qr/^Attempt to access disallowed key \'BAR\' in a restricted hash/, '... got the exception we expected');
like(exception { eval "sub Foo::beep {}"; die $@ if $@; }, qr/^Attempt to access disallowed key \'beep\' in a restricted hash/, '... got the exception we expected');
like(exception { no strict 'refs'; delete ${'Foo::'}{BAZ} }, qr/^Attempt to delete disallowed key \'BAZ\' from a restricted hash/, '... got the exception we expected');

done_testing;