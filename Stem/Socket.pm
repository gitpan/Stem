#  File: Stem/Socket.pm

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

#######################################################

package Stem::Socket ;

use strict ;

use Socket ;
use Symbol ;
use Errno qw( EINPROGRESS ) ;

my $attr_spec = [

	{
		'name'		=> 'object',
		'required'	=> 1,
		'type'		=> 'object',
		'help'		=> <<HELP,
The owner of this object that gets all the method callbacks.
HELP
	},
	{
		'name'		=> 'server',
		'type'		=> 'boolean',
		'help'		=> <<HELP,
Mark this cell as a server socket.
HELP
	},
	{
		'name'		=> 'sync',
		'type'		=> 'boolean',
		'default'	=> 0,
		'help'		=> <<HELP,
Mark this as a synchronously connecting socket. Default is asyncronous
connections. In both cases the same method callbacks are used.
HELP
	},
	{
		'name'		=> 'port',
		'required'	=> 1,
		'help'		=> <<HELP,
TCP port number for listening or connecting
HELP
	},
	{
		'name'		=> 'host',
		'help'		=> <<HELP,

Host to connect to or listen on. If the value is explicitly set to '',
then the host will be INADDR_ANY which allows a server to listen on
all host interfaces.
HELP
	},
	{
		'name'		=> 'method',
		'default'	=> 'connected',
		'help'		=> <<HELP,
Method to call when a socket connection or accept happens.
HELP
	},
	{
		'name'		=> 'timeout',
		'default'	=> 10,
		'help'		=> <<HELP,
How long to wait (in seconds) before a connection times out.
HELP
	},
	{
		'name'		=> 'timeout_method',
		'default'	=> 'connect_timeout',
		'help'		=> <<HELP,
Method to call when a socket connection timeout happens.
HELP
	},
	{
		'name'		=> 'max_retries',
		'default'	=> 0,
		'help'		=> <<HELP,
The maximum number of connection retries before an error is returned.
HELP
	},
	{
		'name'		=> 'private',
		'help'		=> <<HELP,
HELP
	},

] ;

sub new {

	my( $class ) = shift ;

	my $self = Stem::Class::parse_args( $attr_spec, @_ ) ;
	return $self unless ref $self ;

	if ( $self->{ 'server' } ) {

		$self->{'type'} = 'server' ;
		my $listen_err = $self->listen_to() ;
		return $listen_err unless ref $listen_err ;
	}
	else {

		$self->{'type'} = 'client' ;

		my $connect_err = $self->connect_to() ;

		return $connect_err unless ref $connect_err ;
	}

	return( $self ) ;
}

sub connect_to {

	my( $self ) = @_ ;

	my $connect_event = Stem::Socket::Connect->new(
				'object'	=> $self,
				'host'		=> $self->{'host'},
				'port'		=> $self->{'port'},
				'timeout'	=> $self->{'timeout'},
				'sync'		=> $self->{'sync'},
	) ;

	return $connect_event unless ref $connect_event ;

	$self->{'connect_event'} = $connect_event ;
}

sub connected {

	my( $self, $connected_sock ) = @_ ;

# the i/o for sockets is always non-blocking in stem.

	$connected_sock->blocking( 0 ) ;

	my $method = $self->{'method'} ;

	delete $self->{'connect_event'} ;

	$self->{'object'}->$method( $connected_sock, $self->{'private'} ) ;
}

sub connect_timeout {

	my( $self ) = @_ ;

# callback if timeout method is set.

	if ( $self->{'max_retries'} && --$self->{'retry_count'} > 0 ) {

		delete $self->{'connect_event'} ;

		my $method = $self->{'timeout_method'} ;
		$self->{'object'}->$method( $self->{'private'} ) ;
		return ;
	}

	$self->connect_to() ;
}

sub listen_to {

	my( $self ) = @_ ;

	my $accept_event = Stem::Socket::Accept->new(
				'object'	=> $self,
				'host'		=> $self->{'host'},
				'port'		=> $self->{'port'},
				'method'	=> 'connected',
	) ;

	return $accept_event unless ref $accept_event ;

	$self->{'accept_event'} = $accept_event ;
}

sub stop_listening {

	my( $self ) = @_ ;

#print "stop: ", map( "<$_>", caller() ), "\n" ;
	$self->{'accept_event'}->stop() ;
}

sub start_listening {

	my( $self ) = @_ ;

	$self->{'accept_event'}->start() ;
}

sub type {
	$_[0]->{'type'} ;
}

