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

    # warn "HELLO!" if __PACKAGE__->can('one');

    has 'one';
    has 'two';
}

can_ok('My::Test', 'one');
can_ok('My::Test', 'two');

my $test = bless { one => 1, two => 2 } => 'My::Test';
is($test->one, 1, '... got the expected results');
is($test->two, 2, '... got the expected results');

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