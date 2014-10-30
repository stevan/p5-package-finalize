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
    Package::Finalize->import_into( $pkg );
    Package::Finalize->add_finalizer_for( $pkg, sub { delete ${ $pkg . '::'}{'has'} });
}

1;