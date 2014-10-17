package Bar;

use strict;
use warnings;
use Package::Finalize;

sub baz { 'Bar::baz' }

FINALIZE {
    *Bar::gorch = sub { 'Bar::gorch' };
};

1;

__END__