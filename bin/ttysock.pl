#!/usr/local/bin/perl

use IO::Socket ;
use IO::Select ;

my $sock = IO::Socket::INET->new( .... ) ;

$s = IO::Select->new();

$s->add(\*STDIN);
$s->add($sock);


while(@ready = $sel->can_read) {
   foreach $fh (@ready) {
	  if($fh == $sock) {

		$size = sysread( $sock, $buf, 1024 ) ;
		syswrite( STDOUT, $buf, $size ) ;
	}
	else {
		$size = sysread( STDIN, $buf, 1024 ) ;
		syswrite( $sock, $buf, $size ) ;
	}
   }
}
