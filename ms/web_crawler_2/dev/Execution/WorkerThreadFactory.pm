package WorkerThreadFactory;

use threads;
use threads::shared;

use WorkerThread;

use constant
{
	FALSE,
	TRUE
};

sub new
{
	my ($class, $maxWorkers) = @_;
	
	my $self = bless(&share({}), $class);
	
	# create all the necessary subroutines here and store refs to them in $self
	#	also, declare shared data here and use lexical closure to hold onto
	
	# array with a slot for each thread to send requests
	my $reassignmentRequestArray = &share([]);
	# contains the new assignments for workers
	my $reassignmentContentsArray = &share([]);
	# array to hold the IDs of available workers
	my $availableWorkersArray = &share([]);
	# when clients first request workers, save their functions in here
	my $functionPackageMap = &share([]);
	# stores which workers are registered to a given client
	my $clientWorkerRegistry = &share({});
	# stores references to the threads
	my $threadList = &share([]);
	# used to signal runtime status to the threads
	my $threadStatus = &share([]);
	
	# create all the threads and their associated subroutines
	_createThreads($maxWorkers,
				   $threadList,
				   $threadStatus,
				   $reassignmentContentsArray,
				   $reassignmentRequestArray,
				   $availableWorkersArray);
	
	$self->{REQUEST_WORKERS_SUB} = _generateRequestWorkersSub(
										$reassignmentRequestArray,
										$reassignmentContentsArray,
										$availableWorkersArray,
										$functionPackageMap,
										$clientWorkerRegistry);
										
	$self->{RELEASE_WORKERS_SUB} = _generateReleaseWorkersSub(
										$clientWorkerRegistry,
										$availableWorkersArray);
										
	$self->{SHUTDOWN_SUB} = 
		sub
		{
			my $fullResults = [];
			for my $index (0..(scalar(@$threadList) - 1))
			{
				# grab the current thread
				my $currentThread = $threadList->[$index];
				# get its thread id (unique)
				my $currentID = $currentThread->tid();
				# set the status of this thread to FALSE, which will signal for it to finish
				$threadStatus->[$currentID] = FALSE;
				# join the thread and add its results to the collection
				$fullResults->[$index] = $currentThread->join();
			}
			return $fullResults;
		};

	return $self;
}

sub requestWorkers
{
	my ($self, $clientID, $howMany, $functionPackage) = @_;
	return $self->{REQUEST_WORKERS_SUB}->(@_);
}

sub releaseWorkers
{
	my ($self, $clientID, $howMany) = @_;
	return $self->{RELEASE_WORKERS_SUB}->(@_);
}

sub shutdown
{
	my $self = shift;
	return $self->{SHUTDOWN_SUB}->();
}

sub 

sub _createThreads
{
	my ($maxWorkers,
	 	$threadList,
	 	$threadStatus,
     	$reassignmentContentsArray,
	 	$reassignmentRequestArray,
	 	$availableWorkersArray) = @_;
	 	
	# make a dummy function to create threads with
	my $dummyFunction = sub { return; };
	 	
	# make an array to grab up all the indices
	my $threadIndices = &share([]);
	for my $index (0..($maxWorkers - 1))
	{
		# create the subroutine for the thread to run
		my $executionFunction = _generateThreadExecutionSub($index,
															$threadStatus,
															$reassignmentRequestArray,
															$reassignmentContentsArray);
		# create the thread
		$threadList->[$index] = threads->create($executionFunction,
												$dummyFunction,
												$dummyFunction,
												$dummyFunction);
		# add the threads index to the collection
		$threadIndices->[$index] = $index;
		
	}
	push (@$availableWorkersArray, @$threadIndices);
}

