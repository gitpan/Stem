#  File: Stem/Event.pm

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

package Stem::Event ;

use strict ;

use Stem::Trace 'log' => 'stem_status', 'sub' => 'TraceStatus' ;
use Stem::Trace 'log' => 'stem_error' , 'sub' => 'TraceError' ;

# basic package wrappers for top level Event.pm calls.

sub start_loop {

	$Event::DIED = \&died ;

	Event::loop() ;
}

sub died {
	my( $event, $err ) = @_ ;
        use Carp;
	Carp::cluck( "Stem::Event died: $err", "die called in [$event]\n",
                     map( "<$_>", caller() ), "\n" ) ;

	exit;
} ;


sub end_loop {

	Event::unloop_all( 1) ;
}

sub dump {

	local( $,) = ' ' ;

	for my $w ( Event::all_watchers() ) {

		TraceStatus "$w O ", @{$w->cb()}, "fd ", $w->fd(), "\n" ;
	}
}




sub trigger {

	my( $event, $object, $method, @args ) = @_ ;

	TraceStatus "[$event] [$object] [$method]\n" ;

###################
###################
# lookup cell name from object. log it and store it
###################
###################

	$Stem::Event::current_object = $object ;
	$object->$method( @args ) ;


###################
###################
# clear saved cell name and target???
###################
###################



	my ( $cell_name, $target ) = Stem::Route::lookup_cell_name( $object ) ;

	if ( $cell_name ) {

#		Debug 
#		    "EVENT $event to $cell_name:$target [$object] [$method]\n" ;
	}
	else {

#		Debug "EVENT $event to [$object] [$method]\n" ;
	}

	Stem::Msg::process_queue() ;
}


############################################################################

package Stem::Event::Plain ;

=head2 Stem::Event::Plain::new

This event is queued up for dispatch in the future when there no other
pending events. It has these attributes which are passed into the new
constructor:


=over 4

=item      'object'	=> <required object to trigger>

=item      'method'	=> <method to call (default is 'triggered')>

=back


=head2 Example

	$plain_event = Stem::Event::Plain->new( 'object' => $foo_obj ) ;

=cut


my $attr_spec_plain = [

	{
		'name'		=> 'object',
		'required'	=> 1,
		'type'		=> 'object',
		'help'		=> <<HELP,
HELP
	},

	{
		'name'		=> 'method',
		'default'	=> 'triggered',
		'help'		=> <<HELP,
HELP
	},

] ;

sub new {

	my( $class ) = shift ;

	my $self = Stem::Class::parse_args( $attr_spec_plain, @_ ) ;
	return $self unless ref $self ;
	
# create the plain event watcher

	my $idle_event = Event->idle(
			'cb'		=> [ $self, 'idle_triggered' ],
			'repeat'	=> 0
		) ;

	$self->{'idle_event'} = $idle_event ;

	return $self ;
}

sub idle_triggered {

	my( $self ) = @_ ;

	Stem::Event::trigger( 'plain', $self->{'object'},
				       $self->{'method'} ) ;

	$self->{'idle_event'}->cancel() ;

	delete( $self->{'idle_event'} ) ;
}

############################################################################

package Stem::Event::Plain::Test ;

sub go {

	print __PACKAGE__, " testing\n" ;

	Stem::Event::Plain->new( 'object' => bless {} ) ;

	Stem::Event::start_loop() ;

	print "end test\n" ;
}

# default callback method

sub triggered {

	my( $self ) = @_ ;

	print "success\n" ;
}


############################################################################

package Stem::Event::Signal ;

=head2 Stem::Event::Signal::new

This event is triggered by signals. It has these attributes which are
passed into the new constructor:


=over 4

=item      'object'	=> <required object to trigger>

=item      'method'	=> <method to call (default is 'SIG_handler')>
			   where SIG is the lower case name of the signal

=item      'signal'	=> <name of signal>

=back


=head2 Example

	$signal_event = Stem::Event::Signal->new( 'object' => $foo_obj
						  'signal' => 'INT' ) ;

	sub sigint_handler { die "SIGINT\n" }

=cut


my $attr_spec_signal = [

	{
		'name'		=> 'object',
		'required'	=> 1,
		'type'		=> 'object',
		'help'		=> <<HELP,
HELP
	},

	{
		'name'		=> 'signal',
		'required'	=> 1,
		'help'		=> <<HELP,
HELP
	},

	{
		'name'		=> 'method',
		'help'		=> <<HELP,
HELP
	},

] ;

