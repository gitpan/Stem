#  File: Stem/Demo/Cmd.pm

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

package Stem::Demo::Cmd ;

use Cwd ;
use Carp ;
use Data::Dumper ;

my %demo_cmd_to_path = (

	ls	=> '/bin/ls',
	df	=> '/bin/df',
	du	=> '/bin/du',
) ;


sub msg_in {

	my( $self, $msg ) = @_ ;

#print $msg->dump( 'CMD' ) ;

	return unless $msg->type() eq 'cmd' ;

	my $cmd_name = $msg->cmd() ;

	my $cmd_arg = $msg->data() || '' ;
	$cmd_arg = ${$cmd_arg} if ref $cmd_arg ;
	$cmd_arg ||= '' ;

#print "cmd [$cmd_name] - [$cmd_arg]\n" ;

	return $self->help() if lc $cmd_name eq 'help' ;

	if ( $cmd_name eq 'cd' ) {

		my $cd_err = chdir $cmd_arg ? 'Succeeded' : 'Failed' ;
		my $cwd = cwd ;

		return "cd to '$cmd_arg' $cd_err. Cwd: $cwd\n" ;
	}

	my $cmd_path = $demo_cmd_to_path{ $cmd_name  } ;

	return "unknown command [$cmd_name]\n" unless $cmd_path ;

	local( *CMD ) ;

	my @cmd_args = split ' ', $cmd_arg ;

	unless ( open( CMD, '-|' ) ) {

		exec $cmd_path, @cmd_args ;

		die "can't exec $cmd_name\n" ;
	}

	local( $/ ) ;

	my $cmd_out = <CMD> ;

#print ::BUG "CMD DEMO out [$cmd_out]\n" ;

	return $cmd_out ;
}

sub help {

	return( <<HELP ) ;

Help for Stem::Demo::Cmd

Command Names:

	help		Print this help text
	cd		Change directory
	ls		Run /bin/ls
	df		Run /bin/df
	du		Run /bin/du

Examples:

	ls -l /			ls of /
	df .			df of current partition
	cd /tmp			chdir to /tmp
	du			run du in the current directory

HELP
}

1 ;
