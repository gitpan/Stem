#  File: Stem/Gather.pm

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

package Stem::Gather ;

use Stem::Trace 'log' => 'stem_status', 'sub' => 'TraceStatus' ;
use Stem::Trace 'log' => 'stem_error' , 'sub' => 'TraceError' ;

use strict ;

my %class_to_attr_name ;

my $attr_spec = [

	{
		'name'		=> 'object',
		'required'	=> 1,
		'type'		=> 'object',
		'help'		=> <<HELP,
Owner object to callback
HELP
	},

	{
		'name'		=> 'keys',
		'required'	=> 1,
		'type'		=> 'list',
		'help'		=> <<HELP,
List of keys to gather.
HELP
	},

	{
		'name'		=> 'gathered_method',
		'default'	=> 'gather_done',
		'help'		=> <<HELP,
Method to callback when all keys are gathered
HELP
	},

	{
		'name'		=> 'no_restart',
		'help'		=> <<HELP,
Do not start upon creation. A call to restart() must be made
HELP
	},

	{
		'name'		=> 'timeout',
		'help'		=> <<HELP,
Optional timeout period (in seconds)
HELP
	},

	{
		'name'		=> 'timeout_method',
		'default'	=> 'gather_timeout',
		'help'		=> <<HELP,
Method to callback when all timeout happened before all keys are gathered
HELP
	},

] ;


sub new {

	my( $class ) = shift ;

	my $self = Stem::Class::parse_args( $attr_spec, @_ ) ;
	return $self unless ref $self ;

	return 'Stem::Gather "keys" is not an array reference'
		unless ref $self->{'keys'} eq 'ARRAY' ;

	$self->restart() unless $self->{'no_restart'} ;

	return( $self ) ;
}

sub restart {

	my( $self ) = @_ ;

	$self->{'gathered'} = 0 ;

	$self->{'keys_left'} = { map { $_, 1 } @{$self->{'keys'}} } ;

	TraceStatus "GAT keys '@{$self->{'keys'}}'" ;

	$self->cancel_timeout() ;

	if ( my $timeout = $self->{'timeout'} ) {

		$self->{'timer_event'} = Stem::Event::Timer->new(
				'object'	=> $self,
				'delay'		=> $timeout, 
				'hard'		=> 1,
				'repeat'	=> 0 ) ;
	}
}

sub add_keys {

	my( $self, @keys ) = @_ ;

	push @{$self->{'keys'}}, @keys ;
}

sub gathered {

	my( $self, @keys ) = @_ ;

	TraceStatus "gathered: @keys" ;

	return if $self->{'gathered'} ;

	delete @{$self->{'keys_left'}}{@keys} ;

	return if keys %{$self->{'keys_left'}} ;

	$self->cancel_timeout() ;
	$self->{'gathered'} = 1 ;

	my $method = $self->{'gathered_method'} ;

	TraceStatus "gathered done: calling $method" ;

	return $self->{'object'}->$method() ;
}

sub timed_out {

	my( $self ) = @_ ;

	$self->cancel_timeout() ;

	my $method = $self->{'timeout_method'} ;
	$self->{'object'}->$method() ;

	return ;
}

sub cancel_timeout {

	my( $self ) = @_ ;

	if ( my $timer = $self->{'timer_event'} ) {
		$timer->cancel() ;

		delete $self->{'timer_event'} ;
	}
}

sub shut_down {

	my( $self ) = @_ ;

	$self->cancel_timeout() ;

	delete 	$self->{'object'} ;
}

1 ;
