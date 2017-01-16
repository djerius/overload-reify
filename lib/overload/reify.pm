package overload::reify;

use 5.006;

# ABSTRACT: Provide named methods for inherited overloaded operators

use strict;
use warnings;

our $VERSION = '0.01';

use overload ();
use Carp;

my %OP = (

    # grab 'em all
    (
        map +( $_ => undef ),
        grep( $_ ne 'fallback',
            map( split( /\s+/, $_ ), values %overload::ops ) )
    ),

    # and update those we known with a method name
    # anything undef will trigger an error in the test suite.

    # with_assign     	=> '+ - * / % ** << >> x .',
    '+'  		=> 'add',
    '-'  		=> 'subtract',
    '*'  		=> 'multiply',
    '/'  		=> 'divide',
    '%'  		=> 'modulus',
    '**' 		=> 'pow',
    '<<' 		=> 'lshift',
    '>>' 		=> 'rshift',
    'x'  		=> 'repetition',
    '.'  		=> 'append',

    # assign          	=> '+= -= *= /= %= **= <<= >>= x= .='
    '+='  		=> 'add_assign',
    '-='  		=> 'subtract_assign',
    '*='  		=> 'multiply_assign',
    '/='  		=> 'divide_assign',
    '%='  		=> 'modulus_assign',
    '**=' 		=> 'pow_assign',
    '<<=' 		=> 'lshift_assign',
    '>>=' 		=> 'rshift_assign',
    'x='  		=> 'repetition_assign',
    '.='  		=> 'append_assign',

    # num_comparison    => '< <= > >= == !=',
    '<'  		=> 'numeric_lt',
    '<=' 		=> 'numeric_le',
    '>'  		=> 'numeric_gt',
    '>=' 		=> 'numeric_ge',
    '==' 		=> 'numeric_eq',
    '!=' 		=> 'numeric_ne',

    # '3way_comparison' => '<=> cmp',
    '<=>' 		=> 'numeric_cmp',
    'cmp' 		=> 'string_cmp',

    # str_comparison    => 'lt le gt ge eq ne',
    'lt' 		=> 'string_lt',
    'le' 		=> 'string_le',
    'gt' 		=> 'string_gt',
    'ge' 		=> 'string_ge',
    'eq' 		=> 'string_eq',
    'ne' 		=> 'string_ne',

    # binary            => '& &= | |= ^ ^= &. &.= |. |.= ^. ^.=',
    '&'   		=> 'binary_and',
    '&='  		=> 'binary_and_assign',
    '|'   		=> 'binary_or',
    '|='  		=> 'binary_or_assign',
    '^'   		=> 'binary_xor',
    '^='  		=> 'binary_xor_assign',
    '&.'  		=> 'binary_string_and',
    '&.=' 		=> 'binary_string_and_assign',
    '|.'  		=> 'binary_string_or',
    '|.=' 		=> 'binary_string_or_assign',
    '^.'  		=> 'binary_string_xor',
    '^.=' 		=> 'binary_string_xor_assign',

    # unary         	=> 'neg ! ~ ~.',
    'neg' 		=> 'neg',
    '!'   		=> 'not',
    '~'   		=> 'bitwise_negation',
    '~.'  		=> 'bitwise_string_negation',


    # mutators      	=> '++ --',
    '++' 		=> 'increment',
    '--' 		=> 'decrement',

    # func          	=> 'atan2 cos sin exp abs log sqrt int',
    'atan2' 		=> 'atan2',
    'cos'   		=> 'cos',
    'sin'   		=> 'sin',
    'exp'   		=> 'exp',
    'abs'   		=> 'abs',
    'log'   		=> 'log',
    'sqrt'  		=> 'sqrt',
    'int'   		=> 'int',

    # conversion    	=> 'bool "" 0+ qr',
    'bool' 		=> 'bool',
    '""'   		=> 'stringify',
    '0+'   		=> 'numerify',
    'qr'   		=> 'regexp',

    # iterators     	=> '<>',
    '<>' 		=> 'null_filehandle',

    # filetest      	=> '-X',
    '-X' 		=> 'filetest',

    # dereferencing 	=> '${} @{} %{} &{} *{}',
    '${}' 		=> 'scalar_deref',
    '@{}' 		=> 'array_deref',
    '%{}' 		=> 'hash_deref',
    '&{}' 		=> 'code_deref',
    '*{}' 		=> 'glob_deref',

    # matching      	=> '~~',
    '~~' 		=> 'smartmatch',

    # special       	=> 'nomethod fallback ='
    'nomethod' 		=> 'nomethod',
    '='        		=> 'copy_constructor',
);


