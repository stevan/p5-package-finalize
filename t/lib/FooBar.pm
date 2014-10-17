package FooBar;

use strict;
use warnings;
use Package::Finalize;

our @STACK;

FINALIZE {
    push @FooBar::STACK => __PACKAGE__;
};

package FooBar::Baz;

use strict;
use warnings;
use Package::Finalize;

FINALIZE {
    push @FooBar::STACK => __PACKAGE__;
};

package FooBar::Baz::Gorch;

use strict;
use warnings;
use Package::Finalize;

FINALIZE {
    push @FooBar::STACK => __PACKAGE__;
};

1;