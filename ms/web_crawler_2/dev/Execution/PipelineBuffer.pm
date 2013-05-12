package PipelineBuffer;

# import CPAN modules
use threads;
use threads::shared;
use Thread::Queue;

sub new
{
	my $class = shift;
	
	my $self = &share({});
	
	my $jobQueue = new Thread::Queue;
	
	$self->{GET_JOB_SUB} = sub { return $jobQueue->dequeue_nb(); };
	$self->{ADD_JOBS_SUB} = sub { my ($self, $jobs); $jobQueue->enqueue(@$jobs); };
	$self->{GET_PENDING_JOBS_SUB} = sub { return $jobQueue->pending(); };
	
	bless $self, $class;
	return $self;
}

sub getJob
{
	my $self = shift;
	return $self->{GET_JOB_SUB}->();
}

sub addJobs
{
	my ($self, $jobs) = @_;
	$self->{ADD_JOBS_SUB}->($self, $jobs);
}

sub getPendingJobs
{
	my $self = shift;
	return $self->{GET_PENDING_JOBS_SUB}->();
}

1;