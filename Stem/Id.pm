#  File: Stem/Id.pm

#  This file is part of Stem.
#  Copyright (C) 1999, 2000, 2001 Stem Systems, Inc.

#  Stem is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.

#  Stem is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.

#  You should have received a copy of the GNU General Public License
#  along with Stem; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

#  For a license to use the Stem under conditions other than those
#  described here, to purchase support for this software, or to purchase a
#  commercial warranty contract, please contact Stem Systems at:

#       Stem Systems, Inc.		781-643-7504
#  	79 Everett St.			info@stemsystems.com
#  	Arlington, MA 02474
#  	USA

package Stem::Id ;

use strict ;

=pod

This module generates unique Id strings for use as names in Stem
addresses. Its most common use is by parent Cells which clone
themselves and need a unique Target. The parent Cell uses its Cell
name and the new Target to register the cloned Cell.

=cut

my $attr_spec = [

	{
		'name'		=> 'size',
		'default'	=> 6,
		'help'		=> <<HELP,
This sets the number of characters in the Id.  It defaults to 6.
HELP
	},

] ;

=head2 new

The new method constructs a Stem::Id object. It initializes the Id
string to a string of 'a's. The string size determines how long this
object can go before it has to reuse previously deleted Id strings.

=cut

sub new {

	my( $class ) = shift ;

	my $self = Stem::Class::parse_args( $attr_spec, @_ ) ;
	return $self unless ref $self ;

	my $size = $self->{'size'} ;

	$self->{'start'}  = 'a' x $size ;
	$self->{'next'}	  = 'a' x $size ;
	$self->{'end'}	  = 'a' x ( $size + 1 ) ;
	$self->{'in_use'} = {} ;

	return $self ;
}

=head2 next

The next method returns the next available Id in the object and marks
that as in use.  It fails if all possible Id's are in use.

=cut

sub next {

	my( $self ) = @_ ;

	my $next = $self->{'next'} ;
	my $curr_next = $next ;
	my $end = $self->{'end'} ;
	my $in_use = $self->{'in_use'} ;
	
	while( exists( $in_use->{$next} ) ) {

		$next++ ;

# fail if we looped around.

#print "curr $curr_next $next\n" ;

		return if $next eq $curr_next ;

		$next = $self->{'start'} if $next eq $end ;
	}

	$in_use->{$next} = 1 ;
	$self->{'next'} = $next ;

	return $next ;
}

=head2 delete

The delete method allows this Id to be reused by a call to the next
method.

=cut

sub delete {

	my( $self, $id ) = @_ ;

	delete $self->{'in_use'}{ $id } ;
}

=head2 dump

The dump method returns a the list of Ids that are in use.  used. It
either returns the list of keys or an anonymous array with them
depending on the calling context.

=cut

sub dump {

	my( $self ) = @_ ;

	return( wantarray ? keys %{ $self->{'in_use'} } :
			  [ keys %{ $self->{'in_use'} } ] ) ;
}

1 ;
