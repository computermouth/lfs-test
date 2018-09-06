#!/usr/bin/perl 

###########################################################################################################
#          Name:
#	   Description: This script takes the result from pt-table-check, re-checksum all tables
#		shows in the log file of pt-checksum-filter, rerun pt-table-checksum for maxium 10 	 
#		times, if the difference is still exist, email to MYSQL_DBA@businesswire.com for further
#		investigate.
############################################################################################################

print ("Runing recheck.pl\n");
use Getopt::Std;
getopts("u:p:f:m:s:");
print ("Parameters are: $opt_u $opt_p $opt_f $opt_m $opt_s\n");
#Variables

#$DEBUG=1;
#$MASTERDB="mysql1.sfprod";
$MASTERDB=$opt_m;
#$SLAVEDB="mysql1.nyprod";
$SLAVEDB=$opt_s;
#$CHECKSUMRESULTFILE="/home/mchen/scripts/result/DRUPALPROD_checksum_result.log";
$CHECKSUMRESULTFILE=$opt_f;
#$PTBASEDIR="~/scripts/tools/percona-toolkit-1.0.1/bin/";
$PTBASEDIR="";
$PTTABLEFILTERCOMMAND=$PTBASEDIR."pt-checksum-filter";
$PTCHECKSUMTABLECOMMAND=$PTBASEDIR."pt-table-checksum";
$MAXRECHECK=1;

$USER=$opt_u;
$PASS=$opt_p;

print "Re-checksum the tables with differences between the primary master and the last slave!\n\n";
print "Read the log file from $CHECKSUMRESULTFILE ...\n\n";
 
$ptfiltercommand= $PTTABLEFILTERCOMMAND." ".$CHECKSUMRESULTFILE;
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
my $c=@delta;
if ( $c == 0 )
{
	print "There is no checksum difference between two hosts\n";
	#open (FILE,"$CHECKSUMRESULTFILE") or die ("cannot read $CHECKSUMRESULTFILE");
	system ("tail -100  ${CHECKSUMRESULTFILE}");
}
	
foreach (@delta)
{
	print $_; 
	my @dbtable=split(' ',$_);
	$cmd=$PTCHECKSUMTABLECOMMAND." -u".$USER." -p".$PASS." --databases ".@dbtable[0]." --tables ".@dbtable[1]." ".$MASTERDB." ".$SLAVEDB." | ".$PTTABLEFILTERCOMMAND;
	$alt_cmd=$PTCHECKSUMTABLECOMMAND." -u".$USER." -p".$PASS." --databases ".@dbtable[0]." --algorithm=BIT_XOR --tables ".@dbtable[1]." ".$MASTERDB." ".$SLAVEDB." | ".$PTTABLEFILTERCOMMAND;
	print "!!!!!command $cmd\t";
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
    		if (isKnownDBTable(@dbtable[0], @dbtable[1])==1)
		{
                     $ret=`$altcmd`;
		     if ($ret ne "" )
		     {
 			sendAlarm($altcmd);
		     }
		     else
    	             {
        		print"  OK  with BIT_XOR algorithm after ". ++$count." attemp(s).\n"
		     }		
                }
		else
		{
			print "  Failedi with ".++$count." attemp(s)!!!\n!!!!!!!!!! ALARM !!!!!!!!!!\n";
			print "Checksum command: $cmd\n";
			print "Last checksum result:\n$ret\n";
			print "!!!!!!!!!! ALARM !!!!!!!!!!\n";
		}
	}
	else
	{
        	print"  OK with ". ++$count." attemp(s).\n"
	}

}
sub sendAlarm()
{
    	my ($cmd)=@_;
	print "  Failedi with ".++$count." attemp(s)!!!\n!!!!!!!!!! ALARM !!!!!!!!!!\n";
	print "Checksum command: $cmd\n";
	print "Last checksum result:\n$ret\n";
	print "!!!!!!!!!! ALARM !!!!!!!!!!\n";
   
}
sub isKnownDBTable
{
	my ($db, $table) = @_;
	if ( $table eq "search_total")
	{
		return 1;
	}
	else
	{
		return 0;
	}
}
