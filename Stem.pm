#  File: Stem.pm

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

package Stem ;


use strict ;
use Event ;
use IO::Socket ;
use vars qw( $VERSION ) ;

$VERSION = 0.07 ;

use Stem::Route qw( :cell ) ;
use Stem::Vars ;
use Stem::Class ;
use Stem::Conf ;
use Stem::Event ;
use Stem::Log ;
use Stem::Msg ;
use Stem::Hub ;
use Stem::Portal ;
use Stem::Util ;

register_class( __PACKAGE__, 'stem' ) ;

sub status_cmd {

	return "Stem Version: $VERSION" ;
}

1 ;