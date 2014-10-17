#!/usr/bin/env perl

use strict;
use warnings;

use lib 't/lib';

BEGIN { warn "main->BEGIN" }
END   { warn "main->END"   }

use Foo;
use Bar;
use Baz;

warn Foo->bar;
warn Foo->baz;
warn Foo->gorch;
warn Foo->bling;

UNITCHECK {
    warn "main->UNICHECK enter ...";
    warn "... leave main->UNICHECK";
}

1;