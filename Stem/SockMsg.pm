#  File: Stem/SockMsg.pm

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

package Stem::SockMsg ;

use strict ;

use Data::Dumper ;

use Stem::Socket ;
use Stem::Trace 'log' => 'stem_status', 'sub' => 'TraceStatus' ;
use Stem::Trace 'log' => 'stem_error' , 'sub' => 'TraceError' ;
use Stem::Route qw( :cell ) ;
use base 'Stem::Cell' ;

my $attr_spec = [

	{
		'name'		=> 'reg_name',
		'help'		=> <<HELP,
The registration name for this Cell
HELP
	},

	{
		'name'		=> 'host',
		'help'		=> <<HELP,
Host address to listen on or connect to
HELP
	},

	{
		'name'		=> 'port',
		'required'	=> 1,
		'help'		=> <<HELP,
Port address to listen on or connect to
HELP
	},

	{
		'name'		=> 'server',
		'type'		=> 'boolean',
		'help'		=> <<HELP,
Mark this Cell as a server (listens for connections)
HELP
	},

	{
		'name'		=> 'connect_now',
		'type'		=> 'boolean',
		'help'		=> <<HELP,
Connect upon Cell creation
HELP
	},

	{
		'name'		=> 'log_name',
		'help'		=> <<HELP,
Log to send connection status to
HELP
	},

	{
		'name'		=> 'cell_attr',
		'class'		=> 'Stem::Cell',
		'help'		=> <<HELP,
Argument list passed to Stem::Cell for this Cell
HELP
	},

] ;


sub new {

	my( $class ) = shift ;

	my $self = Stem::Class::parse_args( $attr_spec, @_ ) ;
	return $self unless ref $self ;


	if ( $self->{'server'} ) {
		my $sock_obj = Stem::Socket->new( 
				'object'	=> $self,
				'host'		=> $self->{'host'},
				'port'		=> $self->{'port'},
				'server'	=> 1,
		) ;

		return $sock_obj unless ref $sock_obj ;

		my $host_text = $self->{'host'} ;

		$host_text = 'localhost' unless defined $host_text ;

		my $info = <<INFO ;
SockMsg
Type:	server
Local:	$host_text:$self->{'port'}
INFO

		$self->cell_info( $info ) ;

		$self->{'sock_obj'} = $sock_obj ;
	}
	elsif ( $self->{'connect_now'} ) {

		$self->connect() ;
	}

	$self->cell_set_args(
			'host'		=> $self->{'host'},
			'port'		=> $self->{'port'},
			'server'	=> $self->{'server'},
	) ;

#print  "Sock\n", Dumper( $self ) ;

	return( $self ) ;
}

sub connected {

	my( $self, $connected_sock ) = @_ ;

	my $type = $self->{'sock_obj'}->type() ;

	my $info = sprintf( <<INFO,
SockMsg connected
Type:	$type
Local:	%s:%d
Remote:	%s:%d
INFO
				$connected_sock->sockhost(),
				$connected_sock->sockport(),
				$connected_sock->peerhost(),
				$connected_sock->peerport(),
	) ;

TraceStatus "\n$info" ;

	if ( my $log_name = $self->{ 'log_name' } ) {

#print "MSG LOG\n" ;

		Stem::Log::Entry->new(
				'logs'	=> $log_name,
				'text'	=> "Connected\n$info",
		) ;
	}

	$self->cell_set_args(
			'fh'		=> $connected_sock,
			'aio_args'	=>
				[ 'fh'	=> $connected_sock ],
			'info'		=> $info,
	) ;

	$self->cell_trigger() ;
}

# this method is called after the cell is triggered. this cell can be
# the original cell or a cloned one.

sub triggered_cell {

	my( $self ) = @_ ;

	return "SockMsg: can't connect a server socket" if $self->{'server'} ;

	print "SockMsg triggered\n" ;

	return $self->connect() ;
}

sub connect {

	my( $self ) = @_ ;

	my $host = $self->cell_get_args( 'host' ) || $self->{'host'} ;
	my $port = $self->cell_get_args( 'port' ) || $self->{'port'} ;

########################
########################
## handle connect timeouts
########################
########################

TraceStatus "Connecting to $host:$port" ;

	my $sock_obj = Stem::Socket->new( 
			'object'	=> $self,
			'host'		=> $host,
			'port'		=> $port,
	) ;

	return $sock_obj unless ref $sock_obj ;

	$self->{'sock_obj'} = $sock_obj ;

	return ;
}


# we handle the socket close method directly here so we can reconnect
# if needed. the other async method callbacks are in Cell.pm

sub async_closed {

	my( $self ) = @_ ;

	my $sock = $self->cell_get_args( 'fh' ) ;

#	$sock->close() ;

#print "Sock MSG: closed name $self->{'reg_name'}\n" ;

#		$self->{'sock_obj'}->connect_to() ;

	if ( my $log_name = $self->{ 'log_name' } ) {

		Stem::Log::Entry->new(
				'logs'	=> $log_name,
				'text'	=> "Closed\n$self->{'info'}",
		)
	}

TraceStatus "Disconnected" ;

	$self->cell_set_args( 'info' => 'SockMsg disconnected' ) ;

######################
######################
# add support for reconnect.
# it has a flag, delay, retry count.
######################
######################

	$self->cell_shut_down() ;
}

1 ;