sub new {

	my( $class ) = shift ;

	my $self = Stem::Class::parse_args( $attr_spec_signal, @_ ) ;
	return $self unless ref $self ;

	$self->{'method'} = $self->{ 'method' } ||
			    "sig_\L$self->{'signal'}_handler" ;

# create the signal event watcher

	my $signal_event = Event->signal(
			'cb'		=> [ $self, 'signal_triggered' ],
			'signal'	=> $self->{'signal'},
		) ;

	$self->{'signal_event'} = $signal_event ;

	return $self ;
}

sub signal_triggered {

	my( $self ) = @_ ;

	Stem::Event::trigger( "signal $self->{'signal'}",
			      $self->{'object'},
			      $self->{'method'} ) ;
}

sub cancel {

	my( $self ) = @_ ;

	$self->{'signal_event'}->cancel() ;

	delete( $self->{'signal_event'} ) ;
}


############################################################################

package Stem::Event::Signal::Test ;

sub go {

	print __PACKAGE__, " testing\n" ;

	Stem::Event::Signal->new( 'object' => bless({}), 'signal' => 'INT' ) ;

	Stem::Event::start_loop() ;

	print "end test\n" ;
}

# default callback method

sub sigint_handler {

	my( $self, $event ) = @_ ;

	print "SIGINT\n" ;
}


############################################################################

package Stem::Event::Timer ;


=head2 Stem::Event::Timer::new

This event is queued up for dispatch in the future at a given time
('at') or after a minimum time period has elapsed ('delay'). One of the
two time attributes 'at' or 'delay' must be set. Here are the allowed
attributes:

=over 4

=item	'object'	=> <required object to trigger>

=item	'at'		=> <epoch time when to trigger event>

=item	'delay'		=> <time in seconds to wait before triggering event>

=item	'method'	=> <method to call (default is 'timed_out')>

=item	'interval'	=> <interval in seconds before retriggers>

=item	'hard'		=> interval timer starts at start of callback

=item	'single'	=> single shot timer 

=back

=cut

my $attr_spec_timer = [

	{
		'name'		=> 'object',
		'required'	=> 1,
		'type'		=> 'object',
		'help'		=> <<HELP,
HELP
	},

	{
		'name'		=> 'delay',
#		'required'	=> 1,
		'mutex'		=> 'times',
		'help'		=> <<HELP,
HELP
	},

	{
		'name'		=> 'at',
#		'required'	=> 1,
		'mutex'		=> 'times',
		'help'		=> <<HELP,
HELP
	},

	{
		'name'		=> 'method',
		'default'	=> 'timed_out',
		'help'		=> <<HELP,
HELP
	},

	{
		'name'		=> 'hard',
		'type'		=> 'boolean',
		'default'	=> 0,
		'help'		=> <<HELP,
HELP
	},

	{
		'name'		=> 'interval',
		'default'	=> 0,
		'help'		=> <<HELP,
HELP
	},

	{
		'name'		=> 'single',
		'type'		=> 'boolean',
		'default'	=> 0,
		'help'		=> <<HELP,
HELP
	},

] ;

sub new {

	my( $class ) = shift ;

	my $self = Stem::Class::parse_args( $attr_spec_timer, @_ ) ;
	return $self unless ref $self ;

	my( @time_args ) ;

	if ( exists( $self->{ 'delay' } ) ) {

		@time_args = ( 'after' => $self->{ 'delay' } ) ;
	}
	elsif ( exists( $self->{ 'at' } ) ) {

		@time_args = ( 'at' => $self->{ 'at' } ) ;
	}
	else {

		return "No delay or at attributes for Stem::Event::Timer\n" ;
	}

# create the timer event watcher

	my $timer_event = Event->timer(
			'cb'		=> [ $self, 'timer_triggered' ],
			'hard'		=> $self->{'hard'},
			'interval'	=> $self->{'interval'},
			@time_args,
		) ;

	$self->{'timer_event'} = $timer_event ;

	return $self ;
}

sub timer_triggered {

	my( $self ) = @_ ;


	Stem::Event::trigger( 'timer', $self->{'object'},
				       $self->{'method'} ) ;


	$self->cancel() if $self->{'single'} ;
}

sub cancel {

	my( $self ) = @_ ;

	$self->{'timer_event'}->cancel() ;

	delete( $self->{'timer_event'} ) ;
	delete( $self->{'object'} ) ;
}

############################################################################

package Stem::Event::Timer::Test ;

