use strict;

use Config;
use Data::Dumper;
use File::Spec;
use Module::Build 0.11;

my $class = Module::Build->subclass( code => <<'EOCODE' );

use strict;

my @demo_scripts =
    qw( chat_demo
	chat2_demo
	inetd_demo
	tail_demo
      );

my @config_files =
    qw(	chat
        chat_client
	chat_server
	inetd
	archive
	monitor
	ttysock
      );

use File::Path;
use File::Spec;

sub ACTION_install
{
    my $self = shift;

    $self->SUPER::ACTION_install;

    $self->install_config_files;
    $self->install_demos;
    $self->install_ssfe;
}

sub install_config_files
{
    my $self = shift;

    my $conf_path = $self->{args}{conf_path};

    unless ( -d $conf_path )
    {
        mkpath( $conf_path, 1, 0755 );
    }

    foreach my $conf (@config_files)
    {
        my $out_file = File::Spec->catfile( $conf_path, "$conf.stem" );

        print "Installing config file: $out_file\n";

        my $in_file = File::Spec->catfile( File::Spec->curdir, 'conf', "$conf.stem" );
        my $conf_text = read_file($in_file);

        if ( $conf eq 'inetd' )
        {
            my $proc_serv = File::Spec->catfile( $self->{args}{bin_path}, 'proc_serv' );

            $conf_text =~
                s[path\s+=>\s+'bin/proc_serv',]
                 [path\t\t=> '$proc_serv',];
        }
        elsif ( $conf eq 'monitor' || $conf eq 'archive' )
        {
            $conf_text =~
                s[path'\s+=>\s+'tail]
                 [path'\t\t=> '$self->{args}{tail_dir}]g ;
        }

        my $err = write_file( $out_file, $conf_text );

        die "\n$err\n" if $err;
    }
}

sub install_demos
{
    my $self = shift;

    return unless $self->{args}{install_stem_demos};

    foreach my $demo (@demo_scripts)
    {
        my $out_file = File::Spec->catfile( $self->{args}{bin_path}, $demo );

        print "Installing demo script: $out_file\n";

        my $in_file = File::Spec->catfile( File::Spec->curdir, 'bin', $demo );
        my $demo_text = read_file($in_file);

        $demo_text =~ s{/usr/local/bin/perl}[$self->{args}{'perl_path'}];

        $demo_text =~ s{xterm}[$self->{args}{xterm_path}]g;

        if ( $demo eq 'tail_demo' )
        {
            $demo_text =~ s['tail']['$self->{args}{tail_dir}'];
        }

        my $err = write_file( $out_file, $demo_text );

        die "$err\n" if $err ;

        chmod 0755, $out_file;
    }
}

sub install_ssfe
{
    my $self = shift;

    return unless $self->{args}{install_ssfe};

    print <<'EOF';

Installing ssfe. This is not a Stem install script and it will ask its
own questions. It will execute in its own xterm (whatever was
configured earlier) to keep this install's output clean. The xterm is
kept open with a long sleep call and can be exited by typing ^C.

EOF

    # ugly
    system <<'EOF';
xterm -e /bin/sh -c 'chdir extras ;
tar zxvf sirc-2.211.tar.gz ;
chdir sirc-2.211 ;
./install ;
sleep 1000 ;'
EOF

    print "\nInstallation of ssfe is done\n\n";
}

sub read_file
{

    my $file_name = shift;

    my $buf;

    local *FH;

    open FH, $file_name || die "Can't open $file_name $!";

    return <FH> if wantarray;

    read FH, $buf, -s FH;
    return $buf;
}


sub write_file
{
    my $file_name = shift;

    local *FH;

    open FH, ">$file_name" || return "Can't create $file_name $!";

    print FH @_;

    return;
}

EOCODE

eval { require Stem::InstallConfig };

my $is_win32 = $^O =~ /Win32/;

my $default_conf_path = $is_win32 ? undef : '/etc/stem';
my $default_tail_dir = File::Spec->catfile( File::Spec->tmpdir, 'stem-tail' );

my %conf = ( bin_path  => $Config{bin},
             perl_path => $Config{perlpath},
             conf_path => $default_conf_path,
             install_stem_demos => 1,
             tail_dir  => $default_tail_dir,
             install_ssfe => ( $is_win32 ? 0 : 1 ),
             %Stem::InstallConfig::Config,
           );

get_path_conf();
get_demo_conf();

write_install_config_pm();

my $version_from = File::Spec->catfile( File::Spec->curdir, 'lib', 'Stem.pm' );

my $build = $class->new( module_name => 'Stem',
                         dist_version_from => $version_from,
                         prereq => { Event => 0.77,
                                     IO    => 1.20,
                                   },
                         args => \%conf,
                         dynamic_config => 1,
                       );

$build->create_build_script;

exit;

