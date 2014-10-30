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

like(
    exception { My::Test->woot }, 
    qr/^\[PACKAGE FINALIZED\] The package \(My\:\:Test\) has been finalized, attempt to access key \(woot\) is not allowed/, 
    '... got the exception we expected (for calling a method that does not exist)'
);

like(
    exception { no strict 'refs'; ${'My::Test::'}{BAR} }, 
    qr/^\[PACKAGE FINALIZED\] The package \(My\:\:Test\) has been finalized, attempt to access key \(BAR\) is not allowed/, 
    '... got the exception we expected (for accessing the package via stash key)'
);

like(
    exception { no strict 'refs'; ${'My::Test::'}{BAR} = 10 }, 
    qr/^\[PACKAGE FINALIZED\] The package \(My\:\:Test\) has been finalized, attempt to store into key \(BAR\) is not allowed/, 
    '... got the exception we expected (for attempting to store into package via stash key)'
);

like(
    exception { eval "sub My::Test::beep {}"; die $@ if $@; }, 
    qr/^\[PACKAGE FINALIZED\] The package \(My\:\:Test\) has been finalized, attempt to store into key \(beep\) is not allowed/, 
    '... got the exception we expected (for attempting to install a new method)'
);

done_testing;