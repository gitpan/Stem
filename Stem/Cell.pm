#  File: Stem/Cell.pm

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

package Stem::Cell ;

use strict ;

use Data::Dumper ;
use Carp qw( cluck ) ;

use Stem::Route qw( :cell ) ;
use Stem::AsyncIO ;
use Stem::Id ;
use Stem::Gather ;
use Stem::Cell::Clone ;
use Stem::Cell::Pipe ;
use Stem::Cell::Sequence ;
use Stem::Cell::Work ;

use Stem::Trace 'log' => 'stem_status' , 'sub' => 'TraceStatus' ;

my %class_to_attr_name ;

my $attr_spec = [

	{
		'name'		=> 'cloneable',
		'type'		=> 'boolean',
		'help'		=> <<HELP,
The parent Cell will be cloned upon triggering
HELP
	},
	{
		'name'		=> 'data_addr',
		'type'		=> 'address',
		'help'		=> <<HELP,
Cell address to send any data read in. If not set here it must come
from a message.
HELP
	},
	{
		'name'		=> 'status_addr',
		'type'		=> 'address',
		'help'		=> <<HELP,
Cell address to send Cell status to
HELP
	},
	{
		'name'		=> 'send_data_on_close',
		'type'		=> 'boolean',
		'help'		=> <<HELP,
Buffer all read data and only send it when the I/O is closed
HELP
	},
	{
		'name'		=> 'no_io',
		'type'		=> 'boolean',
		'help'		=> <<HELP,
Don't do any I/O for the Cell. Either there is none or the owner Cell must
do its own I/O
HELP
	},
	{
		'name'		=> 'pipe_addr',
		'type'		=> 'address',
		'help'		=> <<HELP,
Cell address to open a pipe to
HELP
	},
	{
		'name'		=> 'pipe_args',
		'help'		=> <<HELP,
HELP
	},
	{
		'name'		=> 'id_size',
		'default'	=> 3,
		'help'		=> <<HELP,
Size of unique ID space for clones. Range is 26**N
HELP
	},
	{
		'name'		=> 'trigger_method',
		'default'	=> 'triggered_cell',
		'help'		=> <<HELP,
Method to callback in owner object when cell is triggered
HELP
	},

# the below attributes are not permanent yet
# unused so far.
	{
		'name'		=> 'shut_down_method',
		'default'	=> 'shut_down_cell',
		'help'		=> <<HELP,
Method to callback in owner object when cell is shutdown
HELP
	},


	{
		'name'		=> 'activated_method',
		'default'	=> 'activate_cell',
		'help'		=> <<HELP,
Method to call in owner Cell when the cell is activated. UNSUPPORTED
HELP
	},
	{
		'name'		=> 'sequence_done_method',
		'help'		=> <<HELP,
Method to call in owner Cell when the executing sequence completes.
HELP
	},

	{
		'name'		=> 'worker_mode',
		'type'		=> 'boolean',
		'help'		=> <<HELP,
Mark that this Cell is in worker mode. It receives and sends back
work messages which carry work objects.
HELP
	},
	{
		'name'		=> 'work_generator',
		'type'		=> 'boolean',
		'help'		=> <<HELP,
Mark that this Cell generates work messages. 
HELP
	},
	{
		'name'		=> 'work_ready_addr',
		'type'		=> 'address',
		'help'		=> <<HELP,
This is the address of the Cell that this Cell sends a message to
when work can be done (i.e. a work message can now be sent here).
HELP
	},
	{
		'name'		=> 'work_codec',
		'help'		=> <<HELP,
This is the sub-class that is used to convert work data to/from a byte stream.
HELP
	},
	{
		'name'		=> 'stderr_log',
		'help'		=> <<HELP,
This sets the log that will get the stderr output of the process
HELP
	},
] ;


sub new {

	my( $class ) = shift ;

	my $self = Stem::Class::parse_args( $attr_spec, @_ ) ;
	return $self unless ref $self ;

	return( $self ) ;
}

# this is only called in Stem::Conf for this class.
# it initialized the cell info object inside its owner object.