sub get_listen_sock {

	my( $host, $port, $listen ) = @_ ;

	unless( $port ) {

		my $err = "get_listen_sock Missing port" ;
		return $err ;
	}

# no host will default to localhost, '' will force INADDR_ANY

	$host = 'localhost' unless defined $host ;

# get the host name or IP and convert it to an inet address

	my $inet_addr = length( $host ) ? inet_aton( $host ) : INADDR_ANY ;

#print "HOST [$host]\n" ;
#print inet_ntoa( $inet_addr ), "\n" ;

	unless( $inet_addr ) {

		my $err = "get_listen_sock Unknown host [$host]" ;
		return $err ;
	}

# check if it is a get the service name or numeric port and convert it
# to a port number

	if ( $port =~ /\D/ and not $port = getservbyname( $port, 'tcp' ) ) {

		my $err = "get_listen_sock: unknown port [$port]" ;
		return $err ;
	}

# prepare the socket address

	my $sock_addr = pack_sockaddr_in( $port, $inet_addr ) ;

# get an anonymous glob symbol

	my $listen_sock = gensym ;

# create this socket

	unless ( socket( $listen_sock, PF_INET, SOCK_STREAM,
			 getprotobyname('tcp') ) ) {

		my $err = "get_listen_sock can't get socket $!" ;
		return $err ;
	}

	unless ( setsockopt( $listen_sock, SOL_SOCKET, SO_REUSEADDR, 1) ) {
		my $err = "get_listen_sock setsockopt REUSEADDR $!" ;
		return $err ;
	}

	unless ( bind( $listen_sock, $sock_addr ) ) {
		my $errno = $! + 0 ;
		my $err = <<ERR ;
get_listen_sock can't bind to port $port on host $host: $errno $!
ERR
		return $err ;
	}

	$listen ||= 5 ;


	unless ( listen( $listen_sock, $listen ) ) {

		my $err = <<ERR ;
get_listen_sock can't listen on port $port on host $host $!
ERR
		return $err ;
	}

	return( bless $listen_sock, 'IO::Socket::INET' ) ;
}


sub get_connected_sock {

	my( $host, $port, $sync ) = @_ ;

	unless( $port ) {

		my $err = "get_connected_sock Missing port" ;
		return $err ;
	}

	$host ||= 'localhost' ;

# get the host name or IP and convert it to an inet address

	my $inet_addr = inet_aton( $host ) ;

	unless( $inet_addr ) {

		my $err = "get_connected_sock Unknown host [$host]" ;
		return $err ;
	}

# check if it is a get the service name or numeric port and convert it
# to a port number

	if ( $port =~ /\D/ and not $port = getservbyname( $port, 'tcp' ) ) {

		my $err = "get_connected_sock: unknown port [$port]" ;
		return $err ;
	}

# prepare the socket address

	my $sock_addr = pack_sockaddr_in( $port, $inet_addr ) ;
	my $protocol = getprotobyname('tcp');

# get an anonymous glob symbol

	my $connect_sock = gensym ;

# create this socket

	socket( $connect_sock, PF_INET, SOCK_STREAM, $protocol ) ;

# and make it blessed so we can do stuff with it.

	bless $connect_sock, 'IO::Socket::INET' ;

#print "connect $connect_sock", $connect_sock->fileno(), "\n" ;

# set the sync (connect blocking) mode

	$connect_sock->blocking( $sync ) ;

	unless ( $connect_sock->connect( $sock_addr ) ) {

# handle linux false error of EINPROGRESS

		unless ( $! == EINPROGRESS ) {

			return "get_connected_sock: connect error $!\n" ;
		}
	}

	return $connect_sock ;
}

############################################################################

package Stem::Socket::Accept ;

=head2 Stem::Socket::Accept::new

This constructor creates a listen socket (using the optional address
arguments) and when a connection is ready to be accepted it triggers its
object. The callback method is passed the accepted socket as its first
argument.

=over 4

	'object'	=> <required object to trigger>

	'method' =>
		<method to call (default is 'accepted').
		the accepted socket is passed as the first argument>

	'port' => <port to listen on (default is 10000)>

	'host' => <host/ip to listen on (default is IN_ANY)>

	'listen'	=> <max number of pending accepts (default 5)>

=back

=cut

use Socket ;
use Symbol ;

my $attr_spec_accept = [

	{
		'name'		=> 'object',
		'required'	=> 1,
		'type'		=> 'object',
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
		'name'		=> 'method',
		'default'	=> 'accepted',
		'help'		=> <<HELP,
HELP
	},

	{
		'name'		=> 'listen',
		'default'	=> '5',
		'help'		=> <<HELP,
HELP
	},

] ;

sub new {

	my( $class ) = shift ;

	my $self = Stem::Class::parse_args( $attr_spec_accept, @_ ) ;
	return $self unless ref $self ;

	
	my $listen_sock = Stem::Socket::get_listen_sock(
						$self->{'host'},
						$self->{'port'},
						$self->{'listen'},
	) ;

	return $listen_sock unless ref $listen_sock ;

	$self->{'listen_sock'} = $listen_sock ;

# create and save the read event watcher

	my $read_event = Stem::Event::Read->new(
				'object'	=> $self,
				'fh'		=> $listen_sock,
			) ;
					
	$self->{'read_event'} = $read_event ;

	return $self ;
}

# callback when a socket can be accepted (the listen socket is readable)

