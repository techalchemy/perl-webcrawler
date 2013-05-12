my $initializedThreads;

BEGIN
{
	# do something to initialize threads early
}

use threads;
use threads::shared;
use Thread::Queue;

main();

use constant NUM_THREADS => 32;

use constant
{
	ON,
	OFF
}

sub main
{
	
	# load the seeds for the crawl
	my $seeds = loadSeeds();
	
	my $queues = &share([]);
	my $status = &share([]);
	my $directive = &share([]);
	for my $index (0..scalar(@$functions) - 1)
	{
		$queues->[$index] = Thread::Queue->new();
		$status->[$index] = ON;
		$directive[$index] = 
		
	}
	
}

sub worker_thread
{
	my ($directive, $queues, $status) = @_;
	
	# define functions
	my $functions = [
		\&buildRecords,
		\&getPage,
		\&parsePage,
		\&pruneLinks,
		\&postData,
		\&addPages
	];
	
	while ($status == ON)
	{
		$queues->[($directive + 1) % scalar(@$functions)]->enqueue($functions->[$directive]->($queues->[$directive]->dequeue));
	}
}

# return a non repeating random set of integers from 0 to $size - 1
sub getRandomOrderingOfIntegers
{
	my $size = shift;
	my $bag = [];
	my $used = [];
	for my $index ( 0..($size - 1) )
	{
		my $left = $size - $index;
		my $choice = int(rand($left));
		push (@bag, $filter->[$choice]);
		$filter = updateFilter($filter, $choice);
	}
	return $bag;
}

sub updateFilter
{
	my ($filterRef, $lastChosenIndex) = @_;
	my @oldFilter = @$filterRef;
	my @newFilter = (
						@oldFilter[0..($lastChosenIndex - 1)],
						map { $_++ } @oldFilter[($lastChosenIndex + 1)..$#oldFilter]
					);
	return @newFilter;
}

sub loadSeeds
{
	# TODO: implement crawler::loadSeeds
}

sub buildRecords
{
	# TODO: implement crawler::buildRecords
}

sub getPage
{
	# TODO: implement crawler::getPage
}

sub parsePage
{
	# TODO: implement crawler::parsePage
}

sub pruneLinks
{
	# TODO: implement crawler::pruneLinks
}

sub postData
{
	# TODO: implement crawler::postData
}

sub addPages
{
	# TODO: implement crawler::addPages
}