sub go {

	my( $self ) ;

	print __PACKAGE__, " testing\n" ;

	print <<EOT ;

Soft timeouts are at 10 second intervals + 4 second sleep time.
Hard timeouts are at 10 second intervals and don't count the sleep time.

EOT

	$self = bless { 'type' => 'hard', 'count' => 3 } ;
	my $evt = Stem::Event::Timer->new( 'object' => $self, 'hard' => 1,
					   'delay' => 6, 'interval' => 10,
					   'repeat' => 1 ) ;

	print $evt unless ref $evt ;
	$self->{'timer_event'} = $evt ;


	$self = bless { 'type' => 'soft', 'count' => 3 } ;
	$evt = Stem::Event::Timer->new( 'object' => $self,  'delay' => 2,
				        'interval' => 10, 'repeat' => 1 ) ;

	print $evt unless ref $evt ;
	$self->{'timer_event'} = $evt ;

	print scalar localtime, "\n" ;

	Stem::Event::start_loop() ;

	print "end test\n" ;
}

# default callback method

sub timed_out {

	my( $self ) = @_ ;

	print scalar localtime ;

	print "  timed out $self->{'type'}\n" ;
	
	sleep 4 ;

	return if $self->{'count'}-- > 0 ;

	$self->{'timer_event'}->cancel() ;

	print "canceled\n"
}

############################################################################

package Stem::Event::Read ;

=head2 Stem::Event::Read::new

This event is triggered whenever its file descriptor has data to be read.
It takes an optional timeout value which will trigger the read_timeout
method if no data has come in during that period.

=over 4

	'object'	=> <required object to trigger>

	'fh'		=> <required file descriptor to watch for reading>


	'method'	=> <method to call - default is 'readable'>

	'timeout_method' =>
		<method to call when timed out (default is 'read_timeout')>


	'timeout'	=>
		<timeout in seconds to wait on a read (default is no timeout)>

=back

=cut

my $attr_spec_read = [

	{
		'name'		=> 'object',
		'required'	=> 1,
		'type'		=> 'object',
		'help'		=> <<HELP,
HELP
	},

	{
		'name'		=> 'fh',
		'required'	=> 1,
		'type'		=> 'handle',
		'help'		=> <<HELP,
HELP
	},

	{
		'name'		=> 'timeout',
		'help'		=> <<HELP,
HELP
	},

	{
		'name'		=> 'method',
		'default'	=> 'readable',
		'help'		=> <<HELP,
HELP
	},

	{
		'name'		=> 'timeout_method',
		'default'	=> 'read_timeout',
		'help'		=> <<HELP,
HELP
	},

] ;

sub new {

	my( $class ) = shift ;

	my $self = Stem::Class::parse_args( $attr_spec_read, @_ ) ;
	return $self unless ref $self ;

	my @timeout_args ;

# handle optional timeout args

	if ( my $timeout = $self->{'timeout'} ) {

		@timeout_args = (
			'timeout'	=> $timeout,
			'timeout_cb'	=> [ $self, 'timeout_triggered' ]
		) ;
	}

# create the read event watcher

	my $read_event = Event->io(
			'cb'	=> [ $self, 'read_triggered' ],
			'fd'	=> $self->{'fh'},
			'poll'	=> 'r',
			@timeout_args
		) ;
		
	$self->{'read_event'} = $read_event ;

	return $self ;
}

sub read_triggered {

	my( $self ) = @_ ;

	Stem::Event::trigger( 'read', $self->{'object'},
				      $self->{'method'} ) ;
}

sub timeout_triggered {

	my( $self ) = @_ ;

	Stem::Event::trigger( 'read_timeout', $self->{'object'},
					      $self->{'method'} ) ;
}


# wrapper for event cancel

sub cancel {

	my( $self ) = @_ ;

	$self->{'read_event'}->cancel() ;

	delete $self->{'read_event'} ;
}

sub stop {

	my( $self ) = @_ ;

	$self->{'read_event'}->stop() ;
}

sub start {

	my( $self ) = @_ ;

	$self->{'read_event'}->start() ;
}

############################################################################

package Stem::Event::Read::Test ;

use Symbol ;

sub go {

	my( $self, @pipe, $read_fh, $write_fh, $read_event, $write_event ) ;

	print __PACKAGE__, " testing\n" ;

	$read_fh = gensym ;
	$write_fh = gensym ;

# get a pipe to read/write through.

	pipe( $read_fh, $write_fh ) ;

# create the test object ;

	$self = bless {
			'message'	=> 'Stem Read/Write Event',
			'read_fh'	=> $read_fh,
			'write_fh'	=> $write_fh,
	} ;

# create the read and write events

	$read_event = Stem::Event::Read->new(
				'object'	=>	$self,
				'fh'		=>	$read_fh,
				'timeout'	=>	3,
	) ;

	$self->{'read_event'} = $read_event ;

	$write_event = Stem::Event::Write->new(
				'object'	=>	$self,
				'fh'		=>	$write_fh,
	) ;

	$self->{'write_event'} = $write_event ;


#  syswrite( $self->{'write_fh'},'foobar' ) ;
#  my $read_buf ;
#  my $bytes_read = sysread( $self->{'read_fh'}, $read_buf, 1000 ) ;

#  die 'closed' unless $bytes_read ;

#  print "read $bytes_read bytes [$read_buf]\n" ;


# enable the write event

	$write_event->start() ;

print "main loop\n" ;
	Stem::Event::start_loop() ;

	print "end test\n" ;
}

