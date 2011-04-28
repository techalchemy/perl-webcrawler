package BossThread;

use threads;
use threads::shared;

sub new
{
	my ($class, $getFeaturesFunction, $isRunningFunction) = @_;
	
	my $self = {};
	
	# create the subroutine the actual thread will execute
	
	bless $self, $class;
	return $self;
}

sub start
{
	my $self = shift;
	$self->{executionThread} = threads->create(\&_run);
}

sub finish
{
	my $self = shift;
	return $self->{executionThread}->join();
}

sub _run
{
	
}

1;