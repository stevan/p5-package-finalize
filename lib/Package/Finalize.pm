package Package::Finalize;

use strict;
use warnings;
use mro;

use Devel::Hook;
use Devel::BeginLift;
use Variable::Magic qw[ wizard cast ];

use constant DEBUG => $ENV{'DEBUG_PACKAGE_FINALIZE'};

use constant DEFAULT_IGNORED_KEYS => [qw/
    import   
    unimport 

    can
    isa

    VERSION  
    AUTHORITY

    ISA
    DOES
    DESTROY

    ()
    ((
    (""

    BEGIN    
    INIT 
    CHECK
    UNITCHECK

    __ANON__ 

    AUTOLOAD
/];

our %WIZARDS;
our %FINALIZERS;
our %FETCH_SEMAFORE;
our %STORE_SEMAFORE;

our $INDENT = 0;

sub import { 
    my $pkg = shift;
    $pkg->import_into( caller, @_ );
}

sub import_into {
    my (undef, $pkg, @additional_keys_to_ignore) = @_;

    $FINALIZERS{ $pkg }     = [] unless exists $FINALIZERS{ $pkg };
    $FETCH_SEMAFORE{ $pkg } = 0;
    $STORE_SEMAFORE{ $pkg } = 0;
    $WIZARDS{ $pkg }        = wizard(
        data     => sub { $_[1] },
        fetch    => sub {
            # Sometimes we get in an infinite loop
            # because the `store` handler is checking
            # the packages in the MRO and so doing a 
            # bunch of `fetch` operations that we 
            # just really need to ignore, so we do
            return if $FETCH_SEMAFORE{ $pkg };  

            my ($stash, $to_ignore, $key) = @_;
            
            _log("... attempting to fetch <$key> from <$pkg>") if DEBUG;
            
            return if exists $to_ignore->{ $key }; # ignore standard perl stuff and our initial entries ...
            
            # now check the MRO, because the way 
            # method caching works, it will test
            # for method existence at each class
            # in the MRO until it finds it ...
            _log("!!! key <$key> does not exist in <$pkg>, checking MRO to see if this is just method lookup") if DEBUG;
            {                                      
                no strict 'refs';
                my @mro = @{ mro::get_linear_isa( $pkg ) };
                shift @mro;
                for my $class ( @mro ) {
                    _log("... looking for <$key> in <$class> (on behalf of <$pkg>)") if DEBUG;
                    if ( exists ${ $class . '::'}{ $key } ) {
                        _log(">>> found <$key> in <$class> for <$pkg>") if DEBUG;
                        return;
                    }
                }
            }

            _croak("[PACKAGE FINALIZED] The package ($pkg) has been finalized, attempt to access key ($key) is not allowed");
        },
        delete   => sub {
            my ($stash, $to_ignore, $key) = @_;
            _log("... attempting to delete <$key> from <$pkg>") if DEBUG;
            return if exists $to_ignore->{ $key }; # ignore standard perl stuff ...
            _croak("[PACKAGE FINALIZED] The package ($pkg) has been finalized, attempt to delete key ($key) is not allowed");
        },        
        store    => sub { 
            # In some cases we need to ignore
            # the `store` operation, the particular
            # case we have found is within a call 
            # to `can` that will fail, perl will 
            # attempt to store the key because of 
            # how method caching works, so we just 
            # ignore this here.
            return if $STORE_SEMAFORE{ $pkg };

            # wrap this code with the semafore 
            # for the `fetch` operation ...
            $FETCH_SEMAFORE{ $pkg } = 1;

            my ($stash, $to_ignore, $key) = @_;
            
            _log("... attempting to store <$key> into <$pkg>") if DEBUG;
            
            return if exists $to_ignore->{ $key }; # ignore standard perl stuff ...
            
            return if $key =~ /::$/;               # allow the creation of sub-packages ...

            # now check the MRO, because the way 
            # method caching works, it will store
            # a local copy of a method in the 
            # package to help speed up dispatch
            _log("!!! key <$key> does not exist in <$pkg>, checking MRO to see if this is just method caching") if DEBUG;
            {
                no strict 'refs';
                my @mro = @{ mro::get_linear_isa( $pkg ) };
                shift @mro;
                for my $class ( @mro ) {
                    _log("... looking for <$key> in <$class> (on behalf of <$pkg>)") if DEBUG;
                    if ( exists ${ $class . '::'}{ $key } ) {
                        _log(">>> found <$key> in <$class> for <$pkg>") if DEBUG;
                        return;
                    }
                }
            }    

            # turn this off ...        
            $FETCH_SEMAFORE{ $pkg } = 0;             

            _croak("[PACKAGE FINALIZED] The package ($pkg) has been finalized, attempt to store into key ($key) is not allowed");           
        },
    );
 
    # set up the UNITCHECK hook
    Devel::Hook->push_UNITCHECK_hook(sub {
        _log("{\n") if DEBUG;
        $INDENT++;            
        _log("running finalizers for package <$pkg> ...") if DEBUG;
        $_->() for @{ $FINALIZERS{ $pkg } };
        _log("... finalizers for package <$pkg> have been run, now preparing the stash for locking") if DEBUG;
        {
            no strict   'refs';
            no warnings 'once';
            _log("!!! adding a custom &can to <$pkg> to deal with method caching behaviors in `store` operation") if DEBUG;
            *{ $pkg.'::can' } = sub {  
                $STORE_SEMAFORE{ $pkg } = 1;
                my $x = UNIVERSAL::can( @_ );
                $STORE_SEMAFORE{ $pkg } = 0;
                return $x;  
            };
            _log("... marking the following value(s) [" . (join ', ' => keys %{ $pkg.'::' }) . "] as SvREADONLY") if DEBUG;
            Internals::SvREADONLY( ${ $pkg.'::' }{ $_ }, 1 ) for keys %{ $pkg.'::' };
            _log("... applying stash locking magic to package <$pkg>") if DEBUG;
            cast(
                %{ $pkg.'::' }, 
                $WIZARDS{ $pkg }, 
                { 
                    map { $_ => undef } ( 
                        keys %{ $pkg.'::' }, 
                        @additional_keys_to_ignore,                        
                        @{ DEFAULT_IGNORED_KEYS() },
                    ) 
                } 
            );
            _log("... package <$pkg> finalized with the following keys [" . (join ', ' => keys %{ $pkg.'::' }) . "]") if DEBUG;
        }
        _log("... finalization complete for package <$pkg>") if DEBUG;
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
    _croak("No finalizers available for $pkg, perhaps you forgot to `use Package::Finalize` for $pkg") 
        unless exists $FINALIZERS{ $pkg };
    push @{ $FINALIZERS{ $pkg } } => $callback;
    return;
}

sub _log {
    my ($msg) = @_;
    warn(( ' ' x ($INDENT * 2) ), $msg);
}

sub _croak {
    my (undef, $file, $line) = caller(1);
    die @_, " at $file line $line\n";
}

1;

__END__