## @file anonSubTesting.pl
# This file is intended to be a script that will test a hypothesis that will be listed below
# @par Hypothesis
# Will anonymous subroutines maintain their references throughout the runtime of the script, if they are
# referencing a variable that was local to the block in which the subroutine was declared?
# @par Experiment
# Create an array, intending to hold 2 scalar elements called value array
# Create an array, intended to hold two function references
# for each i in 0..1
# 	create anonymous subroutine
#		value array [i]++;
#	add that sub to function reference [i];
# go to another function
# 	foreach function reference
# 		current function -> ();
# assert each element of value array == 1
# @par Explanation
# Two function reference are assigned values. The value each receives is a subroutine declared inside the loop
# The subroutine performs the same function for each of the functions (2) we make. The difference is in what data
# is being referred to. Function f1, {f1 => first function reference, f2 => second function reference}, increments the value 
# at the first index of the value array. The value array is an array that is declared in the same scope (not including the for loop), 
# as the declaration of f1 and f2.
# @par Results
# The program did pass 
# @par Conclusion
# @par Additional Information

use constant NUM_SUBROUTINES => 2;
use strict;
use constant DEBUG_FILENAME => 'experiment_report.dbg';
use lib '../Utilities';
use Utilities::Util;

print "Beginning anonSubTesting.pl..\n";
initializeDebugging();
runExperiment();
print "Finished running anonSubTesting.pl\n";

sub runExperiment
{
	# declare the value array
	Util::debugPrint('inside runExperiment()');
	my $valueArray = [];
	Util::debugPrint('value array created');
	# declare the function reference array
	my $functionReferenceArray = [];
	Util::debugPrint('function reference array created');
	# loop through the indices of the arrays, create function refs
	printValueAndFunctionAddress($valueArray, $functionReferenceArray);
	for my $index (1..NUM_SUBROUTINES)
	{
		Util::debugPrint('inside for loop, declaring anonymous subroutine');
		$functionReferenceArray->[$index] = 
			sub 
			{
				Util::debugPrint('inside anonymous subroutine index:' . $index . ' val arr address:' . $valueArray);
				$valueArray->[$index]++;
			};
	}
	# function reference array is now populated, execute these routines
	Util::debugPrint('calling executeFunctions()');
	executeFunctions($functionReferenceArray);
	Util::debugPrint('back from executeFunctions, in runExperiment');
	# check the results
	Util::debugPrint('checking the results, both entries in value array should be equal to 1');
	Util::debugPrint('calling checkResults()');
	checkResults($valueArray);
	Util::debugPrint('back from checkResults, in runExperiment');
	Util::debugPrint('leaving runExperiment');
}

sub checkResults
{
	my $valueArray = $_[0];
	for my $index (1..NUM_SUBROUTINES)
	{
		my $resultsTest = ($valueArray->[$index] == 1);
		if ($resultsTest)
		{
			Util::debugPrint('ASSERTION PASSED (value array at index ' . $index . ' equal to 1)');
		}
		else
		{
			Util::debugPrint('ASSERTION FAILED (value array at index ' . $index . ' NOT equal to 1)');
		}
	}
}

sub executeFunctions
{
	my $fRefs = $_[0];
	Util::debugPrint('inside executeFunctions()');
	Util::debugPrint('function reference array address: ' . $fRefs);
	for my $index (1..NUM_SUBROUTINES)
	{
		Util::debugPrint('executing function at index ' . $index);
		$fRefs->[$index]->();
	}
	Util::debugPrint('leaving executeFunctions()');
}

sub printValueAndFunctionAddress
{
	my ($valAddress, $fAddress) = @_;
	Util::debugPrint('value array address: ' . $valAddress);
	Util::debugPrint('function reference array address: ' . $fAddress);
}

sub initializeDebugging
{
	Util::setGlobalDebug(1);
	unlink(DEBUG_FILENAME);
	Util::setGlobalDebugFile(DEBUG_FILENAME);
	
	Util::setThreadRecord(0);
	Util::debugPrint('debugging initialized, starting experiment');
}