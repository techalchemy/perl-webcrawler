# Hypothesis: shared variables, when used to dynamically generate a subroutine that is passed into a thread
# constructor, will behave the same way as they do without threading

# bring in the CPAN libraries
use threads;
use threads::shared;

# define the constants used in this script
use constant DEBUG_FILENAME => 'report.dbg';
use constant NUM_THREADS => 4;


# start executing
print "starting threadSafeLexicalClosure.pl...\n";
startExperiment();
print "finished running threadSafeLexicalClosure.pl...\n";

sub startExperiment
{
	# initialize debugging
	#initializeDebugging();
	
	my $valueArray :shared = &share([]);
	
	
	my $threads = createThreads($valueArray);
	
	# join all the threads
	for my $index (0..NUM_THREADS-1)
	{
		print "index: " . $index . "\n";
		$threads->[$index]->join();
	}
	
	# assert that each entry of the array is equal to 1
	print '[' . join(',', @$valueArray) . "]\n";
}

sub createThreads
{
	my $targetArray = shift;
	
	if (is_shared($targetArray))
	{
		print "createThreads param is shared\n";
	}
	else
	{
		print "createThreads param is not shared\n";
	}
	
	my $threadArray = [];
	for my $index (0..NUM_THREADS-1)
	{
		my $threadSub =
			sub
			{
				$targetArray->[$index]++;
			};
		$threadArray->[$index] = threads->create($threadSub);
	}
	return $threadArray;
}

#sub initializeDebugging
#{
#	Util::setGlobalDebug(1);
#	unlink(DEBUG_FILENAME);
#	Util::setGlobalDebugFile(DEBUG_FILENAME);
#	
#	Util::setThreadRecord(0);
#	Util::debugPrint('debugging initialized, starting experiment');
#}