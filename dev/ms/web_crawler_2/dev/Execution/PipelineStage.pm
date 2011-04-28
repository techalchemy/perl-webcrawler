# TODO: reconfigure PipelineStage detail below
#	Create the subroutines for this class in the constructor. Eliminate the need to pass around a big $self hash
#	will only need to pass around a hash containing the function references to use

package PipelineStage;

# import CPAN modules
use threads;
use threads::shared;
use Class::Struct;
use Time::HiRes;

# define the names of the object members
use constant
{
	ADD_WORKERS_SUB,
	REMOVE_WORKERS_SUB,
	GET_NUM_WORKERS_SUB,
	GET_THROUGHPUT_SUB,
	GET_PROCESSING_FUNCTION_SUB,
	START_SUB,
	STOP_SUB,
	COLLECTED_WORKER_STATS
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
	my ($class, 
		$processingFunction, 
		$inputBuffer, 
		$outputBuffer, 
		$throughputSampleRate, 
		$throughputSampleHistorySize,
		$initialNumberOfWorkers) = @_;
	
	my $self = &share({});
	
	my $statusArray :shared = &share([]);
	my $jobsCompletedCounter :shared = &share([]);
	my $workerThreads :shared = &share([]);
	my $numActiveWorkers :shared;
	my $currentThroughput :shared;
	my $monitorThreadSwitch :shared;
	my $deadThreadJobsProcessedCounter :shared;
	
	# initialize the killed threads' results collector
	$self->{COLLECTED_WORKER_STATS} = {};
	# create the add workers subroutine
	$self->{ADD_WORKERS_SUB} = _createAddWorkersSub(
									\$numActiveWorkers,
									$statusArray,
									$inputBuffer,
									$outputBuffer,
									$processingFunction,
									$jobsCompletedCounter,
									$workerThreads);
	
	# create the remove workers subroutine
	$self->{REMOVE_WORKERS_SUB} = _createRemoveWorkersSub(
									$statusArray,
									$workerThreads,
									\$numActiveWorkers,
									\$deadThreadJobsProcessedCounter);
									
	# create the get number of workers subroutine
	$self->{GET_NUM_WORKERS_SUB} = sub { return $numActiveWorkers; };
	
	# create the get throughput function
	$self->{GET_THROUGHPUT_SUB} = sub { return $currentThroughput; };
	
	# create the get processing function sub
	$self->{GET_PROCESSING_FUNCTION_SUB} = sub { return $processingFunction; };
	
	# create the start subroutine
	$self->{START_SUB} = 
		sub
		{
			my $self = shift;
			$monitorThreadSwitch = ON;
			my $monitorThread = _createStartMonitorThreadSub(
								\$monitorThreadSwitch,
								$jobsCompletedCounter,
								\$currentThroughput, 
								$throughputSampleRate,
								$throughputSampleHistorySize,
								$deadThreadJobsProcessedCounter)->();
			# now that the monitor is up and running, start the pipeline proper
			$self->{ADD_WORKERS_SUB}->($self, $initialNumberOfWorkers);
		};
	# create the stop subroutine
	$self->{STOP_SUB} =
		sub
		{
			my $self = shift;
			# stop the monitor thread,
			$monitorThreadSwitch = OFF;
			# remove all the workers
			$self->{REMOVE_WORKERS_SUB}->($self->{GET_NUM_WORKERS_SUB}->());
			# return the collected worker stats
			return $self->{COLLECTED_WORKER_STATS};
		};
	
	
	bless $self, $class;
	
	# share this object and return it
	return $self;
}

sub addWorkers
{
	my ($self, $howMany) = @_;
	$self->{ADD_WORKERS_SUB}->($self, $howMany);
}

sub removeWorkers
{
	my ($self, $howMany) = @_;
	$self->{REMOVE_WORKERS_SUB}->($self, $howMany);
}

sub getNumWorkers
{
	my $self = shift;
	return $self->{GET_NUM_WORKERS_SUB}->();
}

sub getThroughput
{
	my $self = shift;
	return $self->{GET_THROUGHPUT_SUB}->();
}

sub getProcessingFunction
{
	my $self = shift;
	return $self->{GET_PROCESSING_FUNCTION_SUB}->();
}

sub start
{
	my $self = shift;
	$self->{START_SUB}->($self);
}

