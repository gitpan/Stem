#!/usr/local/bin/perl -w
#  File: install.pl

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

use strict;

use Config;
use Carp;
use Cwd ;
use File::Path ;

my( @stem_modules, @stem_module_dirs, @stem_executables, @stem_links,
    @stem_demos, @stem_confs, @perl_modules, %conf, $stem_dir,
    @files_written ) ;


$| = 1 ;

check_manifest() ;

get_path_conf() ;

get_perl_modules_conf() ;

get_demo_conf() ;

install_perl_modules() ;

install_stem_confs() ;

install_stem_modules() ;

install_stem_execs() ;

install_stem_demos() ;


print <<TEXT ;

Congratulations on installing Stem. If you have any questions on Stem
or installing it, email them to help\@stemsystems.com

Please make sure you read the DEMO_* documents which tell you how to run the
demonstration scripts.

If you need to uninstall the files Stem just installed, all of them
are listed in the file 'installed_files'. You can delete them all with
the make command:

	make uninstall_stem

TEXT

write_file( 'installed_files', @files_written ) ;

exit ;

##########

sub check_manifest {

	my $err ;

	$stem_dir = cwd ;

	die <<DIE unless -e "$stem_dir/Stem.pm" && -d "$stem_dir/Stem" ;
You must execute this install from the stem source directory.
DIE

	print "\nChecking Stem distribution...";


	print "\nChecking Stem Modules...";
	foreach my $file ( @stem_modules ) {
	    $err .= "\tCould not find $file\n" unless -e $file ;
	}

	print "\nChecking Stem Executables...";
	foreach my $file ( @stem_executables ) {
	    $err .= "\tCould not find bin/$file\n" unless -e "bin/$file" ;
	}

	print "\nChecking Stem Configurations...";
	foreach my $file ( @stem_confs ) {
	    $err .= "\tCould not find conf/$file.stem\n"
				unless -e "conf/$file.stem" ;
	}

	die <<DIE if $err ;


Missing files:

$err

Please check if you have a clean download and if you extracted the all files.

DIE

	print "\nStem distribution is ok.\n";
}

# get all the useful info from the $Config hash or user settings for them

sub get_path_conf {

	print <<TEXT;

Welcome to the Stem installation script.

This script will ask you various questions in order to properly
configure and install Stem on your system.  Whenever a question is
asked, the default answer will be shown inside [brackets].  Pressing
enter will accept the default answer. If a choice needs to be made
list of values, the list will be inside (parentheses).

TEXT

	$conf{'perl_path'} = query_value( <<TEXT, $Config{'perlpath'} ) ;

Stem has several executable Perl programs and demonstration scripts
and they need to have the correct path to your perl binary.

What is the path to perl? []
TEXT

	$conf{'bin_path'} = query_value( <<TEXT, $Config{'bin'} ) ;

Those Stem executables need to be installed in a directory that is in your
shell \$PATH.

What directory will have the Stem executables? []
TEXT

	$conf{'perl_lib'} = query_value( <<TEXT, $Config{'sitelib'} ) ;

Stem has a library of Perl modules that need to be installed in the
path searched by your perl binary.

What is the directory of perl's site library? []
TEXT

	my $stem_dir = $conf{'perl_lib'} ;
	$stem_dir =~ s{/perl.*$}{/stem}i ;
	$conf{'stem_dir'} = $stem_dir ;

	my $conf_dir = "$stem_dir/conf" ;

	$conf{'conf_path'} = query_value( <<TEXT, $conf_dir ) ;

Stem configuration files are used to create and initialize Stem Cells
(objects). Stem needs to know the list of directories to search to
find its configurations files.

Note that the default has a single absolute path. You can test Stem
configurations easily setting this path when running Stem. You can
override or modify the path time with either a shell environment
variable or on the command line of run_stem. See the documentation on
run_stem for how so do this.

What directory will hold the Stem configuration files? []
TEXT

}