# operator overloads are stored in the symbol table as "($op"
#
# if the overload is a coderef
#    *{$symbol}{CODE} = $coderef
#
# if the overload is a $method_name
#    *{$symbol}{CODE}   = \&overload::nil (or ::_nil)
#    *{$symbol}{SCALAR} = $method_name
#
# cribbed from Role::Tiny

# stolen from Role::Tiny
sub _getglob {
    ## no critic( ProhibitNoStrict )
    no strict 'refs';
    \*{ $_[0] };
}


sub import {

    my $class = shift;

    my %opt = (
	-methods => 1,
        -prefix => 'operator_',
        'HASH' eq ref $_[-1] ? %{ pop() } : (),
    );


    my $into = delete( $opt{-into} ) || caller;
    my $wrap_methods = delete $opt{-methods};
    my $method_name_prefix = delete $opt{-prefix};

    croak( "unknown options: ", keys %opt ) if %opt;

    my %install;

    my @args = @_;
    while ( @args ) {

        my $arg = shift @args;

        if ( $arg eq '-not' ) {

	    # if first is an exclusion, populate
            @install{ _ops( ':all' ) } = 1
              unless %install;

            $arg = shift @args
              or croak( "missing operator after -not\n" );

	    $arg = [ $arg ] unless 'ARRAY' eq ref $arg;

            delete @install{ _ops( $_ ) } foreach @$arg
        }
        else {
            @install{ _ops( $arg ) } = 1;
        }
    }

    # default to all if not specified, but only if no arguments were
    # passed. that way if the caller (mistakenly?) excludes everything
    # it gets what it asks for.
    @install{ _ops( ':all' ) } = 1
	unless %install || @_;

    for my $op ( keys %install ) {

        my $symbol = '(' . $op;

        my $glob = overload::mycan( $into, $symbol );
	next unless defined $glob;

        my $coderef = *{$glob}{CODE};
        next unless defined $coderef;

        # method name ?
        my $method_name;
        if (
            ( defined &overload::nil && $coderef == \&overload::nil )
            || ( defined &overload::_nil
                && $coderef == \&overload::_nil ) )
        {

            $method_name = ${ *{$glob}{SCALAR} };
            # weird but possible?
            next unless defined $method_name;
        }

	# it's a real method; only rewire if requested to do so
        if ( defined $method_name ) {
            next unless $wrap_methods;
	    ## no critic(ProhibitStringyEval)
            $coderef
              = eval "package $into; sub { shift()->$method_name(\@_) }";
        }

        # (re)wire the overload to use a new method name

        $method_name = $method_name_prefix . $OP{$op};

        *{ _getglob "${into}::${method_name}" } = $coderef;
        $glob  = _getglob "${into}::${symbol}";
        *$glob = \$method_name;
        no warnings 'redefine';
        *$glob = defined &overload::nil ? \&overload::nil : \&overload::_nil;
    }
}

sub _ops {

    my ( $op ) = @_;

    return $op if defined $OP{$op};
    return keys %OP if $op eq ':all';

    my ( $tag ) = $op =~ /^:(.*)$/;

    return grep( $_ ne 'fallback', $overload::ops{$tag} )
      if defined $overload::ops{$tag};

    croak( "unknown operator or tag: $op\n" );
    return;
}

