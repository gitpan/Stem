#  File: Stem/Packet.pm

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

package Stem::Packet ;

use strict ;

use Stem::Class ;

my $attr_spec = [

	{
		'name'		=> 'codec',
		'env'		=> 'packet_codec',
		'default'	=> 'Data::Dumper',
		'help'		=> <<HELP,
HELP
	},
	{
		'name'		=> 'object',
		'type'		=> 'object',
		'help'		=> <<HELP,
If an object is passed in, the filter will use it for callbacks
HELP
	},
	{
		'name'		=> 'packet_method',
		'default'	=> 'packet_out',
		'help'		=> <<HELP,
HELP
	},

	{
		'name'		=> 'data_method',
		'default'	=> 'packet_data',
		'help'		=> <<HELP,
HELP
	},

] ;

sub new {

	my( $class ) = shift ;

	my $self = Stem::Class::parse_args( $attr_spec, @_ ) ;
	return $self unless ref $self ;

# handle the case of the codec keyword with no value

	$self->{'codec'} ||= 'Data::Dumper' ;

	my $codec_class = "Stem::Codec::$self->{'codec'}" ;

	eval "require $codec_class" ;

	die "Unknown Stem codec '$codec_class'" if $@ ;

	$self->{'codec_obj'} = $codec_class->new() ;

	return $self ;
}

sub to_packet {

	my $self = shift ;

	return unless @_ ;

	my $packet_text = ${$self->{'codec_obj'}->encode( shift )} ;

	my $size = length( $packet_text ) ;

# wrap the packet text with a size/codec/end pair of lines

	$packet_text = "#$size:$self->{'codec'}\012$packet_text\012#END\012" ;

#print "PACK [$packet_text]\n" ;

	if ( my $obj = $self->{'object'} ) {

		my $method = $self->{'packet_method'} ;

		$obj->$method( \$packet_text ) ;

		return ;
	}

	return \$packet_text ;
}

sub to_data {

	my( $self, $input ) = @_ ;

	$input = '' unless defined $input ;

	my $buf_ref = \$self->{'buffer'} ;

	${$buf_ref} .= ( ref $input ) ? ${$input} : $input ;

#print "BUF [${$buf_ref}]\n" ;

	my $codec_class = $self->{'codec'} ;
	my $codec = $self->{'codec_obj'} ;

	while( 1 ) {

		my $size = $self->{'size'} ;

		unless ( $size ) {

# grab the size if we can from the header line

			return unless ${$buf_ref} =~
					s/\A#(\d+):$codec_class\012// ;

			$size = $1 ;

			$self->{'size'} = $size ;
		}

# see if we have a full packet with end line

		return if length( ${$buf_ref} ) < $size ;
		return unless substr( ${$buf_ref}, $size, 6 ) eq 
							"\012#END\012" ;

		$self->{'size'} = 0 ;

local( $SIG{'__WARN__'} ) = sub {} ;

		my $decoded_data = $codec->decode(
				substr( ${$buf_ref}, 0, $size + 6, '' )
		) ;

		if ( my $obj = $self->{'object'} ) {

			my $method = $self->{'data_method'} ;

			$obj->$method( $decoded_data ) ;

			next ;
		}

		return( $decoded_data ) ;
	}
}

1 ;