sub readable {

	my( $self ) = @_ ;

# get the accepted socket

	my $accepted_sock = $self->{'listen_sock'}->accept() ;

	$accepted_sock->blocking( 0 ) ;

# callback the object/method with the accepted socket as the argument

	Stem::Event::trigger( 'accepted',
			      $self->{'object'},
			      $self->{'method'},
			      $accepted_sock ) ;
}

# wrapper for event cancel

sub cancel {

	my( $self ) = @_ ;

	$self->{'read_event'}->cancel() ;

	delete $self->{'read_event'} ;
}

sub stop {

	my( $self ) = @_ ;

	$self->{'read_event'}->stop() ;
}

sub start {

	my( $self ) = @_ ;

	$self->{'read_event'}->start() ;
}


############################################################################

package Stem::Socket::Accept::Test ;

sub go {

	my( $self, $accept_event, $connect_event ) ;

	print __PACKAGE__, " testing\n" ;

	$self = bless {} ;

	$accept_event = Stem::Socket::Accept->new(
					'object' => $self,
					'port' => 10_000 ) ;

	die $accept_event unless ref $accept_event ;

	$self->{'accept_event'} = $accept_event ;

	$connect_event = Stem::Socket::Connect->new(
						'object' => $self,
						'port' => 10_000,
						'host' => 'localhost' ) ;

	die $connect_event unless ref $connect_event ;

	$self->{'connect_event'} = $connect_event ;

	Stem::Event::start_loop() ;

	print "end test\n" ;
}

sub accepted {

	my( $self, $accepted_sock ) = @_ ;

	print "accepted\n" ;

	close( $accepted_sock ) ;

	$self->{'accept_event'}->cancel() ;

	print "accept canceled\n" ;
}

sub connected {

	my( $self, $connected_sock ) = @_ ;

	print "connected\n" ;
}

############################################################################

package Stem::Socket::Connect ;

use Socket ;
use Symbol ;

my $attr_spec_connect = [

	{
		'name'		=> 'object',
		'required'	=> 1,
		'type'		=> 'object',
		'help'		=> <<HELP,
The owner of this object that gets all the method callbacks.
HELP
	},
	{
		'name'		=> 'sync',
		'type'		=> 'boolean',
		'default'	=> 0,
		'help'		=> <<HELP,
Mark this as a synchronously connecting socket. Default is asyncronous
connections. In both cases the same method callbacks are used.
HELP
	},
	{
		'name'		=> 'port',
		'required'	=> 1,
		'help'		=> <<HELP,
TCP port number to connect to
HELP
	},
	{
		'name'		=> 'host',
		'help'		=> <<HELP,
Host to connect to.
HELP
	},
	{
		'name'		=> 'method',
		'default'	=> 'connected',
		'help'		=> <<HELP,
Method to call when a socket connection happens.
HELP
	},
	{
		'name'		=> 'timeout',
		'default'	=> 10,
		'help'		=> <<HELP,
How long to wait (in seconds) before a connection times out.
HELP
	},
	{
		'name'		=> 'timeout_method',
		'default'	=> 'connect_timeout',
		'help'		=> <<HELP,
Method to call when a socket connection timeout happens.
HELP
	},
] ;

sub new {

	my( $class ) = shift ;

	my $self = Stem::Class::parse_args( $attr_spec_connect, @_ ) ;
	return $self unless ref $self ;


	my $connect_sock = Stem::Socket::get_connected_sock(
						$self->{'host'},
						$self->{'port'},
						$self->{'sync'},
	) ;

	return $connect_sock unless ref $connect_sock ;

	$self->{'connected_sock'} = $connect_sock ;


	if( $self->{'sync'} ) {

#print "connected\n" ;
		$self->writeable() ;
		return $self ;
	}

# create and save the write event watcher

	my $write_event = Stem::Event::Write->new(
			'object'	=>	$self,
			'fh'		=>	$connect_sock,
			'timeout'	=>	$self->{'timeout'},
	) ;

	$self->{'write_event'} = $write_event ;

	$write_event->start() ;

	return $self ;
}

# callback when a socket is connected (the socket is writeable)

sub writeable {

	my( $self ) = @_ ;

# get the connected socket

	my $connected_sock = $self->{'connected_sock'} ;

# callback the object/method with the connected socket as the argument
	
	Stem::Event::trigger( 'connected',
			      $self->{'object'},
			      $self->{'method'},
			      $connected_sock ) ;

# delete the single shot write event

	$self->cancel() ;
}

sub write_timeout {

	my( $self ) = @_ ;

	my $connected_sock = $self->{'connected_sock'} ;
	
	$connected_sock->close() ;

	Stem::Event::trigger( 'connect_timeout',
			      $self->{'object'},
			      $self->{'method'} ) ;

	$self->cancel() ;
}

sub cancel {

	my( $self ) = @_ ;

	my $evt = delete $self->{'write_event'} ;
	return unless $evt ;
	$evt->cancel() ;
}

1 ;
