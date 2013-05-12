

package Observer;

use constant
{
	STATS_COLLECTION,
	START_SUB,
	STOP_SUB
};

sub new
{
	my ($class,
		$pipelineStages,
		$pipelineBuffers,
		$controller) = @_;
	
	my $self = &share({});
	
	# start sub
	$self->{START_SUB} = _generateStartSub();
	# stop sub
	$self->{STOP_SUB} = _generateStopSub();
	# initialize statistics collection
	$self->{STATS_COLLECTION} = _generateStatsCollector();
	
	
	bless $self, $class;
	return $self;
}

sub start
{
	my $self = shift;
	$self->{START_SUB}->();
}

sub stop
{
	my $self = shift;
	$self->{STOP_SUB}->();
}

1;