sub stop
{
	my $self = shift;
	return $self->{STOP_SUB}->($self);
}

sub _createAddWorkersSub
{
	my ($activeThreadCountRef,
		$statusArray,
		$inputBuffer,
		$outputBuffer,
		$function,
		$jobCountingArray,
		$workerThreads) = @_;
	# deference the number of active threads reference
	my $numActive = $$activeThreadCountRef;
	# define and return the add worker subroutine
	return
		sub
		{
			my ($self, $numToAdd) = @_;
			for my $index ($numActive...($numActive + $numToAdd))
			{
				# set the current status of this element to ON
				$statusArray->[$index] = ON;
				# create the thread execution subroutine
				my $executionRoutine = _createWorkerExecutionSub(
						$index,
						$statusArray,
						$inputBuffer,
						$outputBuffer,
						$function,
						$jobCountingArray);
				# now create the thread and place reference to it in the thread array
				$workerThreads->[$index] = threads->create($executionRoutine);
			}
			# update the number of active threads
			$$activeThreadCountRef += $numToAdd;
		};
}

sub _createWorkerExecutionSub
{
	my ($index, $statusArray, $inputBuffer, $outputBuffer, $function, $jobCountingArray) = @_;
	
	return
		sub
		{
			my $startTime = time;
			while ($statusArray->[$index] == ON)
			{
				my $currentJob = $inputBuffer->getJob();
				if ($currentJob)
				{
					$outputBuffer->addJobs($function->($currentJob));
					$jobCountingArray->[$index]++;
				}
				
				threads::yield();
			}
			return (time - $startTime);
		};
}

sub _createRemoveWorkersSub
{
	my ($statusArray, 
		$workerThreads, 
		$activeThreadCountRef, 
		$jobCountingArray, 
		$jobsProcessedByDeadThreadsCounterRef) = @_;
	return
		sub
		{
			my ($self, $numToRemove) = @_;
			my $localResults = [];
			for my $index (0..$numToRemove-1)
			{
				# set the status bit of the first element to OFF
				$statusArray->[0] = OFF;
				# wind down the worker and add its stats to the localResults collection
				my $currentWorkerResults = new WORKER_THREAD_STATS;
				$currentWorkerResults->lifespan($workerThreads->[0]->join());
				my $jobsProcessed = shift @{$jobCountingArray};
				$currentWorkerResults->jobsProcessed($jobsProcessed);
				# add the jobs processed to the grand total
				$$jobsProcessedByDeadThreadsCounterRef += $jobsProcessed;
				$localResults->[$index] = $currentWorkerResults;
				# shift values off the status, and worker arrays
				shift @{$statusArray};
				shift @{$workerThreads};
				
			}
			# add this local collection of results to the total
			push (@{$self->{COLLECTED_WORKER_STATS}}, @$localResults);
			# update the number of active threads
			$$activeThreadCountRef -= $numToRemove;
		};
}

sub _createMonitorThreadStartSub
{
	my ($monitorStatusRef, 
		$currentThroughputRef, 
		$jobCounterArray, 
		$sampleRate, 
		$maxHistorySize,
		$deadThreadJobsProcessedCounterRef) = @_;
	
	return
		sub
		{
			return
				async
				{
					my $lastSampleTime = time;
					my $totalJobsInHistory = 0;
					my @history = ();
					my $jobTotalAtLastSample = 0;
					while ($$monitorStatusRef == ON)
					{
						my $currentTime = time;
						if ($currentTime - $lastSampleTime > $sampleRate)
						{
							my $jobsProcessedSinceLastSample =
									($$deadThreadJobsProcessedCounterRef + _computeArraySum($jobCounterArray)) - $jobTotalAtLastSample;
							my $currentHistorySize = scalar(@history);
							my $jobsLeavingHistory = 0;
							if (scalar(@history) == $maxHistorySize)
							{
								$jobsLeavingHistory = shift @history;
							}
							
							$totalJobsInHistory += ($jobsProcessedSinceLastSample - $jobsLeavingHistory);
							push (@history, $jobsProcessedSinceLastSample);
							
							$$currentThroughputRef = $totalJobsInHistory / scalar(@history);
						}
						yield();
					 }
				};
		};
}

sub _computeArraySum
{
	my $arrayReference = shift;
	my $sum = 0;
	foreach (@$arrayReference)
	{
		$sum += $_;
	}
	return $sum;
}

1;