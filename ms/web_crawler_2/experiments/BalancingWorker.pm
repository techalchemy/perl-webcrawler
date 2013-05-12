

package BalancingWorker.pm;

sub new
{
	my ($class, $functions, $status, $bottleneckScores) = @_;
	
	my $thread = threads->create(\&_execute, $functions, $status, $bottleneckScores);
}

sub _execute
{
	my ($functions, $status, $bottleneckScores) = @_;
	
	# choose the 
}

1;