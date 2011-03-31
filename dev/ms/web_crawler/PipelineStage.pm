## @file PipelineStage.pm
# This file is intended to encapsulate the functions needed to simulate a pipeline in the context of a multithreading
# program. The class defined within is a modified type of thread pool, it will use a collection of worker threads
# to process all the jobs passed to it. While in that sense this class is like a generic thread pool, it is different
# in the sense that it was designed to be used in conjuction with other instances in a pipeline. For this reason, it
# includes methods that will allow a program implementing a full pipeline to dynamically reallocate resources to
# best load balance and avoid bottlenecks. A conceptual explanation of the way this class works is described below.
# @par Model
# The class expects that it will be passed a incoming job collection and an outgoing job collection and a processing
# function. While this function can do anything the user wants, it does need to return output that will be passed
# to the next stage of the pipeline. The processing function can be thought of as a transform used to create outputs
# from inputs.


package PipelineStage;

# import CPAN modules
use threads;
use threads::shared;
use Thread::Queue;

# if a initial thread number isn't supplied, uses this
use constant DEFAULT_NUM_THREADS => 4;
# signal used to shut down threads
use constant TERMINATE => 0;


## @cmethod public PipelineStage new($processingFunction, $inputQueue, $outputQueue, $sharedData, $initialThreads)
# Default (and only) constructor for a pipeline stage object. This object is supposed to encapsulate
# a pipeline stage that owns a thread pool it uses to process jobs. The specified parameters allow
# the object this method creates to process jobs received from a previous stage of the pipeline
# and place its finished jobs in a queue for the next stage to process
# @param processingFunction this is a reference to the function actually used to transform input data into output data
# @param inputQueue this is a reference to a Thread::Queue object that it will receive jobs from
# @param outputQueue reference to Thread::Queue object that it will place finished jobs into
# @param sharedData reference to data that the threads will all use
# @return when this pipeline stage is shut down, it will return statistics about its run
sub new
{
	# this function needs to create the threads, and have some reference to them
	# so it can pause/shutdown/stop them when it needs to
	my ($class, $processingFunction, $inputQueue, $outputQueue, $sharedData, $initialThreads) = @_;
	my $self = {};
	# make sure the three mandatory operators are defined
	if ($processingFunction && $inputQueue && $outputQueue)
	{
		$self->{PROCESSING_FUNCTION} = $processingFunction;
		$self->{PENDING_JOBS} = $inputQueue;
		$self->{FINISHED_JOBS} = $outputQueue;
	}
	else
	{
		return undef;
	}
	$initialThreads = DEFAULT_NUM_THREADS unless $initialThreads;
	# initialize rest of objects fields
	$self->{NUM_THREADS} = 0;
	$self->{SHARED_DATA} = $sharedData;
	$self->{INITIAL_THREADS} = $initialThreads;

	#start the pipeline monitoring thread, it will collect results and do other administration
	
	bless $self, $class;
	return $self;
}

sub start
{
	my $self = shift;
	# add the initial workers
	my $initialThreadNumber = $self->{INITIAL_THREADS};
	addWorkers($self, $initialThreadNumber);
}

sub addWorkers
{
	my ($self, $howMany) = @_;
	my $threadPool = $self->{THREAD_POOL};
	for(1..$howMany)
	{
		my $newThread = threads->create(\_workerThread, $processingFunction, $inputQueue, $outputQueue);
		$threadPool->{$newThread->tid()} = $newThread;
	}
}

## @cmethod void removeWorkers($howMany)
# this function removes the number of threads specified. Returns immediately but the threads will actually be removed at a later time
# this thread places a job in the queue that when processed by a worker will cause it to clean up and finish, allowing it to be joined
# this pipeline stage 
sub removeWorkers
{
	my ($self, $howMany) = @_;
	my $inputQueue = $self->{PENDING_JOBS};
	my @terminalJobs;
	for(1..$howMany)
	{
		push(@terminalJobs, TERMINATE);
	}
	$inputQueue->enqueue(\@terminalJobs);
	# now join the terminated thread and get its results
}

sub shutdown
{
	my $self = shift;
	my $numThreads = $self->{NUM_THREADS};
	#terminate all the running workers
	removeWorkers($self, $numThreads);
	#collect the outputs
	my @workers = keys %{$self->{THREAD_POOL}};
	my @results = @{$self->{RESULTS}};
	while (@workers)
	{
		push(@results, $_->join());
	}
	return \@results;
}

sub getCurrentThroughput
{
	
}

sub _workerThread
{
	my ($processingFunction, $inputQueue, $outputQueue) = @_;
	
	#initialize statistics aggregators and whatever
	
	#start the main processing loop
	while (my $job = $inputQueue->dequeue())
	{
		if ($job eq TERMINATE)
		{
			last;
		}
		my $outputJobs = $processingFunction->($job);
		$outputQueue->enqueue($outputJobs);
	}
}

1;