=method method_names

  # from the command line:
  perl -Ilib -MData::Dumper -Moverload::reify \
     -e 'print Dumper overload::reify->method_names()'

  # in code 
  $hashref = overload::reify->method_names( %options );

This class method returns a hashref whose keys are operators and whose
values are the names of generated methods.  The available options are:

=over

=item C<-prefix>

The prefix for the names of the generated method names.  It defaults to
C<operator_>.

=back

=cut

sub method_names {

    my $class = shift;

    my %opt = ( -prefix => 'operator_', @_ );

    return { map +($_ => $opt{-prefix} . $OP{$_}), keys %OP };
};


1;

# COPYRIGHT

__END__


=head1 SYNOPSIS

  { package Parent;
    use overload
      '+=' => 'plus_equals',
      '++' => sub { ... };

    # ...

    sub plus_equals { ... }
  }

  { package Child1;

    use Parent;

    use overload::reify;

    # this creates new methods:
    #
    #  operator_increment()
    #    performs the ++ operation
    #
    #  operator_add_assign()
    #    comparable to plus_equals(), but modifying
    #    it won't modify plus_equals

  }

  { package Child2;

    use Parent;

    # don't create methods for overloads with method names
    use overload::reify { -methods => 0 };

    # this creates new methods:
    #
    #  operator_increment()
    #    performs the ++ operation
  }

=head1 DESCRIPTION

This pragma creates named methods for inherited operator overloads.
The child may then modify them using such packages as L<Moo>,
L<Moose>, or L<Class::Method::Modifers>.

=head2 Background

When a package overloads an operator it provides either a method
name or a coderef, e.g.

  overload
    '++' => 'plus_plus',
    '--' => sub { ..., }

In the latter case, the overloaded subroutine cannot be modfied via
e.g., the B<around> subroutine in
L<Class::Method::Modifiers|Class::Method::Modifiers/around> (or
L<Moo|Moo/around> or L<Moose|Moose/around>) as it has no named symbol
table entry.

B<overload::reify> installs named methods in a package's symbol table for
overloaded operators. The methods for operators which already
utilize a method name are wrappers which call the original methods by
name.  For operators using coderefs, the generated methods alias
the coderefs.  A mapping of operators to method names is available via
the L</method_names> method.

By default named methods are constructed for I<all> overloaded
operators, regardless of how they are implemented (providing the child
class a uniform naming scheme). If this is not desired, set the
C<-methods> option to false.

=head2 Usage

The pragma is invoked with the following template:

  use overload::reify @operators, ?\%options;

where C<@operators> is a list of strings, each of which may contain:

=over

=item *

an operator to be considered, e.g. C<'++'>;

=item *

a tag (in the form C<:>I<class>) representing a class
of operators. A class may be any of the keys accepted by the
L<overload|overload/Overloadable Operations> pragma, as well as the
special class C<all>, which consists of all operators.

=item *

the token C<-not>, indicating that the next operator is to be excluded
from consideration.  If C<-not> is the first element in the list of
operators, the list is pre-seeded with all of the operators.

=back

and C<%options> is a hash with one or more of the following keys:

=over

=item C<-into>

The package into which the methods will be installed.  This defaults
to the calling package.

=item C<-methods>

A boolean indicating whether or not wrappers will be generated for overloaded operators with named methods.  This defaults to I<true>.

=item C<-prefix>

The prefix for the names of the generated method names.  It defaults to
C<operator_>.

=back

=head1 SEE ALSO

L<Class::Method::Modfiers>, L<Moo>, L<Moose>.

=head1 CONTRIBUTORS

Thanks to

=over

=item *

L<MSTROUT|https://metacpan.org/author/MSTROUT> for the
suggestion to house this code in its own module.

=item *
L<HAARG|https://metacpan.org/author/HAARG> for reviewing
an initial version of this code.

=back

