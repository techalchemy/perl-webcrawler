

package WorkerThread;

use constant
{
	TRUE,
	FALSE
};

sub new
{
	my ($class,
		$processingFunction,
		$getJobFunction,
		$addJobsFunction,
		$checkStatusFunction) = @_;
		
	my $self = &share({});
	
	# create the reassignment mechanism
	my $reassignmentRequested :shared;
	
	
	$self->{EXECUTION_SUBROUTINE} = _createExecutionSubroutine();
	
														 
														 
	
	
	bless $self, $class;
	return $self;
}

sub start
{
	my $self = shift;
	
	$self->{THREAD_HANDLE} = threads->create($self->{EXECUTION_SUBROUTINE}->());
}

sub finish
{
	my $self = shift;
	return $self->{THREAD_HANDLE}->join();
}

sub reassignTask
{
	my ($self, $processFunction,
		$getJob, $addJobs,
		$checkStatus) = @_;
	
}

sub _createExecutionSubroutine
{
	my ($reassignmentRequest, $reassignmentFunction) = @_;
	
	return
		sub
		{
			my ($processingFunction, $getJobFunction, 
				$addJobsFunction, $checkStatusFunction) = @_;
			while ($checkStatusFunction->())
			{
				$addJobsFunction->($processingFunction->($getJobFunction->()));
				if ($reassignmentRequest->())
				{
					$reassignmentFunction->($processingFunction,
											$getJobFunction,
											$addJobsFunction,
											$checkStatusFunction) = @_;
				}
			}
		};
}


1;