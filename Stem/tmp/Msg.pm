#  File: Stem/tmp/Msg.pm

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

package Stem::TTY::Msg ;

use Data::Dumper ;
use Stem::AsyncIO ;

use vars qw( $tty_obj ) ;

#########################
# no attributes for now
#########################

my $attr_spec = [

] ;


sub new {

	my( $class ) = shift ;

	my $self = Stem::Class::parse_args( $attr_spec, @_ ) ;
	return $self unless ref $self ;

	my $aio = Stem::AsyncIO->new(

			'object'	=> $self,
			'read_fh'	=> \*STDIN,
			'write_fh'	=> \*STDOUT,
			'read_method'	=> 'stdin_read',
			'closed_method'	=> 'stdin_closed',
	) ;

	$self->{'aio'} = $aio ;

	$tty_obj = $self ;

	return( $self ) ;
}

sub stdin_read {

	my( $self, $line_ref ) = @_ ;

	my $line = ${$line_ref} ;

	chomp( $line ) ;

#print ::BUG "[$line]\n" ;
#print "[$line]\n" ;

	if ( $line =~ /^quit\s*$/i ) {

		exit ;
	}

	if ( $line =~ /^help\s*$/i ) {

		$self->help() ;
		$self->prompt() ;
		return ;
	}

	if ( $line =~ /^(\w*):(\w+)((?:\s+).*)/ ) {

		my $hub_name = $1 ;
		my $cell_name = $2 ;
		my( $cmd_name, $cmd_data ) = split( ' ', $3, 2 ) ;

#print "tty N[$hub_name] O[$cell_name] C[$cmd_name]\n" ;

		my $msg = Stem::Msg->new(
				'to_cell'	=> $cell_name,
				'to_hub'	=> $hub_name,
				'from_cell'	=> __PACKAGE__,
				'type'		=> 'cmd',
				'cmd'		=> $cmd_name,
				'data'		=> $cmd_data,
		) ;

print $msg->dump() ;


		$msg->dispatch() ;

		return ;

	}

	$self->write( <<ERR ) ;
Missing Hub:Object address in line:

$line

ERR
	$self->prompt() ;
}

sub msg_in {

	my( $self, $msg ) = @_ ;

	my( $data ) ;

	$self = $tty_obj unless ref $self ;

	$data = $msg->data() ;

#print $msg->dump( 'TTY' ) ;

	$data = Dumper( $data ) if ref $data ;

#print ::BUG "M [$data]\n" ;

	$self->write( $data ) ; 

	$self->prompt() ;
}

sub write {

	my( $self, $text ) = @_ ;

	$self->{'aio'}->write( $text) ;
}


sub prompt {

	my( $self ) = @_ ;

	return unless $self->{'prompt'} ;

	$self->write( $self->{'prompt'} ) ;
}

sub help {

	my( $self ) = @_ ;

	$self->write( <<HELP ) ;

Stem::TTY Help:

The first token must have a colon, that is parsed into the hub:object for
the command.  The rest of the line is passed as data to the object.

HELP

}

sub stdin_closed {

	my( $self ) = @_ ;

	*STDIN->clearerr() ;

	$self->write( "EOF (ignored)\n" ) ;

	$self->prompt() ;
}

1 ;