sub cell_init {

	my( $self, $owner_obj, $cell_name, $cell_info_attr ) = @_ ;

# the $owner_obj is the cell that owns this Stem::Cell object

	$self->{'owner_obj'} = $owner_obj ;
	$self->{'cell_name'} = $cell_name ;
	$self->{'from_addr'} = "$Stem::Vars::Hub_name:" if
						$Stem::Vars::Hub_name ;
	$self->{'from_addr'} .= $cell_name ;

	$self->{'cell_info_attr'} = $cell_info_attr ;

# save the attribute name that the owner class uses for the cell info.
# this is how a cell info object can be found given an owner cell object.
# also keep this name in the info itself

	$class_to_attr_name{ ref $owner_obj } ||= $cell_info_attr ;

	if ( $self->{'cloneable'} ) {

		$self->{'id_obj'} = Stem::Id->new(
					'size'	=> $self->{'id_size'} ) ;
		$self->{'is_parent'} = 1 ;
		$self->{'target'} = '' ;
	}
}

sub _get_cell_info {

#cluck "\n\nget cell info" ;

	my ( $self ) = @_ ;

	my $class = ref $self ;

	return "can't get cell info from '$self'\n" unless $class ;

	return $self if $class eq __PACKAGE__ ;

	return $self->{ $class_to_attr_name{ $class } } ;
}

sub cell_trigger {

	my ( $self, @args ) = @_ ;

	my $self_info = $self->_get_cell_info() ;

	return $self_info unless ref $self_info ;

	return if $self_info->{'triggered'} ;

# clone this cell and its info if needed
# $cell will either be $self or a clone of $self

	my $cell = $self_info->_clone() ;

	my $cell_info = $cell->_get_cell_info() ;

	$cell_info->{'triggered'} = 1 ;

	$cell_info->cell_set_args( @args ) ;

	my $err = $cell_info->_work_mode_init() ;
	return $err if $err ;

	$cell_info->_cell_pipe() ;

	unless( $cell_info->{'no_io'} ) {

		my @gather_keys = 'aio_args' ;

		push( @gather_keys, 'data_addr' ) if
				$cell_info->{'piped'} &&
				! $cell_info->{'data_addr'} ;

		my $gather = Stem::Gather->new(
				'object'	=> $cell_info,
				'keys'		=> \@gather_keys,
				'gathered_method' => '_cell_activated',
		) ;

		return $gather unless ref $gather ;

		$cell_info->{'gather'} = $gather ;

		my $err = $gather->gathered( keys %{$cell_info->{'args'}} ) ;

		return $err if $err ;
	}

# do the callback into the (possibly cloned) cell

	$cell_info->_callback( 'trigger_method' ) ;

	return $cell_info ;
}

sub cell_trigger_cmd {

	my ( $self, $msg ) = @_ ;

	my @args ;

	if ( my $data = $msg->data() ) {

		if ( my $ref = ref $data ) {

			if ( $ref eq 'HASH' ) {

				@args = %{$data} ;
			}
			elsif ( $ref eq 'ARRAY' ) {

				@args = @{$data} ;
			}
			elsif ( ref $data eq 'SCALAR' && defined ${$data} ) {

				@args = ${$data} =~ /(\S+)=(\S+)/g ;
#print $self->_dump() ;
#print "D [$$data]\n" ;
			}
		}
		else {
			@args = $data =~ /(\S+)=(\S+)/g ;
		}
	}

	push( @args, triggering_msg => $msg ) ;

	my $cell_info = $self->cell_trigger( @args ) ;

	return $cell_info unless ref $cell_info ;

	return ;
}

sub cell_shut_down {

	my( $self ) = @_ ;

#print "CELL SHUT\n" ;

	my $cell_info = $self->_get_cell_info() ;

	return unless $cell_info->{'active'} ;

	if ( my $aio = delete $cell_info->{'aio'} ) {

		$aio->shut_down() ;
	}

	if ( my $gather = delete $cell_info->{'gather'} ) {

		$gather->shut_down() ;
	}

	$cell_info->_close_pipe() ;

	$cell_info->_clone_delete() ;

	delete $cell_info->{'args'} ;
# 	delete $cell_info->{'data_addr'} ;

	$cell_info->{'active'} = 0 ;
	$cell_info->{'triggered'} = 0 ;

	TraceStatus "cell shut down done" ;

	return ;
}


sub cell_set_args {

	my( $self, %args ) = @_ ;

	my $cell_info = $self->_get_cell_info() ;

	@{$cell_info->{'args'}}{ keys %args } = values %args ;

	if ( my $gather = $cell_info->{'gather'} ) {

		my $err = $gather->gathered( keys %args ) ;
		return $err if $err ;
	}

	return ;
}

sub cell_get_args {

	my( $self, @arg_keys ) = @_ ;

	my $cell_info = $self->_get_cell_info() ;

	return( @{$cell_info->{'args'}}{@arg_keys } ) ;
}

