#!/usr/bin/perl

###########################################################################################################
#          Name:
#	   Description: This script takes the result from pt-table-check, re-checksum all tables
#		shows in the log file of pt-checksum-filter, rerun pt-table-checksum for maxium 10 	 
#		times, if the difference is still exist, email to MYSQL_DBA@businesswire.com for further
#		investigate.
############################################################################################################

#Variables

#$DEBUG=1;
$MASTERDB="sfprodi6-z1";
$SLAVEDB="nyprodi7-z1";
$CHECKSUMRESULTFILE="/home/mchen/scripts/result/DRUPALPROD_checksum_result.log";
$PTBASEDIR="/home/mchen/percona-toolkit-1.0.1/bin/";
$PTTABLEFILTERCOMMAND=$PTBASEDIR."pt-checksum-filter";
$PTCHECKSUMTABLECOMMAND=$PTBASEDIR."pt-table-checksum";
$MAXRECHECK=1;

print "Re-checksum the tables with differences between the primary master and the last slave!\n\n";
print "Read the log file from $CHECKSUMRESULTFILE ...\n\n";
 
$ptfiltercommand= $PTTABLEFILTERCOMMAND." ".$CHECKSUMRESULTFILE;
#print "$ptfiltercommand\n";
my $returncode=`$ptfiltercommand`;
#print $returncode;
my @array=split('\n',$returncode);
if ($DEBUG){
	print "DEBUG:  delta from the result file\n";
	foreach (@array)
	{
		print $_."\n";
	}
	print "DEBUG:  end delta.\n";
}

my @delta;
foreach $dbtables (@array){
	my @dblist=split(' ',$dbtables);
	if ( $DEBUG){
		#print "DEBUG:  dblist \n";
		foreach (@dblist){
			print "DEBUG:   ".$_."\n"; 
		}
		#print "DEBUG: end dblist.\n";
	}
	push(@delta, "@dblist[0] @dblist[1]");
}

if ( $DEBUG){
	print "DEBUG:  delta \n";
	foreach (@delta){
		print $_."\n";
	}
	print "DEBUG:  end delta. \n";
}
my %tmp=map{$_,0} @delta;
@delta=sort(keys %tmp);
foreach (@delta)
{
	print $_; 
	my @dbtable=split(' ',$_);
	$cmd=$PTCHECKSUMTABLECOMMAND." -ubackupuser -pb\@ckup0lny --databases ".@dbtable[0]." --tables ".@dbtable[1]." ".$MASTERDB." ".$SLAVEDB." | ".$PTTABLEFILTERCOMMAND;
	#print "command $cmd\t";
	my $count=0;
	my $ret=" ";
	while ( ($ret=`$cmd`) ne "" && $count <$MAXRECHECK)
	{
		sleep 10;
		$count ++;
	}
	#print "recheck.... ". $ret."\n";
	if ( $count>=$MAXRECHECK && $ret ne "" )
	{
		print "  Failedi with ".++$count." attemp(s)!!!\n!!!!!!!!!! ALARM !!!!!!!!!!\n";
		print "Checksum command: $cmd\n";
		print "Last checksum result:\n$ret\n";
		print "!!!!!!!!!! ALARM !!!!!!!!!!\n";
	}
	else
	{
        	print"  OK with ". ++$count." attemp(s).\n"
	}

}

sub isKnownDBTable
{
	my ($db, $table) = @_;
	if ( $db eq "i" && $table eq "search_total")
	{
		return true;
	}
	else
	{
		return false;
	}
}
