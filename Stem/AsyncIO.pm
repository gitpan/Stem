#  File: Stem/AsyncIO.pm

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

package Stem::AsyncIO ;

use strict ;
use Data::Dumper ;

use Stem::Vars ;


my $attr_spec = [

	{
		'name'		=> 'object',
		'required'	=> 1,
		'help'		=> <<HELP,
HELP
	},

	{
		'name'		=> 'read_method',
		'default'	=> 'async_read_data',
		'help'		=> <<HELP,
Method called with the data read from the read handle. It is only called if the	
data_addr attribute is not set.
HELP
	},

	{
		'name'		=> 'stderr_method',
		'default'	=> 'async_stderr_data',
		'help'		=> <<HELP,
Method called with the data read from the stderr handle. It is only
called if the stderr_addr attribute is not set.
HELP
	},

	{
		'name'		=> 'closed_method',
		'default'	=> 'async_closed',
		'help'		=> <<HELP,
Method used when this object is closed.
HELP
	},

	{
		'name'		=> 'fh',
		'help'		=> <<HELP,
File handle used for reading and writing.
HELP
	},

	{
		'name'		=> 'read_fh',
		'help'		=> <<HELP,
File Handle used for reading.
HELP
	},

	{
		'name'		=> 'write_fh',
		'help'		=> <<HELP,
File handle used for standard output.
HELP
	},

	{
		'name'		=> 'stderr_fh',
		'help'		=> <<HELP,
File handle used for Standard Error.
HELP
	},

	{
		'name'		=> 'data_addr',
		'type'		=> 'address',
		'help'		=> <<HELP,
The address of the Cell where the data is sent.
HELP
	},

	{
		'name'		=> 'stderr_addr',
		'type'		=> 'address',
		'help'		=> <<HELP,
The address of the Cell where the stderr is sent.
HELP
	},

	{
		'name'		=> 'data_msg_type',
		'default'	=> 'data',
		'help'		=> <<HELP,
The type of message that the data is sent in.
HELP
	},

	{
		'name'		=> 'stderr_msg_type',
		'default'	=> 'stderr_data',
		'help'		=> <<HELP,
The type of message that the stderr data is sent in.
HELP
	},

	{
		'name'		=> 'from_addr',
		'type'		=> 'address',
		'help'		=> <<HELP,
The address used in the 'from' field of data and stderr messages.
HELP
	},

	{
		'name'		=> 'send_data_on_close',
		'type'		=> 'boolean',
		'help'		=> <<HELP,
Buffer all read data and send it when the read handle is closed.
HELP
	},
	{
		'name'		=>	'private',
	},

################
## add support to log all AIO
################


	{
		'name'		=> 'log_label',
		'default'	=> 'AIO',
		'help'		=> <<HELP,
HELP
	},
	{
		'name'		=> 'log_level',
		'default'	=> 5,
		'help'		=> <<HELP,
HELP
	},
	{
		'name'		=> 'read_log',
		'help'		=> <<HELP,
HELP
	},

	{
		'name'		=> 'stderr_log',
		'help'		=> <<HELP,
HELP
	},

	{
		'name'		=> 'write_log',
		'help'		=> <<HELP,
HELP
	},


] ;


sub new {

	my( $class ) = shift ;

	my $self = Stem::Class::parse_args( $attr_spec, @_ ) ;
	return $self unless ref $self ;

	if ( $self->{'data_addr'} && ! $self->{'from_addr'} ) {

		return "Using 'data_addr in AsyncIO requires a 'from_addr'" ;
	}

	$self->{'stderr_addr'} ||= $self->{'data_addr'} ;

	$self->{'buffer'} = '' if $self->{'send_data_on_close'} ;

	$self->{ 'read_fh' } ||= $self->{ 'fh' } ;
	$self->{ 'write_fh' } ||= $self->{ 'fh' } ;

	if ( my $read_fh = $self->{'read_fh'} ) {

		my $read_event = Stem::Event::Read->new(
					'object'	=> $self,
					'fh'		=> $read_fh,
		) ;

		return $read_event unless ref $read_event ;

		$self->{'read_event'} = $read_event ;
	}

	if ( my $stderr_fh = $self->{'stderr_fh'} ) {

		my $stderr_event = Stem::Event::Read->new(
					'object'	=> $self,
					'fh'		=> $stderr_fh,
					'method'	=> 'stderr_readable',
		) ;

		return $stderr_event unless ref $stderr_event ;

		$self->{'stderr_event'} = $stderr_event ;
	}

	if ( my $write_fh = $self->{'write_fh'} ) {

		my $write_event = Stem::Event::Write->new(
					'object'	=> $self,
					'fh'		=> $write_fh,
		) ;

		return $write_event unless ref $write_event ;

		$self->{'write_event'} = $write_event ;

		$self->{'write_buf'} = '' ;
	}

	return $self ;
}

