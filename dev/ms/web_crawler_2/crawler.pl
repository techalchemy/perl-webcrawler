use Pipeline;

print "starting crawler.pl..\n";
main();
print "finishing running crawler.pl...\n";

sub main
{
	my $configuration = loadConfigFile($ARGV[0]);
	my $functionsToExecuteArrayReference = getFunctionsToExecute();
	my $crawlPipeline = Pipeline->new($functionsToExecuteArrayReference);
	my $seeds = getSeeds();
	my $crawlResults = $crawlPipeline->run($seeds);
}

sub getFunctionsToExecute
{
	#in here decide what functions are to be executed for the crawl
	# TODO: add code that will take an existing subroutine and use the functions it calls
	# to automatically generate a pipeline for the parallelized version of the code
	
}

sub loadConfigFile
{
	
}

sub getSeeds
{
	
}