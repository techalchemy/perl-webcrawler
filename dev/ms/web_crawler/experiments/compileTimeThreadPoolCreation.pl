

use threads;
use threads::shared;
use WorkerThread;

# create the max workers constant
use constant MAX_WORKERS => 128;

# create the constant for switching
use constant
{
	ON,
	OFF
};

my $workerPool :shared;
my @workerStatus :shared;
BEGIN
{
	# create all the worker threads at once with holding routines to wait for action
	for my $index (0...MAX_WORKERS-1)
	{
		@workerStatus[$index] = ON;
		my $newWorker = WorkerThread->new(
							sub
							{
								
							},
							sub
							{
								
							},
							sub
							{
								
							},
							sub
							{
								
							});
	}
}