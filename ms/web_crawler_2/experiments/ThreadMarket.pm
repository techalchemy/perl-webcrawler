

package ThreadMarket;

use threads;
use threads::shared;

use constant
{
	EMPLOYED,
	UNEMPLOYED
};

sub new
{
	my ($class,
		$employers,
		$prices,
		$numLaborers) = @_;
	
	# need to do following
	#	create the labor force and properly set up their execution
}

sub _work
{
	my ($employers, $prices, $status) = @_;
	
	my $currentJob = getBestPrice($prices);
	while ($status == UNEMPLOYED)
	{
		# do whatever your current job dictates
		$employers->[$currentJob]->();
		
		my $newBest = getBestPrices($prices);
		if ($newBest != $currentJob)
		{
			$currentJob = $newBest;
		}
		
		yield();
	}
}

1;