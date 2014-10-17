#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

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

BEGIN {
    Package::Finalize->add_finalizer_for( 'My::Test' => sub {
        no warnings 'once';
        *My::Test::test3 = sub { 'My::Test::test3' };
    });
}

is(My::Test->test1, 'My::Test::test1', '... got the expected results');
is(My::Test->test2, 'My::Test::test2', '... got the expected results');
is(My::Test->test3, 'My::Test::test3', '... got the expected results');

like(exception { My::Test->woot }, qr/^Attempt to access disallowed key \'woot\' in a restricted hash/, '... got the exception we expected');
like(exception { no strict 'refs'; ${'My::Test::'}{BAR} }, qr/^Attempt to access disallowed key \'BAR\' in a restricted hash/, '... got the exception we expected');
like(exception { eval "sub My::Test::beep {}"; die $@ if $@; }, qr/^Attempt to access disallowed key \'beep\' in a restricted hash/, '... got the exception we expected');

done_testing;