#Imago <imagotrigger@gmail.com>
# Creates client and server filelists
#  Archives the list and targets for deploy.pl

use strict;
use Net::FTP;
use POSIX qw(strftime);
use File::Copy;

print "Packaging deployment\n";

open(LIST,">C:\\build\\betalist.txt");

opendir(DIR, "C:\\build\\Package\\Artwork\\");
my @art = readdir(DIR); 
closedir DIR;

my $offset = strftime("%z", localtime());
if ($offset =~ /Daylight/i) {
	$offset = 5;
} else {
	$offset = 6;
}

foreach my $file (@art) {
	next if ($file =~ /^\./);
	next if ($file !~ /cc_09|tcor_/i);
	my $cmd = "C:\\build\\crc32.exe C:\\build\\Package\\Artwork\\$file";
	my $cmd2 = "C:\\build\\mscompress.exe C:\\build\\Package\\Artwork\\$file";
	my ($modtime,$size)= (stat("C:\\build\\Package\\Artwork\\$file"))[9,7];
	next if (!$size);
	my $crc = `$cmd`;
	chomp $crc;
	$size = sprintf("%09d",$size);
	my $dt = strftime("%Y/%m/%d %H:%M:%S",localtime($modtime + (3600 * $offset)));
	my $crc2 = "0" x ( 8 - length($crc) ) . $crc; 
	print LIST "$dt $size $crc2 $file\n";
	`$cmd2`;
	move("C:\\build\\Package\\Artwork\\${file}_","C:\\build\\AutoUpdate\\Game\\$file");
}


my @objs = ("C:\\Allegiance.exe","C:\\build\\External\\Reloader.exe");

foreach my $file (@objs) {
	my $cmd = "C:\\build\\crc32.exe $file";
	my $cmd2 = "C:\\build\\mscompress.exe $file";
	my ($modtime,$size)= (stat("$file"))[9,7];
	next if (!$size);
	my $crc = `$cmd`;
	chomp $crc;
	$size = sprintf("%09d",$size);
	my $dt = strftime("%Y/%m/%d %H:%M:%S",localtime($modtime + (3600 * $offset)));
	my $crc2 = "0" x ( 8 - length($crc) ) . $crc; 
	my $bin = "Gurgle.crap";
	if ($file =~ /.*\\([^\\]+$)/) {
		$bin = $1;
	}	
	print LIST "$dt $size $crc2 $bin\n";
	`$cmd2`;
	move("${file}_","C:\\build\\AutoUpdate\\Game\\$bin");
}

close LIST;


my $cmd3 = "\"C:\\Program Files\\7-Zip\\7z.exe\" a -t7z C:\\build\\AutoUpdate\\Game.7z C:\\build\\AutoUpdate\\Game\\* -xr!*Server -mx9";
system($cmd3);

open(LIST,">C:\\build\\serverlist.txt");
my @objs = ("C:\\AllSrv.exe","C:\\AGC.dll", "C:\\AllSrvUI.exe");
foreach my $file (@objs) {
	my $cmd = "C:\\build\\crc32.exe $file";
	my $cmd2 = "C:\\build\\mscompress.exe $file";
	my ($modtime,$size)= (stat("$file"))[9,7];
	next if (!$size);
	my $crc = `$cmd`;
	chomp $crc;
	$size = sprintf("%09d",$size);
	my $dt = strftime("%Y/%m/%d %H:%M:%S",localtime($modtime + (3600 * $offset)));
	my $crc2 = "0" x ( 8 - length($crc) ) . $crc; 
	my $bin = "Gurgle.crap";
	if ($file =~ /.*\\([^\\]+$)/) {
		$bin = $1;
	}	
	print LIST "$dt $size $crc2 $bin\n";
	`$cmd2`;
	move("${file}_","C:\\build\\AutoUpdate\\Game\\Server\\$bin");
}
close LIST;


my $cmd3 = "\"C:\\Program Files\\7-Zip\\7z.exe\" a -t7z C:\\build\\AutoUpdate\\Server.7z C:\\build\\AutoUpdate\\Game\\Server\\* -mx9";
system($cmd3);
exit 0;

