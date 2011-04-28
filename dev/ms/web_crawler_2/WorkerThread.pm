## @file WorkerThread.pm
# This class encapsulates a worker thread used as part of a thread pool based multithreading program. This class will execute a
# function passed to it once the method start has been called. The thread will be created and start executing after start has been
# called. The worker thread will then run until the task is completely finished or the shutdown method is called to make it
# exit early.

package WorkerThread;

use threads;
use threads::shared;

sub new
{
	my $class = shift;
	my $executionSubroutine = shift;
	# strategy with this method should be to create an execution subroutine and
	my $self = {};
	$self->{executionSubroutine} = $executionSubroutine;
	bless $self, $class;
	return $self;
}

## @cmethod results start()
# Called by some multithreading programming architecture to begin execution given initialization parameters
# executes some function until its finished, and then returns the results. This class is soooooo general, it
# has pretty much every aspect of its behavior encapsulated away and generated on the dataflow.
sub start
{
	my $self = $_[0];
	$self->{workerThread} = threads->create($self->{executionSubroutine});
}

sub finish
{
	my $self = $_[0];
	return $self->{workerThread}->join();
}

1;