sub get_perl_modules_conf {

	print <<TEXT ;

Stem requires several Perl modules. This section will check if your
system has them installed and if their versions are recent enough.

TEXT

	foreach my $mod_info ( @perl_modules ) {

		my $mod_name = $mod_info->{'name'} ;
		my $mod_version = $mod_info->{'version'} ;

		eval {
			require "$mod_name.pm" ;
		} ;

		if( $@ ) {

			$mod_info->{'install'} = 1 ;

			print <<TEXT ;
	$mod_name.pm is not installed on this system
TEXT

			next ;
		}

		no strict 'refs' ;

		if ( ${"${mod_name}::VERSION"} < $mod_version ) {

			$mod_info->{'install'} = 1 ;

			print <<TEXT ;
	$mod_name.pm was found but it is not recent enough for Stem.
TEXT

			next ;
		}

		print <<TEXT ;
	$mod_name.pm was found and it is recent enough for Stem.
TEXT
	}
}

sub get_demo_conf {

	$conf{'install_stem_demos'} = query_boole( <<TEXT ) ;

Stem comes with several demonstration scripts.
Do you want to install them?
TEXT

	return unless $conf{'install_stem_demos'} ;

	get_xterm_path() ;

	$conf{ 'tail_dir' } = query_value( <<TEXT, '/tmp/tail' ) ;

The tail demo script needs a temporary working directory.
Enter the path to a directory which can be created with mkdir [] ?
TEXT

	$conf{'install_ssfe'} = query_boole( <<TEXT ) ;

ssfe (Split Screen Front End) is a compiled program optionally used by
the Stem demonstration scripts that provides a full screen interface
with command line editing and history. It is not required to run Stem
but it makes the demonstrations easier to work with and they look
nicer. To use ssfe add the '-s' option when you run any demonstration
script. You can also use ssfe for your own programs.  Install ssfe in
some place in your \$PATH ($conf{'bin_path'} is where Stem executables
are being installed) so it can be used by the demo scripts. The ssfe
install script will do this for you or you can do it manually after
building it.

Do you want to install ssfe?
TEXT

}

sub get_xterm_path {

	my $xterm = '' ;
	my $xterm_text ;

	if ( $xterm = which( 'xterm' ) ) {

		$xterm_text = "xterm was found at '$xterm'" ;
#print "which xterm = $xterm\n" ;
	}
	else {
		foreach my $path ( qw(
			/usr/openwin/bin/xterm
			/usr/bin/X11/xterm
			/usr/X11R6/bin/xterm ) ) {

			next unless -e $path ;

			$xterm = $path ;
			$xterm_text = "xterm was found at '$xterm'" ;

			last ;
		}
	}

	$xterm_text ||= <<TEXT ;
xterm was not found on this system. you can't run the demo programs
without xterm Make sure you enter a valid path to xterm or some other
terminal emulator.
TEXT

	$xterm = query_value( <<TEXT, $xterm ) ;

$xterm_text
Enter the path to xterm (or another terminal emulator)? []
TEXT

	if ( -e $xterm ) {

		$conf{ 'xterm_path' } = $xterm ;
		return ;
	}
}


sub install_stem_execs {

	foreach my $exec ( @stem_executables ) {

		my $exec_text = read_file( "bin/$exec" ) ;

		$exec_text =~ s{/usr/local/bin/perl}[$conf{'perl_path'}] ;

		if ( $exec eq 'run_stem' ) {

			$exec_text =~ s/'conf:.'/'$conf{'conf_path'}'/ ;
			$exec_text =~ s|/usr/local/stem|$conf{'stem_dir'}| ;
		}

		my $err = write_file( "$conf{'bin_path'}/$exec", $exec_text ) ;

		die "$err\n" if $err ;

		chmod 0755, "$conf{'bin_path'}/$exec" ;
	}

# install symlinks to run_stem which will run and load a config file
# of that name.

	chdir $conf{'bin_path'} or die "Can't chdir to $conf{'bin_path'}\n" ;

	foreach my $link ( @stem_links ) {

		symlink( 'run_stem', $link ) ;
	}

	chdir $stem_dir ;
}

sub install_stem_confs {

	my $conf_dir = $conf{'conf_path'} ;

	unless( -d $conf_dir ) {

		mkpath( $conf_dir, 1, 0755 ) ;
	}

	foreach my $conf ( @stem_confs ) {

		my $conf_text = read_file( "conf/$conf.stem" ) ;

		if ( $conf eq 'inetd' ) {

			$conf_text =~ s[path\s+=>\s+'proc_serv',]
				       [path\t\t=> '$stem_dir/bin/proc_serv',];
		}
		elsif ( $conf eq 'monitor' || $conf eq 'archive' ) {

			$conf_text =~ s[path'\s+=>\s+'tail]
				       [path'\t\t=> '$conf{'tail_dir'}]g ;
		}

		my $err = write_file( "$conf_dir/$conf.stem", $conf_text ) ;

		die "\n$err\n" if $err ;
	}
}

