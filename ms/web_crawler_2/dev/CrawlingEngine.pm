# import CPAN modules
use threads;
use threads::shared;

# import local modules
use ConfigurationParameters;
use Execution::Pipeline;

# declare the constants used as CrawlingEngine members
use constant
{
	PROCESSING_FUNCTIONS,
	CONFIGURATION,
	PIPELINE,
	SEEDS
};

sub new
{
	my ($class, $processingFunctions, $configuration) = @_;
	my $self = {};
	
	$self->{PROCESSING_FUNCTIONS} = $processingFunctions;
	$self->{CONFIGURATION} = $configuration;
	
	
	
	bless $self, $class;
	return $self;
}

sub crawl
{	
	my $self = shift;
	my $params = [$self];
	
	# perform the initialization functions
	# 	initialize the pipeline
	#	load the seeds
	# 	add the seeds to the pipeline
	# all of these are mandatory so if any fails, the whole crawl fails
	unless (_executeAndPrintOnError(\&_initializePipeline, [$self], 'error initializing pipeline, crawl exiting')
				&& _executeAndPrintOnError(\&_loadSeedJobs, [$self], 'error loading seed jobs, crawl exiting')
				&& _executeAndPrintOnError(\&_addSeedsToPipeline, [$self, $self->{SEEDS}], 'error adding seeds to pipeline, crawl exiting')) {return};
	
	# now start the pipeline and grab the results
	my $pipelineResults = $self->{PIPELINE}->start();
	
	# do any needed processing on the results before returning them
	my $processedPipelineResults = _processResults($pipelineResults);
	
	# return the processed results
	return $processedPipelineResults;
}

sub _executeAndPrintOnError
{
	my ($function, $params, $message) = @_;
	my $returnValue = $function->(@{$params});
	if (!$returnValue)
	{
		_debugPrint($message);
	}
	return $returnValue;
}

sub _debugPrint
{
	my $message = shift;
	Util::debugPrint($message);
}

sub _initializePipeline
{
	my $self = shift;
	
	my $cfg = $self->{CONFIGURATION};
	
	# grab all the configuration parameters the pipeline requires
	#	max number of worker threads
	my $maxWorkers = _loadParameter($cfg, ConfigurationParameters::MAX_WORKER_THREADS);
	
	
	# construct the pipeline, give it configuration params explicitly
	my $pipeline = Pipeline->new($self->{PROCESSING_FUNCTIONS},
								 $maxWorkers);
	
	$self->{PIPELINE} = $pipeline;
	
	unless ($pipeline) {return 0;} else {return 1;};
}

sub _loadSeedJobs
{
	my $self = shift;
	# get the seed filename
	my $seedFilename = $self->{CONFIGURATION}->{ConfigurationParameters::SEED_FILENAME};
	# load the seeds from the file
	my $seeds = _loadSeedsFromFile($seedFilename);
	# add these seeds to $self
	$self->{SEEDS} = $seeds;
}

sub _loadSeedsFromFile
{
	open (SEED_FILE, "<", shift);
	my @seeds = ();
	while (<SEED_FILE>)
	{
		chomp();
		push (@seeds, $_);
	}
	close (SEED_FILE);
	return \@seeds;
}

sub _addSeedsToPipeline
{
	my $self = shift;
	# add the seeds to the pipeline
	$self->{PIPELINE}->addSeeds($self->{SEEDS});
}

sub _loadParameter
{
	my ($configuration, $parameter) = @_;
	return $configuration->{$parameter};
}