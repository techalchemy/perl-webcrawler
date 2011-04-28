

#print (0..-1) . "\n";
#
#my $numToGenerate = 100;
#
#for my $index (1..$numToGenerate)
#{
#	my $resultString = '';
#	$resultString .= int(rand(0));
#	if ($index % 10 == 0)
#	{
#		$resultString .= "\n";
#	}
#	else
#	{
#		$resultString .= "\t";
#	}
#	print $resultString;
#}

{
	package Stuff;
	use constant
	{
		FIRST_THING => 2,
		SECOND_THING => 8
	}
}

main();

sub main
{
	print "first thing is: " . Stuff::FIRST_THING . "\n";
	print "second thing is: " . Stuff::SECOND_THING . "\n";
}