# default callback method


sub readable {

	my( $self, $event ) = @_ ;

	my( $read_buf ) ;

	my $bytes_read = sysread( $self->{'read_fh'}, $read_buf, 1000 ) ;

	die 'closed' unless $bytes_read ;

	print "read $bytes_read bytes [$read_buf]\n" ;
}

sub read_timeout {

	my( $self, $event ) = @_ ;

#	$self->{'read_event'}->cancel() ;

	close( $self->{'write_fh'} ) ;

	print "read timed out, canceled\n"
}

sub writeable {

	my( $self ) = @_ ;

	syswrite( $self->{'write_fh'}, $self->{'message'} ) ;

	print "wrote [$self->{'message'}]\n" ;

	$self->{'write_event'}->cancel() ;

#	print "write canceled\n"
}


############################################################################

package Stem::Event::Write ;

=head2 Stem::Event::Write::new

This event is triggered whenever its file descriptor can be written to.
It takes an optional timeout value which will trigger the write_timeout
method if no data be written during that period. Write events are
stopped when created - a call to the start method is needed to activate
them.

=over 4

	'object'	=> <required object to trigger>

	'fh'		=> <required file descriptor to watch for writing>


	'method'	=> <method to call - default is 'writeable'>

	'timeout_method' =>
		<method to call when timed out (default is 'write_timeout')>


	'timeout'	=>
		<timeout in seconds to wait on a write (default is no timeout)>

=back

=cut

my $attr_spec_write = [

	{
		'name'		=> 'object',
		'required'	=> 1,
		'type'		=> 'object',
		'help'		=> <<HELP,
HELP
	},

	{
		'name'		=> 'fh',
		'required'	=> 1,
		'type'		=> 'handle',
		'help'		=> <<HELP,
HELP
	},

	{
		'name'		=> 'timeout',
		'help'		=> <<HELP,
HELP
	},

	{
		'name'		=> 'method',
		'default'	=> 'writeable',
		'help'		=> <<HELP,
HELP
	},

	{
		'name'		=> 'timeout_method',
		'default'	=> 'write_timeout',
		'help'		=> <<HELP,
HELP
	},
	{
		'name'		=> 'init_off',
		'help'		=> <<HELP,
This event is intially off. Call the start method to turn it on.
HELP
	},

] ;

sub new {

	my( $class ) = shift ;

	my $self = Stem::Class::parse_args( $attr_spec_write, @_ ) ;
	return $self unless ref $self ;

	my @timeout_args ;

# handle optional timeout args

	if ( my $timeout = $self->{'timeout'} ) {

		@timeout_args = (
			'timeout'	=> $timeout,
			'timeout_cb'	=> [ $self, 'timeout_triggered' ]
		) ;
	}

# create the write event watcher

	my $write_event = Event->io(
			'cb'	=> [ $self, 'write_triggered' ],
			'fd'	=> $self->{'fh'},
			'poll'	=> 'w',
			@timeout_args
		) ;
		

	$self->{'write_event'} = $write_event ;

	return $self ;
}


sub write_triggered {

	my( $self ) = @_ ;

	Stem::Event::trigger( 'write', $self->{'object'},
				       $self->{'method'} ) ;
}

sub timeout_triggered {

	my( $self ) = @_ ;

	Stem::Event::trigger( 'write_timeout', $self->{'object'},
					       $self->{'method'} ) ;
}

# wrapper for event cancel

sub cancel {

	my( $self ) = @_ ;

	$self->{'write_event'}->cancel() ;

	delete $self->{'write_event'} ;
}

sub stop {

	my( $self ) = @_ ;

	$self->{'write_event'}->stop() ;
}

sub start {

	my( $self ) = @_ ;

	$self->{'write_event'}->start() ;
}



############################################################################

package Stem::Event::Write::Test ;

sub go {

	print "calling Stem::Event::Read::Test\n" ;

	goto &Stem::Event::Read::Test::go ;
}


1 ;