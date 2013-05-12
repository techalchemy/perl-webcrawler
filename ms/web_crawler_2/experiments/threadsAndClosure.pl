use threads;
use threads::shared;

use constant NUM_WORKER_THREADS => 2;

use constant
{
	ON,
	OFF
};

main();

sub main
{
	my $statusArray = &share([]);
	my $outputArray = &share([]);
	my $threadArray = [];
		
	for my $index (0..NUM_WORKER_THREADS-1)
	{
		$statusArray->[$index] = ON;
		$threadArray->[$index] = threads->create(
									sub
									{
										while ($statusArray->[$index] == ON)
										{
											$outputArray->[$index]++;
											threads::yield();
										}
									
									});
	}
	sleep 4;
	$statusArray->[0] = OFF;
	$threadArray->[0]->join();
	sleep 4;
	$statusArray->[1] = OFF;
	$threadArray->[1]->join();
	
	print '[' . join(',', @$outputArray) . "]\n";
}