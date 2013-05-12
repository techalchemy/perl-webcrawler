## @file lexicalClosureAndThreads.pl
# This file is intended to be run as an experiment. It was created to answer questions I had about the mechanics of certain activities in perl
# and will run an entire experiment that is explained in detail below.
# @par Hypothesis
# Using lexical closure programmers may make thread safe data. If a non shared array is referenced before threads are created, but their
# subroutines are getting defined, when the threads are running later they will all properly update safely this non shared array. If this
# hypothesis fails the next thing to try would be having shared scalar elements in a non shared array
# @par Experiment
# To test this hypothesis, we will create a value array and a function array. The function array will be populated dynamically with
# functions that will execute in other threads. So to test the hypothesis, we will see if when lexical scoping and multithreading is
# employed we can safely have multiple threads reference a non shared array.

# import cpan modules needed for experiment
use threads;
use threads::shared;

use constant NUM_SUBROUTINES => 2;

print "starting lexicalClosureAndThreads.pl...\n";
runExperiment();
print "finished running lexicalClosureAndThreads.pl...\n";

sub executeFunctions
{
	my $functions = shift;
	foreach(@$functions)
	{
		my $currentThread = threads->new($_);
		$currentThread->join();
	}
}

sub generateFunctions
{
	my @valueArray = @_;
	my $tempFunctions = [];
	for my $index (0..NUM_SUBROUTINES-1)
	{
		$tempFunctions->[$index] =
			sub
			{
				$valueArray[$index]++;
			};
	}
	return $tempFunctions;
}

sub runExperiment
{
	# initialize the value array
	my @values : shared = [];
	# initialize the function array
	my $functions = [];
	# populate the functions array
	$functions = generateFunctions(@values);
	# execute the functions
	executeFunctions($functions);
	# check to see what values changed
	print "values are functions executed: [" . join(",", @$values) . "]\n"; 
}