

package Pipeline;

# import CPAN modules
use threads;
use threads::shared;

# import local modules
use PipelineBuffer;
use PipelineStage;

# define the members as a constant
use constant
{
	PROCESSING_FUNCTIONS,
	MAX_WORKERS,
	SEED_JOBS,
	PIPELINE_STAGES,
	PIPELINE_BUFFERS,
	CONTROLLER,
	OBSERVER,
	MAID,
	NUM_STAGES,
	STAGE_CONFIG,
	BUFFER_CONFIG,
	OBSERVER_CONFIG,
	CONTROLLER_CONFIG
};

# start class definition

sub new
{
	my ($class, 
		$processingFunctions, 
		$maxWorkers,
		$initialWorkersPerStage,
		$throughputSampleRate,
		$maxThroughputHistorySize) = @_;
	
	my $self = &share({});
	# populate the members
	if ($processingFunctions) {$self->{PROCESSING_FUNCTIONS} = $processingFunctions;} else {return undef};
	if ($maxWorkers) {$self->{MAX_WORKERS} = $maxWorkers;} else {return undef};
	$self->{NUM_STAGES} = scalar(@$processingFunctions);
	
	# build the stage config
	$self->{STAGE_CONFIG} = [$throughputSampleRate, $maxThroughputHistorySize, $initialWorkersPerStage];
	
	# lazy initialization, so just bless and return
	bless $self, $class;
	return $self;
}

sub start
{
	my $self = shift;
	# initialize the pipeline
	unless (_init($self)) {_debugPrint('error initializing pipeline, pipeline exiting'); return undef;};
	# place the seeds into the first buffer
	unless (_placeSeedJobsInPipeline($self)) 
	{
		_debugPrint('no seed jobs found, nothing to execute, exiting'); 
		return undef;
	};
	
	# run the pipeline
	#	start all the stages and support threads
	
	# monitor the pipeline to check if finished
	while (!_isExecutionFinished($self))
	{
		yield();
	}
	
	# execution is finished, now shutdown all the shit
	my $results = _shutdownAndCleanupPipeline($self);
	# return the results
	return $results;
}

sub addSeeds
{
	my ($self, $seeds) = @_;
	$self->{SEED_JOBS} = $seeds;
}

sub _placeSeedJobsInPipeline
{
	my $self = shift;
	my $seedJobs = $self->{SEED_JOBS};
	if (!$seedJobs)
	{
		return undef;
	}
	$self->{PIPELINE_BUFFERS}->[0]->addJobs($seedJobs);
}

sub _isExecutionFinished
{
	my $self = shift;
	# TODO: implement Pipeline::_executionFinished
}

sub _shutdownAndCleanupPipeline
{
	my $self = shift;
	# TODO: implement Pipeline::_shutdownAndCleanupPipeline
}

sub _debugPrint
{
	# TODO: implement Pipeline::_debugPrint
}

sub _init
{
	my $self = shift;
	# initialize the pipeline buffers (fatal if failure)
	unless (_initializeBuffers($self)) {_debugPrint('error initializing stages, pipeline exiting'); return 0;};
	# initialize the pipeline stages (fatal if failure)
	unless (_initializeStages($self)) {_debugPrint('error initializing stages, pipeline exiting'); return 0;};
	# initialize the statistics collector (non-fatal if error)
	unless (_initializeObserver($self)) {_debugPrint('error initializing statistics aggregator');};
	# initialize the scheduler (non-fatal if error)
	unless (_initializeController($self)) {_debugPrint('error initializing scheduler');};
	# initialize the maid (non-fatal if error)
	unless (_initializeMaid($self)) {_debugPrint('error initializing maid');};
	# initialization completed, return truth
	return 1;
}

sub _initializeBuffers
{
	my $self = shift;
	
	my $numStages = $self->{NUM_STAGES};
	my $pipelineBuffers = &share([]);
	# need to create a buffer for each stage
	for my $index (0...$numStages)
	{
		$pipelineBuffers->[$index] = PipelineBuffer->new();
	}
	# make sure this Pipeline is shared
	if (!is_shared($self)) { _debugPrint('Pipeline not thread safe, buffer initialization failed'); return 0; };
	
	# add the buffers to the object
	$self->{PIPELINE_BUFFERS} = $pipelineBuffers;
	
	return 1;
}

sub _initializeStages
{
	my $self = shift;
	
	my $numStages = $self->{NUM_STAGES};
	my $pipelineStages = &share([]);
	my $pipelineBuffers = $self->{PIPELINE_BUFFERS};
	my $functions = $self->{PROCESSING_FUNCTIONS};
	my @stageConfig = @$self->{STAGE_CONFIG};
	# create the stages
	for my $index (0...$numStages)
	{
		$pipelineStages->[$index] = PipelineStage->new($functions->[$index],
													   $pipelineBuffers->[$index],
													   $pipelineBuffers->[($index + 1) % $numStages],
													   @stageConfig);
	}
	
	# add the stages to the object
	$self->{PIPELINE_STAGES} = $pipelineStages;
	
	return 1;
}

sub _initializeObserver
{
	my $self = shift;
	# TODO: implement Pipeline::_initializeObserver
	
	
}

sub _initializeController
{
	my $self = shift;
	# TODO: implement Pipeline::_initializeController
}


1;