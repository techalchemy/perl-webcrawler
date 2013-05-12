## @file CrawlingEngine.pm
# This file is going to contain all the necessary functions to drive a given crawling task. This module will
# then be run by a main driver script that will perform necessary initialization and activate this module with
# the proper parameters for the given crawling job. This engine will be a multithreaded crawler that will be given
# a set of seeds and parameters to initiate a crawl. The intention of this module is to only deal with the issues
# related to the mechanics of crawling the page. The current plan for the architecture is described below. This engine
# is also intended to be extremely configurable and as a result expects a hash of configuration parameters. The
# configuration parameters utilized by this script and what their function is are listed below as well.
# @par Threading Model
# From the previous version of the model, it appeared that retrieving pages was taking much longer than it
# took to actually parse the page, output it, and collect statistics. Because of this, we are going to
# switch to a pipelined model. The model is currently assumed to have four stages. Each of these stages will
# have its own thread pool. This will allow the crawler to dynamically allocate resources to different stages
# to properly balance the different runtimes required for each. Each pipeline stage will be encapsulated
# into an instance of a class that handles all the processing for a pipeline stage
# @par Configuration Parameters
# - Engine Parameters
#	- maxWorkerThreads this parameter specifies the total number of worker threads the engine can utilize. This number doesn't ensure that
#	  that number of threads will be used at any specific time or the total number of threads used by this engine when monitoring and support
#	  threads are taken into account
#	- linkDepth this parameter specifies the link depth the crawling will descend to before terminating
#   - initialResourceAllocationHints this is an array with an entry for each stage of the pipeline. is used to help engine load balance



package CrawlingEngine;

# bring in cpan modules
use Thread::Queue;

# bring in local modules used
use PipelineStage;
use Utilities::Util;

#declare constants
use constant NUM_PIPELINE_STAGES => 4;

sub crawl
{
	my ($configurationParameters, $seedsList) = @_;
	# initialize the queues to be used as buffers between stages. These will be stored in an array with the index indicating
	# the stage that will populate it
	Util::debugPrint('initializing pipeline buffers');
	my @pipelineBuffers;
	if (!initializeBuffer(\@pipelineBuffers))
	{
		Util::debugPrint('problem initializing pipeline buffers, crawl exiting');
		return 0;
	}
	Util::debugPrint('pipeline buffers initialized');
	# initialize the pipeline
	Util::debugPrint('initializing pipeline stages');
	my @pipelineStages;
	if (!initializePipeline(\@pipelineStages))
	{
		Util::debugPrint('problem initializing pipeline stages, crawl exiting');
	}
	Util::debugPrint('pipeline stages initialized');
	# place seeds into the first pipeline buffer
	
}

sub initializePipeline
{
	
}

sub initializeBuffers
{
	my $bufferArray = $_[0];
	for(1..NUM_PIPELINE_STAGES)
	{
		my $currentQueue = Thread::Queue->new();
		if (!$currentQueue) { return 0; };
		push(@$bufferArray, $currentQueue);
	}
	return 1;
}

1;