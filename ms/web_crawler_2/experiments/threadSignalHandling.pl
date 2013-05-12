
use threads;
use threads::shared;
use Time::HiRes;

main();

use constant
{
	CONTINUE,
	STOP
};

sub main
{
	
	my $thr = threads->create(\&thr_func);
	
	
	sleep(5);
	
	my $counter_value = $thr->kill('KILL')->join();
	
	print "counter valued at: " . $counter_value . "\n";
}

sub thr_func
{
	
	my $counter = 0;
	
	my $statusChecker :shared = CONTINUE;
	
	$SIG{'KILL'} =
		sub
		{
			print "inside the kill signal handler sub\n";
			$statusChecker = STOP;
		};
	
	while ($statusChecker == CONTINUE)
	{
		$counter++;
	}
	
	return $counter;
}