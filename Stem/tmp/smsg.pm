#  File: Stem/tmp/smsg.pm

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

use strict ;
use Socket ;

use Data::Dumper ;

use Stem::Socket ;
use Stem::AsyncIO ;
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
		'name'		=> 'server',
		'type'		=> 'boolean',
		'help'		=> <<HELP,
HELP
	},

	{
		'name'		=> 'send_data_on_close',
		'type'		=> 'boolean',
		'help'		=> <<HELP,
HELP
	},

	{
		'name'		=> 'log_connections',
		'type'		=> 'boolean',
		'help'		=> <<HELP,
HELP
	},

	{
		'name'		=> 'piped_to',
		'type'		=> 'boolean',
		'help'		=> <<HELP,
HELP
	},

	{
		'name'		=> 'connected_msg',
		'class'		=> 'Stem::Msg',
		'class_args'	=> [
			'type'		=> 'status',
			'data'		=> \'connected',
		],
		'type'		=> 'message',
		'help'		=> <<HELP,
HELP
	},

	{
		'name'		=> 'data_msg',
		'class'		=> 'Stem::Msg',
		'class_args'	=> [
			'type'		=> 'data',
		],
		'type'		=> 'message',
		'help'		=> <<HELP,
HELP
	},

	{
		'name'		=> 'closed_msg',
		'class'		=> 'Stem::Msg',
		'class_args'	=> [
			'type'		=> 'status',
			'data'		=> \'closed',
		],
		'type'		=> 'message',
		'help'		=> <<HELP,
HELP
	},

] ;


sub new {

	my( $class ) = shift ;

	my $self = Stem::Class::parse_args( $attr_spec, @_ ) ;
	return $self unless ref $self ;
	
	$self->{'buffer'} = '' if $self->{'send_data_on_close'} ;

	my $sock_obj = Stem::Socket->new( 
				'object'	=> $self,
				'host'		=> $self->{'host'},
				'port'		=> $self->{'port'},
				'server'	=> $self->{'server'},
	) ;

	return $sock_obj unless ref $sock_obj ;

	$self->{'sock_obj'} = $sock_obj ;

	$self->{'id_obj'} = Stem::Id->new() ;

	$self->{'is_parent'} = 1 ;

	return( $self ) ;
}


######################
######################
# create a pipe_start_cmd method. 
# 
# attributes needed: piped_from - doesn't connect in new, only on command
# command has optional host/port which is used for sock_obj.
#
######################
######################





sub connected {

	my( $self, $connected_sock, $private ) = @_ ;

#####################
#####################
# check max clone count
#####################
#####################

	my $clone = $self->_clone() ;

	$clone->{'connected'} = 1 ;
	$clone->{'sock'} = $connected_sock ;

	$clone->{'aio'} = Stem::AsyncIO->new(

			'object'	=> $clone,
			'fh'		=> $connected_sock,
			'read_method'	=> 'socket_read',
			'closed_method'	=> 'socket_closed',
	) ;

	if ( my $msg = $clone->{'connected_msg'} ) {

		$msg->dispatch() ;
	}

	my $type = $self->{'sock_obj'}->type() ;
	$clone->{'type'} = $type ;

	$clone->{'info'} = sprintf( <<INFO,

Sock::Msg
Type:	$type
Cell:	$self->{'reg_name'}:$clone->{'target'}
Local:	%s:%d
Remote:	%s:%d

INFO
				$connected_sock->sockhost(),
				$connected_sock->sockport(),
				$connected_sock->peerhost(),
				$connected_sock->peerport(),
	) ;

#print $clone->{'info'} ;


use Stem::Debug qw( debug ) ;

debug 'DBG ', $clone->{'info'} ;

	if ( $clone->{ 'log_connections' } ) {

print "MSG LOG\n" ;

		Stem::Log::entry(
				'log'	=> 'foo',
				'text'	=> $clone->{'info'},
		)->submit() ;
	}
}

sub _clone {

	my( $self ) = @_ ;

# copy the object

	my $clone = bless { %{$self} } ;

# get a new target id, register the clone and track it in the parent.

	my $target = $self->{'id_obj'}->next() ;
	$clone->{'target'} = $target ;
	register_cell( $clone, $clone->{'reg_name'}, $target ) ;
	$self->{'clones'}{$target} = $clone ;


	$clone->{'parent'} = $self ;
	$clone->{'is_parent'} = 0 ;

	if ( $clone->{'piped_to'} ) {

		$clone->_pipe_start() ;
	}

	return $clone ;
}

