#!/usr/bin/perl
use strict;
use FindBin;
use Cwd;

my $debug;
my $curDir;
my $dbBackupFileName;
my $dbFileName;

$debug=1;
$curDir=getcwd();
print "The current path is $curDir\n";

print "Please type the full MySQL data backup file:";
$dbBackupFileName=<>;
$dbFileName=getcwd."/".$dbBackupFileName;
print "File name: ".$dbFileName if $debug;

if ( !(-e $dbFileName ))
{
	print "$dbFileName doesn't exist. Please check your file name again!\n";
}else{
	print "not a gz file\n" if $debug;
}



sub isZipFile( )
{
	my $filename;
	my $result;
	$filename=$_[0];
	$result = `gunzip $filename` if (substr( uc($filename),length($filename) -4,3) eq ".GZ");
	print $result;
}
