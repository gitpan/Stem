#  File: Stem/LoadBalance.pm

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

package Stem::LoadBalance ;

use strict ;
use Data::Dumper ;

use Stem::Id ;
use Stem::Route qw( :cell ) ;


my $attr_spec = [

	{
		'name'		=> 'reg_name',
		'required'	=> 1,
		'help'		=> <<HELP,
HELP
	},

	{
		'name'		=> 'host',
		'help'		=> <<HELP,
HELP
	},

	{
		'name'		=> 'port',
		'required'	=> 1,
		'help'		=> <<HELP,
HELP
	},

	{
		'name'		=> 'id_size',
		'default'	=> 3,
		'help'		=> <<HELP,
HELP
	},

] ;


sub new {

	my( $class ) = shift ;

	my $self = Stem::Class::parse_args( $attr_spec, @_ ) ;
	return $self unless ref $self ;

	my $server_obj = Stem::Socket->new( 
				'object'	=> $self,
				'host'		=> $self->{'host'},
				'port'		=> $self->{'port'},
				'method'	=> 'server_connected',
				'server'	=> 1,
	) ;

	return $server_obj unless ref $server_obj ;

	$self->{'server_obj'} = $server_obj ;

	$self->{'id_obj'} = Stem::Id->new( 'size' => $self->{'id_size'} ) ;

	return( $self ) ;
}


sub _server_connected {

	my( $self, $connected_sock ) = @_ ;

	my $id = $parent_info->{'id_obj'}->next() ;


	my $map = {
		'id'		=> $id,
		'server_sock'	=> $connected_sock,
	} ;

	my $server_obj = Stem::Socket->new( 
				'object'	=> $self,
				'host'		=> $self->{'host'},
				'port'		=> $self->{'port'},
				'server'	=> 1,
	) ;

	$map->{'info'} = sprintf( <<INFO,

Sock::Msg
Type:	$type
Cell:	$cell_status
Local:	%s:%d
Remote:	%s:%d

INFO
				$connected_sock->sockhost(),
				$connected_sock->sockport(),
				$connected_sock->peerhost(),
				$connected_sock->peerport(),
	) ;


# pick a client host/port

	my $client_obj = Stem::Socket->new( 
				'object'	=> $self,
				'host'		=> $host,
				'port'		=> $port
				'method'	=> 'client_connected',
				'timeout_method' => 'client_timed_out',
	) ;


	if ( $self->{ 'log_connections' } ) {

		Stem::Log::entry(
				'log'	=> $self->{'log_name'},
				'text'	=> $self->{'info'},
		);
	}


	$self->{'maps'}{$id} = $map ;
}


sub _client_connected {

	my( $self, $connected_sock, $id ) = @_ ;

	$map = $self->{'maps'}{$id} ;

	$map->{'server_aio'} = Stem::AsyncIO->new(

			'object'	=> $self,
			'fh'		=> $self->{'server_sock'},
			'read_method'	=> 'server_read',
			'closed_method'	=> 'server_closed',
			'private'	=> $id,
	) ;

	$map->{'client_aio'} = Stem::AsyncIO->new(

			'object'	=> $self,
			'fh'		=> $self->{'client_sock'},
			'read_method'	=> 'client_read',
			'closed_method'	=> 'client_closed',
			'private'	=> $id,
	) ;

# log it

}


sub _server_read {

	my( $self, $data_ref, $id ) = @_ ;

#print "\nD $self\n", Dumper $self ;

	my $client_aio = $self->{'maps'}{$id}{'client_aio'} ;

	$client_aio->write( $data_ref ) ;
}

sub _server_closed {

	my( $self, $id ) = @_ ;

	$self->shut_down_map( $id ) ;

# log it
}


sub _client_read {

	my( $self, $data_ref, $id ) = @_ ;


#print "\nD $self\n", Dumper $self ;

	my $server_aio = $self->{'maps'}{$id}{'server_aio'} ;

	$server_aio->write( $data_ref ) ;
}

sub _client_closed {

	my( $self, $id ) = @_ ;

	$self->shut_down_map( $id ) ;

# log it
}


sub _shut_down_map {

	my( $self, $id ) = @_ ;

	my $map = $self->{'maps'}{$id} ;

	$map->{'client_aio'}->shut_down() ;
	$map->{'server_aio'}->shut_down() ;
	delete( $map->{'client_aio'} ) ;
	delete( $map->{'server_aio'} ) ;

	close( $map->{'client_sock'} ) ;
	close( $map->{'server_sock'} ) ;

	delete( $self->{'maps'}{$id} ) ;

	$self->{'id_obj'}->delete( $id ) ;
}


# have the parent cleanup after one of it's clones is done.

sub _shut_down {

	my( $self ) = @_ ;

}


1 ;
