#!/usr/bin/perl
# skypecachedecode.pl
# Convert Skype host cache to readable ip address and port
# Written by Ryan - http://blog.doylenet.net
#
# Verson hostory
# ------------------------------------
# 0.1 - Initial release
#
use XML::Simple;
# Check command line options
if(@ARGV < 1){
	print("Usage: skypecachedecode.pl [FILE]\n");
	print("Displays a list of IP's/ports of a Skype host cache.\n"); 
	print("The required file is the shared.xml file\n\n");
	print("Example:\n");
	print("\tskypecachedecode.pl \"C:\\Documents and Settings\\Username\\Application Data\\Skype\\shared.xml\"\n");
	print("\tskypecachedecode.pl \"~/Library/Application Support/Skype/shared.xml\"\n");
	print("\tskypecachedecode.pl /home/username/.Skype/shared.xml\n\n");
	exit;
}
$sharedxml = $ARGV[0];

# Get the correct line out of the XML
$xml = new XML::Simple;
$data = $xml->XMLin($sharedxml);
$theline = $data->{'Lib'}->{'Connection'}->{'HostCache'};

# Split the file out with the common delimeter
@splitaddr = split(/50041050200/, $theline);

# Print out the ip addresses and ports
for ($i=1; $i<@splitaddr; $i++){
	# Print the first octet
	print hex(substr($splitaddr[$i], 0, 2)).".";
	# Print the second octect
	print hex(substr($splitaddr[$i], 2, 2)).".";
	# Print the third octect
	print hex(substr($splitaddr[$i], 4, 2)).".";
	# Print the last octect
	print hex(substr($splitaddr[$i], 6, 2)).":";
	# Print the port
	print hex(substr($splitaddr[$i], 8, 4));
	print "\n";
}

# Print out the total number of records, simply for information sake.
# This seems to always be about 200.
$totalrecords = @splitaddr - 1;
print"There are a total of " . $totalrecords  ." records\n";