sub cell_info {

	my( $self ) = shift ;

	my $cell_info = $self->_get_cell_info() ;

	$cell_info->{'info'} = shift if @_ ;

	return $cell_info->{'info'} ;
}

sub _cell_activated {

	my ( $self ) = @_ ;

	TraceStatus "cell activated" ;

	$self->{'active'} = 1 ;

	return if $self->{'no_io'} ;

	my $aio_args = $self->{'args'}{'aio_args'} ;

	ref $aio_args eq 'ARRAY' or return <<ERR ;
aio_args is not an ARRAY ref
ERR
	my $data_addr = $self->{'args'}{'data_addr'} || $self->{'data_addr'} ;

# we ignore the data address in worker mode so Cell::Work can handle the
# async i/o callbacks.

	$data_addr = undef if $self->{'worker_mode'} ;

	my $aio = Stem::AsyncIO->new(

		'object'		=> $self->{'owner_obj'},
		'data_addr'		=> $data_addr,
		'from_addr'		=> $self->{'from_addr'},
		'send_data_on_close'	=> $self->{'send_data_on_close'},
		@{$aio_args},
	) ;

	return $aio unless ref $aio ;

	$self->{'aio'} = $aio ;

	return ;
}

sub cell_activate {

	my( $self ) = @_ ;

	my $cell_info = $self->_get_cell_info() ;

	$cell_info->{'active'} = 1 ;
}


*cell_status_cmd = \&status_cmd ;

sub status_cmd {

	my( $self ) = @_ ;

	my $cell_info = $self->_get_cell_info() ;

	my $info = $cell_info->{'info'} || $cell_info->{'args'}{'info'} || '' ;

	$info =~ s/^/\t\t/mg ;
 
	my $class = ref $cell_info->{'owner_obj'} ;

	my $data_addr = Stem::Msg::address_string( 
				$cell_info->{'data_addr'} ||
				$cell_info->{'args'}{'data_addr'} ||
				'[NONE]' ) ;

	my $active = ( $cell_info->{'active'} ) ? 'Active' : 'Inactive' ;

	return <<STATUS ;
Cell Status for:
Class:		$class
Addr:		$cell_info->{'from_addr'}
Status:		$active
Data Addr:	$data_addr
Info:$info
STATUS

}

sub data_in {

	my( $self, $msg ) = @_ ;

	my $cell_info = $self->_get_cell_info() ;

	if ( $cell_info->{'is_parent'} ) {

		TraceStatus "parent cell $cell_info->{'from_addr'} ignoring msg" ;

		return ;
	}

	unless( $cell_info->{'active'} ) {

		TraceStatus "cell not active. msg ignored FOO" ;

		return ;
	}

	$cell_info->cell_write( $msg->data() ) ;
}

sub cell_write {

	my( $self, $data ) = @_ ;

	my $cell_info = $self->_get_cell_info() ;

	$cell_info->{'aio'}->write( $data ) ;
}


# handle stderr data as plain data

*stderr_data_in = \&data_in ;


# $cell_info is the Stem::Cell object of the parent cell. the name is
# not self as it is differentiated from $clone_info.



sub _callback {

	my ( $self, $method_name, @data ) = @_ ;

	my $method = $self->{$method_name} ;

	my $owner_obj = $self->{'owner_obj'} ;

	if ( $owner_obj->can( $method ) ) {

		return $owner_obj->$method( @data ) ;
	}

	TraceStatus "can't call $method in $owner_obj" ;

	return ;
}

sub cell_from_addr {

	my ( $self ) = @_ ;

	my $cell_info = $self->_get_cell_info() ;

	return( $cell_info->{'from_addr'} ) ;
}

sub _dump {

	my ( $self, $text ) = @_ ;

	$text ||= 'CELL' ;

	my $dump = "$text =\n" ;

	my $cell_info = $self->_get_cell_info() ;

	foreach my $key ( sort keys %{$cell_info} ) {

		my $val = $cell_info->{$key} || '';

		if ( $key eq 'args' ) {

			$dump .= "\targs = {\n" ;

			foreach my $arg ( sort keys %{$val} ) {

				my $arg_val = $val->{$arg} || '';

				$dump .= "\t\t$arg = '$arg_val'\n" ;
			}

			$dump .= "\t}\n" ;

			next ;
		}

		$dump .= "\t$key = '$val'\n" ;
	}

	$dump .= "\n\n" ;

	return $dump ;
}

sub dump_cmd {

	my ($self) = @_ ;

	my $cell_info = $self->_get_cell_info() ;

	return $cell_info->_dump() . Dumper $cell_info ;
}

1 ;