sub _generateThreadExecutionSub
{
	my ($IDNumber,
		$statusArray,
		$reassignRequestArray,
		$reassignContentsArray) = @_;
	
	
	return
		sub
		{
			my ($processFunction, $getJob, $addJobs) = @_;
				
			my $totalJobsProcessed = 0;
			my $creationTime = time;
			
			while ($statusArray->[$IDNumber] == TRUE)
			{
				# get, process, and add jobs
				$addJobs->($processFunction->($getJob->()));
				# increment number of jobs processed
				$totalJobsProcessed++;
				# check for reassignment requests
				if ($reassignRequestArray->[$IDNumber] == TRUE)
				{
					# need to perform reassignment of add get process functions
					my @newSubs = @$reassignmentContentsArray->[$IDNumber];
					# put them into the right spots
					$processFunction = shift @newSubs;
					$getJob = shift @newSubs;
					$addJobs = shift @newSubs;
					# reassignment finished, turn off the signal
					$reassignRequestArray->[$IDNumber] = FALSE;
				}
				
				yield();
			}
			
		};
}

sub _generateReleaseWorkersSub
{
	my ($clientRegistry, $availableWorkersArray) = @_;
	return
		sub
		{
			my ($self, $clientID, $howMany) = @_;
			
			# get a list of workers the client is using
			my $clientWorkerList = $clientRegistry->{$clientID};
			# if the worker list is empty, return
			if (!$clientWorkerList)
			{
				return 0;
			}
			# check requested release number with how many are being used by the client
			# and modify the amount to remove if necessary
			my $currentNumberOfWorkers = scalar($clientWorkerList);
			
			my $numberToRemove = $howMany;
			if ($numberToRemove > $currentNumberOfWorkers)
			{
				$numberToRemove = $currentNumberOfWorkers;
			}
			
			# actually release the workers
			my $releasedWorkerIDs = [];
			for my $index (0..($numberToRemove))
			{
				$relasedWorkerIDs->[$index] = shift @$clientWorkerList;
			}
			# add all the released workers to the list of available workers
			push (@$availableWorkersArray, @$releasedWorkerIDs);
			# return the number of threads that actually got released
			return $numberToRemove;
		};
}

sub _generateRequestWorkersSub
{
	my ($reassignmentRequestArray, $reassignmentContentsArray, 
		$availableWorkersArray, $functionPackageMap,
		$clientWorkerRegistry) = @_;
	return
		sub
		{
			my ($self, $clientID, $howMany, $functionPackage) = @_;
			
			# check to see if the function bundle is defined here, or elsewhere
			# and decide on what function bundle to use
			my $replacementFunctions = $functionPackage;
			if (!$functionPackage)
			{
				my $storedFunctionPackage = $functionPackageMap->{$clientID};
				if ($storedFunctionPackage)
				{
					$replacementFunctions = $storedFunctionPackage;
				}
				else
				{
					return 0;
				}
			}
			else
			{
				$functionPackageMap->{$clientID} = $functionPackage;
			}
			
			# check for availability of workers
			my $numAvailableWorkers = scalar(@$availableWorkersArray);
			
			my $numWorkersToAdd = $howMany;
			# check against requested number
			if ($numAvailableWorkers < $howMany)
			{
				$numWorkersToAdd = $numAvailableWorkers;
			}
			
			# now have decided what functions to give the workers, and how many to create
			
			my $selectedWorkerIDList = &share([]);
			for my $index (0..($numWorkersToAdd-1))
			{
				# pull off the thread id of an available worker
				my $currentWorkerID = shift @$availableWorkersArray;
				$selectedWorkerIDList->[$index] = $currentWorkerID;
				# place the new function assignment in the right slot in the array
				$reassignmentContentsArray->[$currentWorkerID] = $replacementFunctions;
				# request a reassignment
				$reassignmentRequestArray->[$currentWorkerID] = TRUE;
			}
			# add all the worker id's to the client registry
			push (@{$clientWorkerRegistry->{$clientID}}, @$selectedWorkerIDList);
			return $numWorkersToAdd;
		};
}

1;