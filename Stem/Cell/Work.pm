#  File: Stem/Cell/Work.pm

#  This file is part of Stem.
#  Copyright (C) 1999, 2000, 2001, 2002 Stem Systems, Inc.

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

use Stem::Packet ;

sub _work_mode_init {

	my ( $self ) = @_ ;

	return unless $self->{'worker_mode'} ;

	return if $self->{'packet_codec'} ;

	my $packet = Stem::Packet->new( 'codec' => $self->{'work_codec'} ) ;
	return $packet unless ref $packet ;

	$self->{'packet'} = $packet ;

	return ;
}

sub cell_worker_ready {

	my ( $self ) = @_ ;

	my $cell_info = $self->_get_cell_info() ;

	my $ready_addr = $cell_info->{'work_ready_addr'} ;

	return unless $ready_addr ;

#print "READY addr [$ready_addr]\n" ;

	my $worker_msg = Stem::Msg->new(
				'to' => $ready_addr,
				'type' => 'worker',
				'from' => $cell_info->{'from_addr'},
	) ;

#print $worker_msg->dump('worker ready') ;

	$worker_msg->dispatch() ;

	return ;
}

sub async_read_data {

	my ( $self, $packet_text ) = @_ ;

	my $cell_info = $self->_get_cell_info() ;

#print "WORK text [$$packet_text]\n" ;

	my $work_obj = $cell_info->{'packet'}->to_data( $packet_text ) ;

	return unless defined $work_obj ;

	if ( $cell_info->{'work_generator'} ) {

		my $work_msg = Stem::Msg->new(
			'to'		=> $cell_info->{'data_addr'},
			'from'		=> $cell_info->{'from_addr'},
			'type'		=> 'cell_work',
			'reply_type'	=> 'cell_work',
			'data'		=> $work_obj,
		) ;

		$work_msg->dispatch() ;
	}
	else {

		my $work_msg = delete $cell_info->{'work_msg'} ;

		my $reply_msg = $work_msg->reply(
				 'data' => $work_obj,
		) ;

		$reply_msg->dispatch() ;
	}

	$cell_info->cell_worker_ready() ;
}

sub async_stderr_data {

	my ( $self, $data ) = @_ ;

	my $cell_info = $self->_get_cell_info() ;
	my $log = $cell_info->{'stderr_log'} ;

	return unless $log ;

	Stem::Log::Entry->new (
	       'logs'	=> $log,
	       'level'	=> 5,
	       'label'	=> 'STDERR: ' .
			Stem::Msg::address_string( $cell_info->{'from_addr'} ),
	       'text'	=> ${$data},
	) ;

	return ;
}

sub cell_work_in {

	my ( $self, $msg ) = @_ ;

#print $msg->dump( 'WORK MSG' ) ;

##################
# handle error: work when work in progress. check 'work_msg'
#################

	my $cell_info = $self->_get_cell_info() ;

	$cell_info->{'work_msg'} = $msg ;

	my $obj = $msg->data() ;

#print Store $obj ;

	my $packet_text = $cell_info->{'packet'}->to_packet( $obj ) ;

	$cell_info->cell_write( $packet_text ) ;
}

1 ;