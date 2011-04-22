# TODO: reconfigure PipelineStage detail below
#	Create the subroutines for this class in the constructor. Eliminate the need to pass around a big $self hash
#	will only need to pass around a hash containing the function references to use

package PipelineStage;

# import CPAN modules
use threads;
use threads::shared;
use Class::Struct;

# define the names of the object members
use constant
{
	PROCESSING_FUNCTION,
	INPUT_BUFFER,
	OUTPUT_BUFFER,
	STATUS_ARRAY,
	WORKER_THREADS,
	NUM_ACTIVE_WORKERS,
	WORKER_THREAD_RESULTS,
	JOB_COUNT_ARRAY,
	THROUGHPUT_SAMPLE_RATE,
	THROUGHPUT_SAMPLE_HISTORY_SIZE,
	TOTAL_WORKER_THREADS_CREATED,
	TOTAL_WORKER_THREADS_DESTROYED
};

# define the status states
use constant 
{
	ON,
	OFF
};

# define the struct workers use to store stats
struct(WORKER_THREAD_STATS => {
	jobsProcessed => '$',
	lifespan => '$'
});

sub new
{
	my ($class, $processingFunction, $inputBuffer, $outputBuffer, $throughputSampleRate, $throughputSampleHistorySize) = @_;
	
	my $self = {};
	my $self->{PROCESSING_FUNCTION} = $processingFunction;
	my $self->{INPUT_BUFFER} = $inputBuffer;
	my $self->{OUTPUT_BUFFER} = $outputBuffer;
	my $self->{NUM_ACTIVE_WORKERS} = 0;
	my $self->{WORKER_THREAD_RESULTS} = [];
	my $self->{JOB_COUNT_ARRAY} = [];
	my $self->{TOTAL_WORKER_THREADS_CREATED} = 0;
	my $self->{TOTAL_WORKER_THREADS_DESTROYED} = 0;
	
	bless $self, $class;
	
	# share this object and return it
	return $self;
}

sub addWorkers
{
	my ($self, $numToAdd) = @_;
	my $numActive = $self->{NUM_ACTIVE_WORKERS};
	my $statusArray = $self->{STATUS_ARRAY};
	my $functions = $self->{PROCESSING_FUNCTIONS};
	my $inputBuffer = $self->{INPUT_BUFFER};
	my $outputBuffer = $self->{OUTPUT_BUFFER};
	my $workerThreads = $self->{WORKER_THREADS};
	my $function = $self->{PROCESSING_FUNCTION};
	my $jobCountingArray = $self->{JOB_COUNT_ARRAY};
	for my $index ($numActive...($numActive + $numToAdd))
	{
		# modify the current index status to ON
		$statusArray->[$index] = ON;
		# create this new thread's execution function
		my $newWorkerExecutionFunction = 
			sub
			{
				while ($statusArray->[$index])
				{
					my $currentJob = $inputBuffer->getJob();
					# if the job isn't undefined, process it
					if ($currentJob)
					{
						$outputBuffer->addJobs($function->($inputBuffer->getJob()));	
						$jobCountingArray->[$index]++;	
					}
						
					# chill for a bit
					threads::yield();
				}
			};
		# create the actual thread
		$workerThreads->[$index] = threads->create($newWorkerExecutionFunction);
	}
	
	# update the number of active threads
	$self->{NUM_ACTIVE_WORKERS} += $numToAdd;
}

sub removeWorkers
{
	my ($self, $numToRemove) = @_;
	# TODO: implement PipelineStage::removeWorkers
	my $resultsCollection = $self->{WORKER_THREAD_RESULTS};
	my $jobCounter = $self->{JOB_COUNT_ARRAY};
	my $workerThreads = $self->{WORKER_THREADS};
	my $statusArray = $self->{STATUS_ARRAY};
	my @newlyCollectedResults = ();
	for my $index (0...$numToRemove)
	{
		# set the status bit for this worker to OFF
		$statusArray->[$index] = OFF;
		# now its results can be collected
		
		
		my $currentResultsStruct = new WORKER_THREAD_STATS;
		$currentResultsStruct->jobsProcessed(shift $jobCounter);
		$currentResultsStruct->lifespan($workerToRemove->join());
		$newlyCollectedResults[$index] = $currentResultsStruct;
	}
	
	push (@{$resultsCollection}, @newlyCollectedResults);
	
	
}

sub getNumWorkers
{
	my $self = shift;
	# TODO: implement PipelineStage::getNumWorkers
}

sub getAverageThroughput
{
	my $self = shift;
	# TODO: implement PipelineStage::getAverageThroughput
}

sub getThroughput
{
	my $self = shift;
	# TODO: implement PipelineStage::getThroughput
}

sub start
{
	my $self = shift;
	# TODO: implement PipelineStage::start
}

sub stop
{
	my $self = shift;
	# TODO: implement PipelineStage::stop
}

1;