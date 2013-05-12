

package ConfigurationParameters;

# here is where all the legal configuration file parameters are defined and assigned to a constant
use constant
{
	MAX_WORKER_THREADS => 'pipeline_maxWorkers',
	THROUGHPUT_SAMPLE_RATE => 'pipeline_throughputSampleRate',
	THROUGHPUT_SAMPLE_HISTORY_SIZE => 'pipeline_sampleHistorySize',
	INITIAL_WORKERS_PER_STAGE => 'pipeline_initialWorkersPerStage',
	SEED_FILENAME => 'pipeline_seedFilename'
};

1;