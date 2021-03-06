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

#use Stem::Trace 'log' => 'stem_status', 'sub' => 'TraceStatus' ;
#use Stem::Trace 'log' => 'stem_error' , 'sub' => 'TraceError' ;

=head1 Description

This is a object module used by Stem Cells and objects to detect when
a set of asynchronous events have finished. It is constructed by an
owner object which then stores it in itselt. Gather objects are
initialized with a set of keys to be gathered. When the owner object
is notified of an event, it calls the C<gathered> method of the gather
object with a list of keys. When all of the keys are gathered, a
callback is made to the owner object. An optional timeout is available
which will also generate a callback if the keys are not gathered in
time.

=head1 Synopsis

	use Stem::Gather ;

        # $self is the owner object that has already been created

	my $gather = Stem::Gather->new(
		'object'	=> $self,
		'keys'		=> [qw( msg1 msg2 )]
	) ;

	$self->{'gather'} = $gather ;

	sub msg1_in {

		my( $self ) = @_ ;
		$self->{'gather'}->gathered( 'msg1' ) ;
	}

	sub msg2_in {

		my( $self ) = @_ ;
		$self->{'gather'}->gathered( 'msg2' ) ;
	}

	sub gather_done {

		my( $self ) = @_ ;

		print "we have gathered\n" ;
	}

=cut

use strict ;

my %class_to_attr_name ;

my $attr_spec = [

	{
		'name'		=> 'object',
		'required'	=> 1,
		'type'		=> 'object',
		'help'		=> <<HELP,
This is the owner object which has the methods that get called when Stem::Gather
has either finished gathering all of the keys or it has timed out.
HELP
	},
	{
		'name'		=> 'keys',
		'required'	=> 1,
		'type'		=> 'list',
		'help'		=> <<HELP,
This is the list of keys to gather.
HELP
	},
	{
		'name'		=> 'gathered_method',
		'default'	=> 'gather_done',
		'help'		=> <<HELP,
This method is called in the owner object when all of the keys are gathered.
HELP
	},
	{
		'name'		=> 'no_start',
		'type'		=> 'boolean',
		'help'		=> <<HELP,
If set, then do not start the gather object upon creation. A call to
the C<restart> must be made. This only meaningful if this gather has a
timeout set.
HELP
	},
	{
		'name'		=> 'timeout',
		'help'		=> <<HELP,
This is an optional timeout period (in seconds) waiting for the gather
to be completed
HELP
	},
	{
		'name'		=> 'timeout_method',
		'default'	=> 'gather_timeout',
		'help'		=> <<HELP,
This method is called in the owner object if the gather timed out
before all keys were gathered.
HELP
	},
] ;


###########
# This POD section is autoegenerated. Any edits to it will be lost.

=head2 Constructor Attributes for Class Stem::Gather

=over 4


=item * Attribute - B<object>

=over 4


=item Description:
This is the owner object which has the methods that get called when Stem::Gather
has either finished gathering all of the keys or it has timed out.


=item Its B<type> is: object

=item It is B<required>.

=back

=item * Attribute - B<keys>

=over 4


=item Description:
This is the list of keys to gather.


=item Its B<type> is: list

=item It is B<required>.

=back

=item * Attribute - B<gathered_method>

=over 4


=item Description:
This method is called in the owner object when all of the keys are gathered.


=item It B<defaults> to: gather_done

=back

=item * Attribute - B<no_start>

=over 4


=item Description:
If set, then do not start the gather object upon creation. A call to
the C<restart> must be made. This only meaningful if this gather has a
timeout set.


=item Its B<type> is: boolean

=back

=item * Attribute - B<timeout>

=over 4


=item Description:
This is an optional timeout period (in seconds) waiting for the gather
to be completed


=back

=item * Attribute - B<timeout_method>

=over 4


=item Description:
This method is called in the owner object if the gather timed out
before all keys were gathered.


=item It B<defaults> to: gather_timeout

=back

=back

=cut

# End of autogenerated POD
###########




=head2 Method new

This is the constructor method for Stem::Gather. It uses the standard
Stem key/value API with the

=cut

sub new {

	my( $class ) = shift ;

	my $self = Stem::Class::parse_args( $attr_spec, @_ ) ;
	return $self unless ref $self ;

# 	return 'Stem::Gather "keys" is not an array reference'
# 		unless ref $self->{'keys'} eq 'ARRAY' ;

	$self->restart() unless $self->{'no_start'} ;

	return( $self ) ;
}

=head2 Method restart

This method is called to start up the gather object when it has
already gathered all the keys, it has timed out or it was never
started (the no_start attribute was enabled). It takes no arguments.

=cut


sub restart {

	my( $self ) = @_ ;

	$self->{'gathered'} = 0 ;

	$self->{'keys_left'} = { map { $_, 1 } @{$self->{'keys'}} } ;

#	TraceStatus "GAT keys '@{$self->{'keys'}}'" ;

	$self->_cancel_timeout() ;

	if ( my $timeout = $self->{'timeout'} ) {

		$self->{'timer_event'} = Stem::Event::Timer->new(
				'object'	=> $self,
				'delay'		=> $timeout, 
				'hard'		=> 1,
				'repeat'	=> 0 ) ;
	}
}

=head2 Method add_keys

This method is passed a list of keys which will be added to the list
to be watched for by the Stem::Gather object. The new keys are not
looked for until a call to the C<restart> method is made.

=cut

sub add_keys {

	my( $self, @keys ) = @_ ;

	push @{$self->{'keys'}}, @keys ;
}

=head2 Method gathered

This method is called with a list of keys that are gathered. The keys
that haven't been gathered before are marked as gathered. If there are
no more keys to be gathered, the method in the C<gathered_method>
attribute is called in the owner object. You have to call the
C<restart> method on this gather object to use it again.You can pass
this methods keys that have been gathered or are not even in the list
to be gathered and they are ignored.

=cut

sub gathered {

	my( $self, @keys ) = @_ ;

#	TraceStatus "gathered: @keys" ;

	return if $self->{'gathered'} ;

	delete @{$self->{'keys_left'}}{@keys} ;

	return if keys %{$self->{'keys_left'}} ;

	$self->_cancel_timeout() ;
	$self->{'gathered'} = 1 ;

	my $method = $self->{'gathered_method'} ;

#	TraceStatus "gathered done: calling $method" ;

	return $self->{'object'}->$method() ;
}

sub timed_out {

	my( $self ) = @_ ;

	$self->_cancel_timeout() ;

	my $method = $self->{'timeout_method'} ;
	$self->{'object'}->$method() ;

	return ;
}

sub _cancel_timeout {

	my( $self ) = @_ ;

	if ( my $timer = $self->{'timer_event'} ) {
		$timer->cancel() ;

		delete $self->{'timer_event'} ;
	}
}

=head2 Method

This method B<must> be called if the owner object is being shut down or
destroyed. It will cancel any pending timeout and break the link back
to the owner object. The owner object can then be destroyed without
leaking memory.

=cut

sub shut_down {

	my( $self ) = @_ ;

	$self->_cancel_timeout() ;

	delete $self->{'object'} ;
}

1 ;
