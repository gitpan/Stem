#  File: Stem/WorkQueue.pm

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

package Stem::WorkQueue ;

use strict ;

my $attr_spec = [

] ;

sub new {

	my( $class ) = shift ;

	my $self = Stem::Class::parse_args( $attr_spec, @_ ) ;
	return $self unless ref $self ;

	$self->{ 'work_queue' } = [] ;
	$self->{ 'worker_queue' } = [] ;

	return $self ;
}

sub msg_in {

	my ( $self, $msg ) = @_ ;

	push( @{$self->{ 'work_queue' }}, $msg ) ;

	$self->_check_for_work() ;

	return ;
}

sub worker_in {

	my ( $self, $msg ) = @_ ;

#print $msg->dump('worker') ;

	push( @{$self->{ 'worker_queue' }}, $msg ) ;

	$self->_check_for_work() ;

	return ;
}

sub _check_for_work {

	my ( $self ) = @_ ;

	my $work_q = $self->{ 'work_queue' } ;
	my $worker_q = $self->{ 'worker_queue' } ;

	while( 1 ) {

# see if we have both workers and work to do

		return unless @{$work_q} && @${worker_q} ;

		my $work_msg = shift @{$work_q} ;
		my $worker_msg = shift @{$worker_q} ;

#use YAML ;

#print "WORK out [", Store( $worker_msg->from() ), "]\n" ;

		$work_msg->to( scalar $worker_msg->from() ) ;

#print $work_msg->dump( 'work' ) ;
		$work_msg->dispatch() ;
	}
}

sub status_cmd {

	my ($self) = @_ ;

	my $work_cnt = @{$self->{ 'work_queue' }} ;
	my $worker_cnt = @{$self->{ 'worker_queue' }} ;

	return <<STATUS ;

Work Queue:	$work_cnt
Worker Queue:	$worker_cnt

STATUS

}

1;
