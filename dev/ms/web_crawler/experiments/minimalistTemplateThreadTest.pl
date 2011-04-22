

use threads;
use threads::shared;

# create the signaler
my $createThreadSignal :shared;
my $templateThread :shared;
my $sharedErrorMessage :shared;
BEGIN
{
	require threads;
	require threads::shared;
	$templateThread = threads->create(
		sub
		{
			while(1)
			{
				if ($createThreadSignal == 1)
				{
					threads->create(
						sub
						{
							eval
							{
								struct(TEST =>
								{
									whatever => '$'
								});
							};
							$sharedErrorMessage = shared_clone($@);
						});
					$createThreadSignal = 0;
					last;
				}
			}
		}
	);
}

main();

sub main
{
	$createThreadSignal = 1;
	
	while ($createThreadSignal == 1)
	{
		yield();
	}
	
	require Class::Struct;
	Class::Struct->import();
	
	print "number of threads: " . scalar(threads::list(threads::all())) . "\n";
	print "error message seen: " . $sharedErrorMessage . "\n";
}