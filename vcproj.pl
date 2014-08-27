#Imago <imagotrigger@gmail.com>
# Defines 1.0 keys in the solution

use strict;
use File::Copy;
use Data::Dumper;

my @projs = glob "C:\\build\\FAZR6\\VS2008\\*.vcproj";
foreach my $proj (@projs) {
	open(VCX,$proj);
	my @lines = <VCX>;
	close VCX;
	move("$proj","$proj-prev");
	open(VCX,">$proj");

	my $bfound = 0;
	my $bfound2 = 0;
	foreach my $line (@lines) {
		my $name = $proj;
		$name =~ s/C:\\build\\FAZR6\\VS2008\\//i;
		if ($line =~ s/PreprocessorDefinitions\=\"/PreprocessorDefinitions\=\"_ALLEGIANCE_PROD_\;/i) {
			print "$name Updated to define _ALLEGIANCE_PROD_\n";
		}
		
		print VCX $line;
	}
}
	close VCX;
exit 0;