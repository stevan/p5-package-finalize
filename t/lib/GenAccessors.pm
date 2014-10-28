package GenAccessors;

use strict;
use warnings;

use Devel::BeginLift;
use Devel::Hook;
use Package::Finalize ();

sub import {
    shift;
    
    my $pkg = caller;

    no strict 'refs';
    *{$pkg . '::has'} = sub {
        my ($name) = @_;
        Package::Finalize->add_finalizer_for( $pkg, sub {
            *{$pkg . '::' . $name} = sub {
                my $self = shift;
                $self->{ $name } = $_[0] if @_;
                $self->{ $name };
            }
        });
    };

    Devel::BeginLift->setup_for( $pkg => [ 'has' ] );

    goto \&Package::Finalize::import;
}

1;