sub install_stem_modules {

	my $lib_dir = $conf{'perl_lib'} ;

	mkpath( "$lib_dir/Stem", 1, 0755 ) ;

	foreach my $sub_dir ( @stem_module_dirs ) {

		mkpath( "$lib_dir/Stem/$sub_dir", 1, 0755 ) ;
	}

	foreach my $module ( @stem_modules ) {

		my $mod_text = read_file( $module ) ;
		my $err = write_file( "$lib_dir/$module", $mod_text ) ;

		die "\n$err\n" if $err ;
	}
}

sub install_stem_demos {

	return unless $conf{'install_stem_demos'} ;

	foreach my $demo ( @stem_demos ) {

		my $demo_text = read_file( "bin/$demo" ) ;

		$demo_text =~ s{/usr/local/bin/perl}[$conf{'perl_path'}] ;

		$demo_text =~ s{xterm}[$conf{'xterm_path'}]g ;

		if ( $demo eq 'tail_demo' ) {

			$demo_text =~ s['tail']
				       ['$conf{'tail_dir'}'] ;
		}

		my $err = write_file( "$conf{'bin_path'}/$demo", $demo_text ) ;

		die "$err\n" if $err ;

		chmod 0755, "$conf{'bin_path'}/$demo" ;
	}

	install_ssfe() ;
}

sub install_ssfe {

	return unless $conf{'install_ssfe'} ;

	print <<TEXT ;

Installing ssfe. This is not a Stem install script and it will ask its
own questions. It will execute in its own xterm (whatever was
configured earlier) to keep this install's output clean. The xterm is
kept open with a long sleep call and can be exited by typing ^C.

TEXT

	system <<SYS ;
xterm -e /bin/sh -c 'chdir extras ;
tar zxvf sirc-2.211.tar.gz ;
chdir sirc-2.211 ;
./install ;
sleep 1000 ;'
SYS

	print "\nInstallation of ssfe is done\n\n"
}



sub install_perl_modules {

	my $install_cpan = query_boole( <<TEXT ) ;

Some Perl modules need to be installed for Stem. The latest versions
can be installed from the CPAN if you have the CPAN.pm module
installed or versions of them can be installed from the Stem
distribution which needs the gunzip and tar programs to be
available. You can choose either method. You can also install these
modules manually from either CPAN or the Stem distribution.

Do you want to install the Perl modules from CPAN?

TEXT

	if ( $install_cpan ) {

		eval {
			require 'CPAN.pm' ;
		} ;

		if( $@ ) {

			die <<DIE ;

CPAN.pm is not installed. Please install it so the Perl modules can
installed from the CPAN. 

DIE
		}
	}
	else {
		unless( which( 'gunzip' ) ) {

		die <<DIE ;

'gunzip' is not in your path. Please install it so the Perl modules
can be installed from the Stem distibution.

DIE
		}
	}

	foreach my $mod_info ( @perl_modules ) {

		next unless $mod_info->{'install'} ;

		my $mod_name = $mod_info->{'name'} ;

		if ( $install_cpan ) {

			CPAN::install( $mod_name ) ;

		}
		else {

			my $module = "$mod_name-$mod_info->{'version'}" ;

		system <<SYS ;
chdir modules ;
gunzip -c $module.tar.gz | tar xvf - ;
chdir $module ;
perl Makefile.PL ;
make test install ;
SYS
		}
	}
}

sub which {

	my( $bin ) = @_;

	my $pathdir;

	foreach $pathdir ( split /:/, $ENV{PATH} ) {

		return "$pathdir/$bin" if -e "$pathdir/$bin" ;
	}

	return ;
}