sub shut_down {

	my( $self ) = @_ ;

	if ( $self->{'shut_down'} ) {

		return ;
	}

	if ( $self->{'write_buf'} && length( $self->{'write_buf'} ) ) {

		$self->{'shut_down_after_flush'} = 1 ;

		return ;
	}

	if ( my $event = delete $self->{'read_event'} ) {

		$event->cancel() ;
		close( $self->{'read_fh'} ) ;
	}

	if ( my $event = delete $self->{'write_event'} ) {

		$event->cancel() ;
		close( $self->{'write_fh'} ) ;
	}

	if ( my $event = delete $self->{'stderr_event'} ) {

		$event->cancel() ;
		close( $self->{'stderr_fh'} ) ;
	}

	delete $self->{'object'} ;

	$self->{'shut_down'} = 1 ;
}


sub readable {

	my( $self ) = @_ ;

	my( $read_buf ) ;

	if  ( $self->{'shut_down'} ) {

		return ;
	}

	my $obj = $self->{'object'} ;
	my $data_addr = $self->{'data_addr'} ;

	my $bytes_read = sysread( $self->{'read_fh'}, $read_buf, 8192 ) ;

	unless( defined( $bytes_read ) && $bytes_read > 0 ) {

		if ( $self->{'send_data_on_close'} &&
		     length( $self->{'buffer'} ) &&
		     $data_addr ) {

			$self->send_data( $data_addr,
					  $self->{'data_msg_type'},
					  \$self->{'buffer'}
			) ;
		}

 		my $method = $self->{'closed_method'} ;

 		$obj->$method( $self->{'private'} ) ;

		return ;
	}

#print "READ: [$read_buf]\n" ;

	if ( $self->{'send_data_on_close'} ) {

		$self->{'buffer'} .= $read_buf ;
		return ;
	}

	if ( $data_addr ) {

		$self->send_data( $data_addr,
				  $self->{'data_msg_type'},
				  \$read_buf
		) ;
		return ;
	}

	my $method = $self->{'read_method'} ;

	$obj->$method( \$read_buf, $self->{'private'} ) ;
}

sub stderr_readable {

	my( $self ) = @_ ;

	my( $read_buf ) ;

	my $obj = $self->{'object'} ;

	my $bytes_read = sysread( $self->{'stderr_fh'}, $read_buf, 8192 ) ;

	if ( $bytes_read == 0 ) {

		my $method = $self->{'closed_method'} ;

#		$obj->$method( $self->{'private'} ) ;

		return ;
	}

	if ( my $addr = $self->{'stderr_addr'} ) {

		$self->send_data( $addr,
				  $self->{'stderr_msg_type'},
				  \$read_buf
		) ;
		return ;
	}

	my $method = $self->{'stderr_method'} ;

	$obj->$method( \$read_buf, $self->{'private'} ) ;
}


sub send_data {

	my( $self, $to_addr, $msg_type, $data_ref ) = @_ ;

	my $msg = Stem::Msg->new(
			'to'		=> $to_addr,
			'from'		=> $self->{'from_addr'},
			'type'		=> $msg_type,
			'data'		=> $data_ref,
	) ;

#print $msg->dump( 'AIO send' ) ;
	$msg->dispatch() ;
}

sub write {

	my( $self ) = @_ ;

	if ( $self->{'shut_down'} ) {

		return  ;
	}

	return unless exists( $self->{'write_buf'} ) ;

# use the alias to save time?
# handle a ref or plain data

	$self->{'write_buf'} .= ( ref $_[1] ) ? ${$_[1]} : $_[1] ;

	$self->{'write_event'}->start() ;
}


sub writeable {

	my( $self ) = @_ ;

	if ( $self->{'shut_down'} ) {

		return ;
	}

	my $buf_ref = \$self->{'write_buf'} ;
	my $buf_len = length $$buf_ref ;

	unless ( $buf_len ) {

		$self->{'write_event'}->stop() ;
		return ;
	}

	my $bytes_written = syswrite( $self->{'write_fh'}, $$buf_ref ) ;

	unless( defined( $bytes_written ) ) {

# do a SHUTDOWN
		return ;
	}

# remove the part of the buffer that was written 

	substr( $$buf_ref, 0, $bytes_written, '' ) ;


	return if length( $$buf_ref ) ;

	$self->shut_down() if $self->{'shut_down_after_flush'} ;
}

1 ;
