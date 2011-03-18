#
#	This script should be run with a fresh install of perl and will recursively install the dependencies used by this project
#		Currently requires root permission for cpan installs
#		TODO: make cpan not ask stupid fucking questions about dependencies
#
#
#		Arguments:
#			filename - name of the file to install dependencies for (webCrawler.pl for example)
#
#
print "Starting configure.pl...\n";
BEGIN { system('cpan -i Module::ExtractUse');};

use Module::ExtractUse;


installDependencies($ARGV[0]);

print "Finished running configure.pl\n";


sub installDependencies
{
	my $fileToCheck = $_[0];
	my $p = Module::ExtractUse->new;
	
	$p->extract_use($fileToCheck);
	
	my @usedModules = $p->array;
	foreach(@usedModules)
	{
		
		#check if the current dependency is a local module, if it is we need to grab its dependencies
		my $speculativeModulePath = join("\/", split(/::/)) . ".pm";
		if (-e $speculativeModulePath)
		{
			#if here, means we got a local module. we should grab this module's dependencies as well
			installDependencies($speculativeModulePath);
		}
		else
		{
			system('cpan -y -i ' . $_);
		}
	}
}