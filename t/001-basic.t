#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use lib 't/lib';

BEGIN { $ENV{'DEBUG_PACKAGE_FINALIZE'} = 1 }

{
    package My::Test;
    use strict;
    use warnings;
    use Package::Finalize;

    sub test1 { 'My::Test::test1' }

    FINALIZE {
        no warnings 'once';
        *My::Test::test2 = sub { 'My::Test::test2' };
    }
}

is(My::Test->test1, 'My::Test::test1', '... got the expected results');
is(My::Test->test2, 'My::Test::test2', '... got the expected results');

like(exception { My::Test->woot }, qr/^Attempt to access disallowed key \'woot\' in a restricted hash/, '... got the exception we expected');
like(exception { no strict 'refs'; ${'My::Test::'}{BAR} }, qr/^Attempt to access disallowed key \'BAR\' in a restricted hash/, '... got the exception we expected');
like(exception { eval "sub My::Test::beep {}"; die $@ if $@; }, qr/^Attempt to access disallowed key \'beep\' in a restricted hash/, '... got the exception we expected');

done_testing;