package Package::Finalize;

use strict;
use warnings;
use mro;

use Devel::Hook;
use Devel::BeginLift;
use Variable::Magic qw[ wizard cast ];

use constant DEBUG => 0; #$ENV{'DEBUG_PACKAGE_FINALIZE'};

use constant DEFAULT_IGNORED_KEYS => [qw(
    import   
    unimport 

    can
    isa

    VERSION  
    AUTHORITY

    ISA

    BEGIN    
    INIT 
    CHECK
    UNITCHECK

    __ANON__ 

    AUTOLOAD
)];

our %WIZARDS;
our %IGNORE;
our %FINALIZERS;
our %SEMAFORE;

our $INDENT = 0;

sub import {
    shift;

    my $pkg = caller;

    $FINALIZERS{ $pkg } = [] unless exists $FINALIZERS{ $pkg };
    $SEMAFORE{ $pkg }   = 0;
    $IGNORE{ $pkg }     = {  map { $_ => undef } @{ DEFAULT_IGNORED_KEYS() } };
    $WIZARDS{ $pkg }    = wizard(
        data     => sub { $_[1] },
        fetch    => sub {
            return if $SEMAFORE{ $pkg };
            $SEMAFORE{ $pkg } = 1;            
            my ($stash, $to_ignore, $key) = @_;
            _log("... attempting to fetch $key in $pkg") if DEBUG;
            return if exists $to_ignore->{ $key };
            return if exists $stash->{ $key };
            {
                no strict 'refs';
                my @mro = @{ mro::get_linear_isa( $pkg ) };
                shift @mro;
                for my $class ( @mro ) {
                    _log("... looking for $key in $class (on behalf of $pkg)") if DEBUG;
                    if ( exists ${ $class . '::'}{ $key } ) {
                        _log("GOT THE KEY!!!! $key in $class for $pkg") if DEBUG;
                        return;
                    }
                }
            }
            die "[PACKAGE FINALIZED] The package ($pkg) has been finalized, attempt to access key ($key) is not allowed";
            $SEMAFORE{ $pkg } = 0;
        },
        delete   => sub {
            $SEMAFORE{ $pkg } = 1;
            my ($stash, $to_ignore, $key) = @_;
            _log("... attempting to delete $key in $pkg") if DEBUG;
            return if exists $to_ignore->{ $key };
            return if exists $stash->{ $key };
            {
                no strict 'refs';
                my @mro = @{ mro::get_linear_isa( $pkg ) };
                shift @mro;
                for my $class ( @mro ) {
                    _log("... looking for $key in $class (on behalf of $pkg)") if DEBUG;
                    if ( exists ${ $class . '::'}{ $key } ) {
                        _log("GOT THE KEY!!!! $key in $class for $pkg") if DEBUG;
                        return;
                    }
                }
            }
            die "[PACKAGE FINALIZED] The package ($pkg) has been finalized, attempt to delete key ($key) is not allowed";
            $SEMAFORE{ $pkg } = 0;
        },        
        store    => sub { 
            $SEMAFORE{ $pkg } = 1;
            my ($stash, $to_ignore, $key) = @_;
            _log("... attempting to store into $key in $pkg") if DEBUG;
            return if exists $to_ignore->{ $key };
            return if exists $stash->{ $key };
            {
                no strict 'refs';
                my @mro = @{ mro::get_linear_isa( $pkg ) };
                shift @mro;
                for my $class ( @mro ) {
                    _log("... looking for $key in $class (on behalf of $pkg)") if DEBUG;
                    if ( exists ${ $class . '::'}{ $key } ) {
                        _log("GOT THE KEY!!!! $key in $class for $pkg") if DEBUG;
                        return;
                    }
                }
            }            
            die "[PACKAGE FINALIZED] The package ($pkg) has been finalized, attempt to store into key ($key) is not allowed";
            $SEMAFORE{ $pkg } = 0;
        },
    );

    # set up the UNITCHECK hook
    Devel::Hook->push_UNITCHECK_hook(sub {
        _log("{\n") if DEBUG;
        $INDENT++;            
        _log("running finalizers for $pkg ...") if DEBUG;
        $_->() for @{ $FINALIZERS{ $pkg } };
        _log("... finalizers for $pkg have been run, preparing the stash for locking") if DEBUG;
        {
            no strict   'refs';
            no warnings 'once';
            cast %{ $pkg.'::' }, $WIZARDS{ $pkg }, $IGNORE{ $pkg };
        }
        _log("... finalization complete for $pkg") if DEBUG;
        $INDENT--;
        _log("}\n") if DEBUG;
    });

    # now install the FINALIZE sub and lift it 
    {
        no strict 'refs';
        *{$pkg.'::FINALIZE'} = sub (&) { push @{ $FINALIZERS{ $pkg } } => $_[0]; return };
    }
    Devel::BeginLift->setup_for( $pkg => [ 'FINALIZE' ] );
}

sub add_finalizer_for {
    my (undef, $pkg, $callback) = @_;
    die "No finalizers available for $pkg, perhaps you forgot to `use Package::Finalize` for $pkg" 
        unless exists $FINALIZERS{ $pkg };
    push @{ $FINALIZERS{ $pkg } } => $callback;
    return;
}

sub _log {
    my ($msg) = @_;
    warn(( ' ' x ($INDENT * 2) ), $msg);
}

1;

__END__