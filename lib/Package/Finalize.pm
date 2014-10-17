package Package::Finalize;

use strict;
use warnings;
use mro;

use Devel::Hook;
use Devel::BeginLift;
use List::AllUtils qw[ uniq ];
use Hash::Util     qw[ 
    unlock_keys
    lock_keys 
    lock_keys_plus
    lock_value 
    legal_keys 
    hash_locked 
];

use constant DEBUG => $ENV{'DEBUG_PACKAGE_FINALIZE'};

our %STUBBED_KEYS;
our %FINALIZERS;

our $INDENT = 0;

sub import {
    shift;

    my $pkg = caller;

    $FINALIZERS{ $pkg }   = [] unless exists $FINALIZERS{ $pkg };
    $STUBBED_KEYS{ $pkg } = [] unless exists $STUBBED_KEYS{ $pkg };

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

            my @std_keys_to_delete = ('FINALIZE');
            my %std_keys_to_add = (
                import    => 'CODE',
                unimport  => 'CODE',

                VERSION   => 'SCALAR',
                AUTHORITY => 'SCALAR',

                BEGIN     => 'CODE',
                __ANON__  => 'CODE',
            );

            _log("... creating a few keys in the $pkg stash that are expected to exists") if DEBUG;
            foreach my $k ( keys %std_keys_to_add ) {
                my $type = $std_keys_to_add{ $k };
                if ( $type eq 'CODE' ) {
                    unless ( *{ $pkg . '::' . $k }{'CODE'} ) {
                        *{ $pkg . '::' . $k } = sub {};
                        push @std_keys_to_delete => $k;
                    }
                }
                elsif  ( $type eq 'SCALAR' ) {
                    unless ( ${ $pkg . '::' . $k } ) {
                        ${ $pkg . '::' . $k } = undef;
                        push @std_keys_to_delete => $k;
                    }
                }
            }

            _log("... actually handing \@ISA specifically since it is special") if DEBUG;
            @{$pkg.'::ISA'} = () unless @{$pkg.'::ISA'};
            {
                my @MRO = @{ mro::get_linear_isa( $pkg ) };
                shift @MRO; # we can ignore ourselves

                my @all_methods;
                foreach my $class ( @MRO ) {
                    die "Cannot inherit from a class ($class) which does not have a locked stash"
                        unless hash_locked(%{$class . '::'});
                    push @all_methods => grep { 
                        $_ ne 'FINALIZE' && *{$class . '::' . $_}{'CODE'} 
                    } keys %{$class . '::'};
                }

                @all_methods = uniq @all_methods;

                _log("... collected all possible methods for $pkg : [ " . (join ", " => sort(@all_methods))  . " ]" ) if DEBUG;
                _log("... Stubbing local methods (as needed) for package $pkg") if DEBUG;
                foreach my $method ( @all_methods ) {
                    unless ( *{ $pkg . '::' . $method }{'CODE'} ) {
                        _log("... !!No local method $method for package $pkg is missing, so we are stubbing one out") if DEBUG;
                        *{ $pkg . '::' . $method } = sub {};
                        push @std_keys_to_delete => $method;
                    }
                }

                if ( 1 < scalar @{$pkg.'::ISA'} ) {
                    _log("We have multiple inheritance in $pkg, adjusting things accordingly") if DEBUG;
                    my %seen;
                    foreach my $class ( @{$pkg.'::ISA'} ) {
                        _log("... Stubbing local methods (as needed) for package $class") if DEBUG;
                        my @keys_to_delete;
                        unlock_keys( %{ $class.'::' } ); # assume it has already been compiled and locked ...
                        foreach my $method ( @all_methods ) {
                            # skip if we've already seen it
                            next if $seen{ $method };
                            # mark it seen if it is local
                            $seen{ $method } = 1 if *{ $class . '::' . $method }{'CODE'};
                            # and if we haven't seen it 
                            # and it is not local, then 
                            # install a stub
                            unless ( *{ $class . '::' . $method }{'CODE'} ) {
                                _log("... !!No local method $method for package $class is missing, so we are stubbing one out") if DEBUG;
                                *{ $class . '::' . $method } = sub {};
                                push @keys_to_delete => $method;
                            }
                        }
                        lock_keys_plus( %{ $class.'::' }, @{ $STUBBED_KEYS{ $class } } );
                        delete_stubbed_keys( $class, \@keys_to_delete, \%std_keys_to_add );
                        push @{ $STUBBED_KEYS{ $class } } => @keys_to_delete;
                        lock_value(  %{ $class.'::' }, $_ ) for keys %{ $class.'::' };
                    }
                }
            }

            _log("... actually locking keys of the $pkg stash (which now has all the possible keys we might access)") if DEBUG;
            lock_keys( %{ $pkg.'::' } );
            _log("... the following keys for $pkg have been locked [ " . (join ", " => sort(legal_keys( %{ $pkg.'::' } ))) . " ]") if DEBUG;
            delete_stubbed_keys( $pkg, \@std_keys_to_delete, \%std_keys_to_add );
            push @{ $STUBBED_KEYS{$pkg} } => @std_keys_to_delete;
            lock_value(  %{ $pkg.'::' }, $_ ) for keys %{ $pkg.'::' };
        }
        _log("... finalization complete for $pkg") if DEBUG;
        $INDENT--;
        _log("}\n") if DEBUG;
    });

    {
        no strict 'refs';
        *{$pkg.'::FINALIZE'} = sub (&) { push @{ $FINALIZERS{ $pkg } } => $_[0]; return };
    }
    Devel::BeginLift->setup_for( $pkg => [ 'FINALIZE' ] );
}

sub delete_stubbed_keys {
    my ($pkg, $keys_to_delete, $key_types) = @_;
    _log("... removing all the keys we stubbed in $pkg [ " . (join ", " => sort(@$keys_to_delete)) . " ]") if DEBUG;    
    no strict 'refs';
    foreach my $k ( @$keys_to_delete ) {
        next if not exists ${ $pkg . '::' }{ $k }; # short circuit this ...
        # this is the field we want to remove ...
        my $type = $key_types->{ $k } || 'CODE';
        # delete and grab the glob 
        my $glob = delete ${ $pkg . '::' }{ $k };
        # stash all the types in the glob
        my %to_save;
        foreach my $t (qw[ SCALAR ARRAY HASH CODE IO ]) {
            if ( my $val = *{$glob}{ $t } ) {
                $to_save{ $type } = $val;
            }
        }
        # remove the type you wanted to delete
        delete $to_save{ $type };
        # now restore the glob ...
        foreach my $t ( keys %to_save ) {
            *{ $pkg.'::' . $k } = $to_save{ $t };
        }
    }
}

sub _log {
    my ($msg) = @_;
    warn(( ' ' x ($INDENT * 2) ), $msg);
}

1;

__END__