sub get_path_conf
{
    print <<'EOF';

Welcome to the Stem installation script.

This script will ask you various questions in order to properly
configure and install Stem on your system.  Whenever a question is
asked, the default answer will be shown inside [brackets].  Pressing
enter will accept the default answer. If a choice needs to be made
from a list of values, that list will be inside (parentheses).

EOF

    my $query = <<'EOF';

Stem has several executable Perl programs and demonstration scripts
and they need to have the correct path to your perl binary.

What is the path to perl? []
EOF

    $conf{perl_path} = query_value( $query, $conf{perl_path} );

    $query = <<'EOF';

Those Stem executables need to be installed in a directory that is in your
shell $PATH.

What directory will have the Stem executables? []
EOF

    $conf{bin_path} = query_value( $query, $conf{bin_path} );

    $query = <<'EOF';

Stem configuration files are used to create and initialize Stem Cells
(objects). Stem needs to know the list of directories to search to
find its configurations files.

Note that the default has a single absolute path. You can test Stem
configurations easily setting this path when running Stem. You can
override or modify the path time with either a shell environment
variable or on the command line of run_stem. See the documentation on
run_stem for how so do this.

Enter a list of directories separated by ':'.

What directories do you want to search for Stem configuration files? []
EOF

    $conf{conf_path} = query_value( $query, $conf{conf_path} ) ;
}

sub get_demo_conf
{
    # all the demos need xterm
    return if $is_win32;

    my $query = <<'EOF';

Stem comes with several demonstration scripts.
Do you want to install them?
EOF

    $conf{install_stem_demos} = query_boolean( $query, $conf{install_stem_demos} );
    return unless $conf{install_stem_demos};

    get_xterm_path();
    return unless -x $conf{xterm_path};

    $query = <<'EOF';

The tail demo script needs a temporary working directory.  Enter the
path to a directory to use for this purpose.  If it does not exist,
this directory will be created.  []
EOF

    $conf{tail_dir} = query_value( $query, $conf{tail_dir} );

    # don't even bother
    return if $is_win32;

    $query = <<'EOF';

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
EOF

    $conf{install_ssfe} = query_boolean( $query, $conf{install_ssfe} );
}

sub get_xterm_path
{
    my $xterm;
    my $xterm_text;

    if ( $xterm = which( 'xterm' ) )
    {
        $xterm_text = "xterm was found at '$xterm'";
    }
    else
    {
        foreach my $path ( qw( /usr/openwin/bin/xterm
                               /usr/bin/X11/xterm
                               /usr/X11R6/bin/xterm
                             ) )
        {
            next unless -x $path;

            $xterm = $path;
            $xterm_text = "xterm was found at '$xterm'";

            last;
        }
    }

    $xterm_text ||= <<'EOF';

xterm was not found on this system. you can't run the demo programs
without xterm.  Make sure you enter a valid path to xterm or some other
terminal emulator.
EOF

    my $query = <<"EOF";
$xterm_text
Enter the path to xterm (or another terminal emulator)? []
EOF

    $xterm = query_value( $query, $xterm );

    if ( -x $xterm )
    {
        $conf{xterm_path} = $xterm;
        return;
    }
}

sub write_install_config_pm
{
    my $self = shift;

    my $config = Data::Dumper->Dump( [\%conf], ['foo'] );
    $config =~ s/\$foo = //;
    $config =~ s/\s*;$//;
    $config =~ s/{/(/;
    $config =~ s/}$/)/;

    local *FH;

    my $pm_file =
        File::Spec->catfile( File::Spec->curdir, 'lib', 'Stem', 'InstallConfig.pm' );

    open FH, ">$pm_file" or die "Cannot write to $pm_file $!";

    print FH <<"EOF";

package Stem::InstallConfig;

\%Stem::InstallConfig::Config =
    $config;

1;

EOF

    close FH;
}

sub which
{
    my ($bin) = @_;

    my $pathdir;

    foreach $pathdir ( split /[:;]/, $ENV{PATH} )
    {
        my $file = File::Spec->catfile( $pathdir, $bin );
        return $file if -x $file;
    }

    return;
}

sub query_value
{
    my ($question, $default) = @_;

    $default = '' unless defined $default;

    chomp $question;
    $question =~ s/\[.*\]/\n\t[$default] > /;

    print $question;

    my $answer = <STDIN>;

    die "\nEOF - exiting\n" unless defined $answer;

    return $default if $answer =~ /^$/;

    chomp $answer;

    return $answer;
}

sub query_boolean
{
    my ($question, $default) = @_;

    $default = 1 unless defined $default;

    chomp $question;

    $question .= $default ? ' [y] (y/n) > ' : ' [n] (y/n) > ';

    while (1)
    {
        print $question;

        chomp( my $answer = <STDIN> );

        die 'EOF' unless defined $answer;

        return $default if $answer =~ /^$/;

        return 1 if $answer =~ /^y/i;
        return 0 if $answer =~ /^n/i;

        print "Sorry, '$answer' is not a valid choice.\n";
    }
}
