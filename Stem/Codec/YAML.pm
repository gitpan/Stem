#  File: Stem/Codec/YAML.pm

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

package Stem::Codec::YAML ;


use strict ;

use YAML () ;

use Stem::Class ;

my $attr_spec = [

	{
		'name'		=> 'object',
		'type'		=> 'object',
		'help'		=> <<HELP,
If an object is passed in, the filter will use it for callbacks
HELP
	},

	{
		'name'		=> 'encode_method',
		'default'	=> 'encoded_data',
		'help'		=> <<HELP,
HELP
	},

	{
		'name'		=> 'decode_method',
		'default'	=> 'decoded_data',
		'help'		=> <<HELP,
HELP
	},

] ;

sub new {

	my( $class ) = shift ;

	my $self = Stem::Class::parse_args( $attr_spec, @_ ) ;
	return $self unless ref $self ;

	return $self ;
}

sub encode {

	my $self = shift ;

	return unless @_ ;

	my $encoded_text = YAML::Dump( shift ) ;

	if ( my $obj = $self->{'object'} ) {

		my $method = $self->{'encode_method'} ;

		$obj->$method( \$encoded_text ) ;

		return ;
	}

	return \$encoded_text ;
}

sub decode {

	my( $self, $input ) = @_ ;

	$input = ${$input} if ref $input ;

#print "IN [$input]\n" ;
	my $decoded_data = YAML::Load( $input ) ;

	if ( my $obj = $self->{'object'} ) {

		my $method = $self->{'decode_method'} ;

		$obj->$method( $decoded_data ) ;

		return ;
	}

	return( $decoded_data ) ;
}

1 ;
