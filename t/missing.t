#!perl

use Test2::Bundle::Extended;

use overload::reify;

my %excluded = ( 'fallback' => 1 ) ;

my @ops
  = grep( !$excluded{$_}, map( split( /\s+/, $_ ), values %overload::ops ) );

my $name = overload::reify->method_names();

my @missing = grep !defined $name->{$_}, @ops;
is( \@missing, [], "all operators are named" );

my @extra = grep defined $name->{$_}, keys %excluded;
is( \@extra, [], "no extra operators" );

done_testing;
