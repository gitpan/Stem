
my %ssh_procs ;



	{
		'name'		=> 'ssh_path',
		'env'		=> 'ssh_path',
		'default'	=> '/usr/local/bin/ssh',
		'help'		=> <<HELP,
HELP
	},
	{
		'name'		=> 'use_ssh',
		'env'		=> 'use_ssh',
		'help'		=> <<HELP,
HELP
	},

	{
		'name'		=> 'ssh_port',
		'env'		=> 'ssh_port',
		'help'		=> <<HELP,
HELP
	},

	if ( $self->{ 'use_ssh' } ) {

		$self->_ssh1() ;
	}
	elsif ( $self->{ 'use_ssh2' } ) {

		return $self->_ssh2() ;
	}



sub _ssh1 {

	my( $self ) = @_ ;

	my $ssh_port = $self->{'ssh_port'} ;

	$ssh_port or return "Missing ssh_port in Portal '$self->{'reg_name'}" ;

	my $remote_port = $self->{'port'} ;
	my $remote_host = $self->{'host'},
	$self->{'port'} = $ssh_port ;
	$self->{'host'} = 'localhost' ;

	$self->{'remote_port'} = $remote_port ;
	my $remote_interface = 'localhost' ;

	require Stem::Proc ;

	my $proc = Stem::Proc->new(

		'path'		=> $self->{'ssh_path'},
		'proc_args'	=> [
				'-L',
			"$ssh_port:$remote_interface:$remote_port",
				$remote_host,
				qw( while true ; do sleep 3600 ; done ),
		],
		'no_io'	=> 1,
		'no_clone'	=> 1,
#			'use_pty'	=> 1,
	) ;

	return $proc unless ref $proc ;

	$self->{'proc'} = $proc ;

	$ssh_procs{ $proc } = $proc ;

	sleep 3 ;
}

END {

	foreach my $proc ( values %ssh_procs ) {

		TraceStatus "killing ssh proc" ;

		$proc->shut_down() ;
	}
}



sub _ssh2 {

	my( $self ) = @_ ;

	require Stem::Proc ;

# old style ssh calling a tty2sock program which may be ressurected

#			qw( -q -e none mail),
#  "(cd /wrk/stem/src/stem ; ./run_stem ttysock tty_port=$self->{'port'})",


	my $proc = Stem::Proc->new(

		'path'		=> '/usr/local/bin/ssh',
		'proc_args'	=> [
				'-f',
				'-L',
				"sleep","1000",
		],
		'no_io'	=> 1,
		'no_clone'	=> 1,
#			'use_pty'	=> 1,
	) ;


	return $proc unless ref $proc ;

	$self->{'proc'} = $proc ;



#  		$self->{'write_fh'} = $proc->write_fh() ;
#  		$self->{'read_fh'} = $proc->read_fh() ;
#  		my $err = $self->_activate() ;

	return ;
}
