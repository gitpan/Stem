#!/usr/local/bin/perl -w

package Stem::Load::Echo ;

use strict ;

use LWP::Simple ;

use Getopt::Std ;
use YAML ;

use Stem::Packet ;

#my %opts ;

#getopts('v', \%opts );

#my $verbose = $opts{'v'} ;

$|++ ;

my $buffer = join( '', map chr, 0 .. 255 ) x 1 ;

my $size = 8000 ;

my $packet = Stem::Packet->new() ;

while( 1 ) {

	my $buffer ;

	my $read_cnt = sysread( \*STDIN, $buffer, 8192 ) ;

	last unless $read_cnt ;

	my $obj = $packet->to_data( $buffer ) ;

	next unless $obj ;

	$obj->echo() ;

	syswrite( \*STDOUT, ${ $packet->to_packet( $obj ) } ) ;
}

exit ;



sub echo {

	my( $self ) = @_ ;

#	my $url = <DATA> ;
#	chomp $url ;

	my $url = $self->{'url'} ;

	$self->{'echo'} = get $url ;

	$size++ ;
}


__DATA__
http://www.cnn.com/SPECIALS/index.9695.html#1995
http://www.usatoday.com/life/cyber/tech/review/games/cgg264.htm
http://www.csmonitor.com/linkslibrary/
http://www.usatoday.com/marketing/legal.htm
http://www.csmonitor.com/linkslibrary/
http://news.com.com/2001-1033-0.html?legacy=cnet#
http://www.cnn.com/2002/WORLD/asiapcf/central/07/15/pentagon.wedding.attack/index.html
http://www.usatoday.com/life/lfront.htm
http://www.usatoday.com/life/cyber/tech/net033.htm
http://www.investors.com/learn/fundsarch11.asp?v=7/15
http://www.cnn.com/interactive/space/0107/space.agency.news/content.html
http://www.usatoday.com/sports/sfront.htm
http://www.cnn.com/2002/HEALTH/07/11/pul.AIDS/index.html
http://www.cnn.com/2001/CAREER/trends/08/05/multitasking.study/index.html
http://www.csmonitor.com/cgi-bin/redirect.pl?csArticle
http://news.com.com/2100-1017-943062.html?tag=cd_mh
http://www.usatoday.com/life/cyber/tech/ctcourt.htm
http://news.com.com/2009-1001-831836.html
http://news.com.com/2016-1071-0.html?tag=fd_nc_pr
http://news.com.com/2016-1071-0.html?tag=fd_nc_pr
http://news.com.com/2016-1071-0.html?tag=fd_nc_pr
http://news.com.com/2016-1071-0.html?tag=fd_nc_pr
http://news.com.com/2018-1070-0.html?tag=fd_nc_sr
http://news.com.com/2016-1071-0.html?tag=fd_nc_pr
http://www.cnn.com/TRAVEL/resources/
http://news.com.com/2018-1070-0.html?tag=fd_nc_sr
http://news.com.com/2018-1070-0.html?tag=fd_nc_sr
http://www.cnn.com/money/2001/12/27/economy/wires/jobcuts_ap/
http://news.com.com/2016-1071-0.html?tag=fd_nc_pr
http://news.com.com/2100-1001-943375.html?tag=cd_mh
http://www.investors.com/learn/ICwinning09.asp
http://www.cnn.com/SPECIALS/index.9695.html#1996
http://www.cnn.com/2002/TECH/internet/07/12/net.birdzilla/index.html
http://www.usatoday.com/life/cyber/bonus/qa/ans032.htm
http://news.com.com/2100-1023-944051.html
http://www.usatoday.com/life/cyber/tech/2001/12/18/ebrief.htm
http://www.cnn.com/2002/US/07/15/wisc.derail.ap/index.html
http://www.usatoday.com/life/cyber/tech/2001-06-15-week.htm
http://www.usatoday.com/weather/wfront.htm
http://www.cnn.com/2002/LAW/07/15/bush.plea.deal/index.html
http://www.cnn.com/CNN/Programs/wolf.blitzer.reports/index.html
http://www.usatoday.com/life/cyber/tech/review/games/2001-01-25-violence.htm
http://www.usatoday.com/news/healthscience/science/cold-science/2001-12-28-penguins.htm
http://news.com.com/2100-1040-942986.html?tag=cd_mh
http://www.usatoday.com/sports/baseball/comment/antonen/index.htm
http://www.usatoday.com/small/strategies/2002/01-18-contractors.htm
http://www.usatoday.com/shop/shop_front.htm
http://www.cnn.com/2002/WORLD/asiapcf/south/07/15/pakistan.pearl.verdict/index.html
http://www.usatoday.com/sports/sfront.htm
http://news.com.com/2100-1023-943220.html?tag=cd_mh
http://www.usatoday.com/life/cyber/invest/investor.htm
http://www.cnn.com/2002/HEALTH/07/14/suicide.teens.reut/index.html
http://www.csmonitor.com/cgi-bin/redirect.pl?csArticle
http://www.csmonitor.com/cgi-bin/redirect.pl?csArticle
http://www.csmonitor.com/cgi-bin/redirect.pl?csArticle
http://www.usatoday.com/life/cyber/tech/ct177.htm
http://www.investors.com/quotes/default.asp?t=DUK
http://www.csmonitor.com/cgi-bin/redirect.pl?csArticle
http://www.cnn.com/2002/TECH/space/07/10/universe.age/index.html
http://www.usatoday.com/life/cyber/tech/net034.htm
http://www.csmonitor.com/cgi-bin/redirect.pl?csArticle
http://www.investors.com/learn/fundsarch09.asp?v=7/15
http://www.cnn.com/SPECIALS/2002/summertrips/
http://news.com.com/2100-1033-943339.html?tag=cd_mh
http://www.cnn.com/2002/TECH/industry/07/15/ibm.storage.reut/index.html
http://news.com.com/2009-1001-943513.html
http://news.com.com/2009-1001-943513.html
http://news.com.com/2009-1001-943513.html
http://www.csmonitor.com/cgi-bin/redirect.pl?csArticle
http://news.com.com/2009-1001-845281.html
http://news.com.com/2018-1070-0.html?tag=fd_nc_sr
http://news.com.com/2018-1070-0.html?tag=fd_nc_sr
http://news.com.com/2018-1070-0.html?tag=fd_nc_sr
http://news.com.com/2018-1070-0.html?tag=fd_nc_sr
http://www.cnn.com/SPECIALS/index.1997.html
http://news.com.com/2018-1070-0.html?tag=fd_nc_sr
http://news.com.com/2100-1017-943136.html?tag=cd_mh
http://news.com.com/2018-1070-0.html?tag=fd_nc_sr
http://www.usatoday.com/money/mfront.htm
http://news.com.com/2100-1001-943412.html?tag=cd_mh
http://www.csmonitor.com/aboutus/advertising.html
http://www.usatoday.com/life/cyber/cyber1.htm
http://www.investors.com/learn/ICwinning08.asp
http://www.cnn.com/2000/CAREER/jobenvy/12/08/aura/index.html
http://www.usatoday.com/life/cyber/tech/2001/12/20/ebrief.htm
http://www.usatoday.com/small/strategies/2002/01-25-olympics.htm
http://www.usatoday.com/life/cyber/tech/2001-06-22-week.htm
http://www.usatoday.com/life/cyber/tech/review/games/2001-03-23-violence.htm
http://www.usatoday.com/news/healthscience/science/cold-science/2002-01-16-glacier-robot.htm
http://www.cnn.com/2002/WORLD/asiapcf/south/07/15/mintier.otsc/index.html
http://www.cnn.com/2002/WORLD/asiapcf/central/07/15/pentagon.wedding.attack/index.html
http://www.usatoday.com/life/cyber/bonus/qa/ans035.htm
http://www.cnn.com/2002/LAW/07/15/lindh.prison/index.html
http://news.com.com/2100-1040-943059.html?tag=cd_mh
http://news.com.com/2100-1001-944053.html
http://www.cnn.com/2002/HEALTH/parenting/07/15/sesame.street.hiv.reut/index.html
http://www.usatoday.com/sports/hockey/columns/allen/index.htm
http://www.usatoday.com/life/cyber/tech/ct204.htm
http://www.cnn.com/2002/WORLD/asiapcf/south/07/16/india.pakistan.kashmir/index.html
http://www.cnn.com/2002/TECH/space/07/08/station.crystals/index.html

