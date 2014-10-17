#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use lib 't/lib';

use_ok('FooBar');

{
    no warnings 'once';
    is_deeply(
        \@FooBar::STACK, 
        ['FooBar', 'FooBar::Baz', 'FooBar::Baz::Gorch'],
        '... got the expected ordering of FINALIZE blocks'
    );
}

done_testing;