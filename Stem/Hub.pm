#  File: Stem/Hub.pm

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

package Stem::Hub ;

use Stem::Trace 'log' => 'stem_status', 'sub' => 'TraceStatus' ;
use Stem::Trace 'log' => 'stem_error' , 'sub' => 'TraceError' ;

use strict ;
use Carp ;
use Sys::Hostname ;

use Stem::Vars ;

$Stem::Vars::Hub_name = 'None' ;
$Stem::Vars::Program_name = $0 ;
$Stem::Vars::Host_name = hostname() ;

Stem::Route::register_class( __PACKAGE__, 'hub' ) ;

my $attr_spec = [

	{
		'name'		=> 'reg_name',
		'help'		=> <<HELP,
The registration name is used to name this Hub.
HELP
	},

] ;


sub new {

	my( $class ) = shift ;

	my $self = Stem::Class::parse_args( $attr_spec, @_ ) ;
	return $self unless ref $self ;

	$Stem::Vars::Hub_name = $Env{ 'hub_name' } ||
				$self->{ 'reg_name' } ||
				$Stem::Vars::Program_name ;

	TraceStatus "hub name is '$Stem::Vars::Hub_name'" ;

###########################
###########################
# add code to open hub log 
# 
###########################
###########################

	return ;
}

sub status_cmd {

	return <<STATUS ;

	Hub Status

Name:		$Stem::Vars::Hub_name
Host:		$Stem::Vars::Host_name
Program:	$Stem::Vars::Program_name

STATUS

}

1 ;