sub query_boole {

	my( $question, $default ) = @_;

	$default = 1 unless defined $default ;

	chomp $question ;

	$question .= $default ? ' [y] (y/n) > ' : ' [n] (y/n) > ' ;

	while( 1 ) {

		print $question;

		chomp( my $answer = <STDIN> ) ;

		die 'EOF' unless defined $answer ;

		return $default if $answer =~ /^$/ ;

		return 1 if $answer =~ /^y/i ;
		return 0 if $answer =~ /^n/i ;

		print "Sorry, '$answer' is not a valid choice.\n";
	}
}

sub query_value {

	my( $question, $default ) = @_;

	$default = '' unless defined $default ;

	chomp $question ;
	$question =~ s/\[.*\]/\n\t[$default] > /;

	print $question;

	my $answer = <STDIN> ;

	die "\nEOF - exiting\n" unless defined $answer ;

	return $default if $answer =~ /^$/ ;

	chomp $answer ;

	return $answer ;
}

sub query_list {

	my( $question, $default, @valid_answers ) = @_;

	my %is_valid = map { $_, 1 } @valid_answers ;

	$question =~ s/\[.*\]/[$default] (@valid_answers) /;

	while( 1 ) {

		print $question;

		my $answer = <STDIN> ;

		die "\nEOF - exiting\n" unless defined $answer ;

		return $default if $answer =~ /^$/ ;

		chomp $answer ;

		return $answer if $is_valid{ $answer } ;

		print "Sorry, '$answer' is not a valid choice.\n";
	}
}


sub read_file {

	my( $file_name ) = shift ;

	my( $buf ) ;

	local( *FH ) ;

	open( FH, $file_name ) || croak "Can't open $file_name $!" ;

	return <FH> if wantarray ;

	read( FH, $buf, -s FH ) ;
	return $buf ;
}


sub write_file {

	my( $file_name ) = shift ;

	push( @files_written, "$file_name\n" ) ;

	local( *FH ) ;

	open( FH, ">$file_name" ) || return "Can't create $file_name $!" ;

	print FH @_ ;

	return ;
}

BEGIN {

@stem_modules = qw(
		Stem.pm
		Stem/AsyncIO.pm
		Stem/Boot.pm
		Stem/ChatLabel.pm
		Stem/DBI.pm
		Stem/Cell.pm
		Stem/Cell/Clone.pm
		Stem/Cell/Pipe.pm
		Stem/Cell/Sequence.pm
		Stem/Cell/Work.pm
		Stem/Class.pm
		Stem/Codec/Data/Dumper.pm
		Stem/Codec/Storable.pm
		Stem/Codec/YAML.pm
		Stem/Conf.pm
		Stem/Console.pm
		Stem/Cron.pm
		Stem/DBI.pm
		Stem/Demo/Cmd.pm
		Stem/Event.pm
		Stem/Gather.pm
		Stem/Hub.pm
		Stem/Id.pm
		Stem/Inject.pm
		Stem/Load/Driver.pm
		Stem/Log.pm
		Stem/Log/Entry.pm
		Stem/Log/File.pm
		Stem/Log/Tail.pm
		Stem/Msg.pm
		Stem/Packet.pm
		Stem/Portal.pm
		Stem/Proc.pm
		Stem/Route.pm
		Stem/SockMsg.pm
		Stem/Socket.pm
		Stem/Switch.pm
		Stem/Test/Echo.pm
		Stem/Test/ConfTypes.pm
		Stem/Trace.pm
		Stem/TtySock.pm
		Stem/Util.pm
		Stem/Vars.pm
		Stem/WorkQueue.pm
) ;

@stem_module_dirs = qw(
		Cell
		Codec
		Codec/Data
		Demo
		Load
		Log
		Socket
		Test
) ;

@stem_executables = qw(
		run_stem
		stem_msg
) ;

# these will be symlinks to run_stem.
# running them will be the same as run_stem <symlink>

@stem_links = qw(
		ttysock
) ;

@stem_demos = qw(
		chat_demo
		chat2_demo
		inetd_demo
		tail_demo
) ;

@stem_confs = qw(
		chat
		chat_client
		chat_label
		chat_server
		inetd
		archive
		monitor
		ttysock
		hello_shell
		hello_server
		hello_yaml
		boot
) ;

@perl_modules = (

	{
		'name'		=> 'Event',
		'version'	=> '0.77',
	},

	{
		'name'		=> 'IO',
		'version'	=> '1.20',
	},
) ;

}
