#Imago <imagotrigger@gmail.com>
# Updates the Artwork archive from SVN and Production AU

use strict;
use POSIX;

my $updated = 0;

opendir(DIR, "C:\\build\\Artwork");
my @svnart = readdir(DIR); 
closedir DIR;

foreach my $file (@svnart) {
	next if ($file =~ /^\./);
	my $cmd = "copy C:\\build\\Artwork\\$file C:\\build\\Package\\Artwork /Y";
	if (-e "C:\\build\\Package\\Artwork\\$file") {
		my $modtime = (stat("C:\\build\\Package\\Artwork\\$file"))[9];
		my $thetime = (stat("C:\\build\\Artwork\\$file"))[9];
		if($thetime > $modtime) {
			print "Updating $file\n";
			system($cmd);
			$updated = 1;
		}
	} else {
		print "Adding $file\n";
		system($cmd);
		$updated = 1;
		
	}
}

sub Date2Timestamp {
    my @words = split (/\s+|\/|:/, shift);
    my $month = $words[1] - 1;
    my $hour = $words[3];
    my $min  = $words[4];
    my $sec  = $words[5];
    my $year = $words[0] - 1900;
    return mktime($sec, $min, $hour, $words[2], $month, $year, 0, 0, -1) or die $!;
}

exit 0;

__END__


my $url = "http://www.allegiancezone.com/autoupdate/";
my $cmd = "lwp-download ".$url."filelist.txt C:\\build\\_ilelist.txt";
system($cmd);
$cmd = "expand C:\\build\\_ilelist.txt C:\\build\\filelist.txt";
system($cmd);
open(LIST,"C:\\build\\filelist.txt");
my @lines = <LIST>;
close LIST;
foreach my $line (@lines) {
	my ($date,$time,$size,$crc,$file) = split(/\s/,$line);
	$cmd = "lwp-download $url".$file." C:\\build\\Package\\tmp\\$file";
	my $cmd2 = "expand C:\\build\\Package\\tmp\\$file C:\\build\\Package\\Artwork\\$file";
	if (-e "C:\\build\\Package\\Artwork\\$file") {
		my $modtime = (stat("C:\\build\\Package\\Artwork\\$file"))[9] + 3600;
		my $thetime = Date2Timestamp($date.' '.$time);
		if($thetime > $modtime) {
			my $delta = $thetime - $modtime;
			print "Updating $file\n";
			system($cmd);
			system($cmd2);
			$updated = 1;
		}
	} else {
		print "Adding $file\n";
		system($cmd);
		system($cmd2);
		$updated = 1;
	}

}


my $cmd = "\"C:\\Program Files\\7-Zip\\7z.exe\" a -t7z C:\\build\\Package\\Artwork.7z C:\\build\\Package\\* -x!*.* -xr!tmp -mx9";
system($cmd) if ($updated);

my $cmd = "copy C:\\build\\Package\\Artwork\\* C:\\build\\Allegiance\\objs10\\FZDebug\\FedSrv\\Artwork\\ /Y";
system($cmd) if ($updated);



exit 0;


