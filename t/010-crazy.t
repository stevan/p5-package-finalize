#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use lib 't/lib';

{
    package My::Test;
    use strict;
    use warnings;
    use GenAccessors;

    # if the `has` operation ran 
    # at normal runtime then this 
    # would fail, but since they 
    # have been lifted to BEGIN
    # time, it works. 
    our $GOT_ONE = __PACKAGE__->can('one') ? 1 : 0;

    has 'one';
    has 'two';
}

is($My::Test::GOT_ONE, 1, '... the `has` function fired at BEGIN time');

can_ok('My::Test', 'one');
can_ok('My::Test', 'two');

my $test = bless { one => 1, two => 2 } => 'My::Test';
is($test->one, 1, '... got the expected results');
is($test->two, 2, '... got the expected results');

is(exception { $test->one(10) }, undef, '... no exception (as expected)');
is(exception { $test->two(20) }, undef, '... no exception (as expected)');

is($test->one, 10, '... got the expected results');
is($test->two, 20, '... got the expected results');

ok(!My::Test->can('three'), '... do not have a `three` method (and calling `can` did not break)');

like(
    exception { My::Test->three }, 
    qr/^\[PACKAGE FINALIZED\] The package \(My\:\:Test\) has been finalized, attempt to access key \(three\) is not allowed/, 
    '... got the exception we expected (for calling a method that does not exist)'
);

ok(!My::Test->can('has'), '... the `has` method has been removed');

like(
    exception { eval "My::Test::has('four')"; die $@ if $@ }, 
    qr/^\[PACKAGE FINALIZED\] The package \(My\:\:Test\) has been finalized, attempt to store into key \(has\) is not allowed/, 
    '... got the exception we expected (for trying to call `has` function)'
);

done_testing;