sub _pipe_start {

	my( $self ) = @_ ;

	my $from_cell	= $self->{'reg_name'} ;
	my $from_target	= $self->{'target'} ;
	my $to_cell	= $self->{'piped_to'} ;

# don't send out any other connected message 

	delete $self->{'connected_msg'} ;

	$self->{'data_msg'} = Stem::Msg->new(
			'from_cell'	=> $from_cell,
			'from_target'	=> $from_target,
			'to_cell'	=> $to_cell,
			'type'		=> 'data',
	) ;

	$self->{'closed_msg'} = Stem::Msg->new(
			'from_cell'	=> $from_cell,
			'from_target'	=> $from_target,
			'to_cell'	=> $to_cell,
			'type'		=> 'cmd',
			'cmd'		=> 'pipe_stop',
	) ;

# start the pipe connection handshake

	my $msg = Stem::Msg->new(
			'from_cell'	=> $from_cell,
			'from_target'	=> $from_target,
			'to_cell'	=> $to_cell,
			'type'		=> 'cmd',
			'cmd'		=> 'pipe_start',
	) ;

	$msg->dispatch() ;

#print "\nPIPE $self\n", Dumper $self ;

}


# this command is sent in response to a pipe_start command. it updates
# all the messages to have the correct target to send messages to.

sub target_cmd {

	my( $self, $msg ) = @_ ;

#print "\nT $self\n", Dumper $self ;

	my $to_target = $msg->from_target() ;

	$self->{'to_target'} = $to_target ;

	for my $msg_name ( qw( data_msg closed_msg ) ) {

		next unless $self->{$msg_name} ;

		$self->{$msg_name}->to_target( $to_target ) ;
	}

#print "\nT2 $self\n", Dumper $self ;

	return ;
}

sub socket_read {

	my( $self, $data_ref ) = @_ ;

print "SOCK [${$data_ref}]\n" ;

	if ( $self->{'send_data_on_close'} ) {

		$self->{'buffer'} .= ${$data_ref} ;
		return ;
	}


#print "\nD $self\n", Dumper $self ;

print $self->{'data_msg'}->dump( 'DATA' ) ;


	my $msg = $self->{'data_msg'}->clone( 'data' => $data_ref ) ;


print $msg->dump( 'sock2msg' ) ;

	$msg->dispatch() ;
}


sub socket_closed {

	my( $self ) = @_ ;

	$self->{'connected'} = 0 ;

print "closed name $self->{'reg_name'}\n" ;

######################
######################
######################
# add support for reconnect.
# if it has a flag, delay, retry count.
#
# also add connect command method.
######################
######################
######################
#		$self->{'sock_obj'}->connect_to() ;

	if ( $self->{'send_data_on_close'} ) {

		my $msg = $self->{'data_msg'}->clone( 

			'data'		=> \$self->{'buffer'},
		) ;

		$msg->dispatch() ;
	}

	if ( my $msg = $self->{'closed_msg'} ) {

		$msg->dispatch() ;
	}

	$self->{'parent'}->_clone_done( $self ) ;
}

# have the parent cleanup after one of it's clones is done.

sub _clone_done {

	my( $self, $clone ) = @_ ;

	return unless $self->{ 'is_parent' } ;

	$clone->{'aio'}->shut_down() ;
	delete $clone->{'aio'} ;

	my $target = $clone->{'target'} ;

	return unless $target  ;

	delete( $self->{'parent'} ) ;

	my $clone = $self->{'clones'}{$target} ;

print "sock unreg $clone\n" ;

	my $err = unregister_cell( $clone ) ;

print "unreg err $err\n" if $err ;

	delete ( $self->{'clones'}{$target} ) ;
	$self->{'id_obj'}->delete( $target ) ;
}

sub data_in {

	my( $self, $msg ) = @_ ;

	unless( $self->{'connected'} ) {

		print "socket not connected. msg ignored\n" ;
		return ;
	}

	$self->{'aio'}->write( $msg->data() ) ;
}

sub stderr_in {

	my( $self, $msg ) = @_ ;

	unless( $self->{'connected'} ) {

		print "socket not connected. msg ignored\n" ;
		return ;
	}

	$self->{'aio'}->write( $msg->data() ) ;
}

sub pipe_closed_cmd {

	my( $self, $msg ) = @_ ;

print "Sock::Msg pipe closed\n" ;

	$self->{'parent'}->_clone_done( $self ) ;
}

1 ;
