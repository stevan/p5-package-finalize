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

my $test = bless { one => 1, two => 2 } => 'My::Test';
is($test->one, 1, '... got the expected results');
is($test->two, 2, '... got the expected results');

done_testing;