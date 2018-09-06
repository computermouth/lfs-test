#! /usr/bin/env python
import subprocess
import os
import re
import socket
import sys
import time
from subprocess import Popen, PIPE

DOMAIN_NAME="businesswire.com"

print "This is a monitor script to check consistency of GTID_EXECUTED sets on all nodes.  Any difference should be investigated and fixed before next switch over, otherwise a full database export and resore might be needed to bring the entire cluster back to in-sync state again.\n"
print "Please use mysqlbinlog to identify the SQLs which GTIDs are not shown up on all nodes.\n\n"

try:
	host_lifecycle=os.environ['BW_LIFECYCLE']
except:
	GEnv=open("/opt/businesswire/config/global.env","r")
	for line in GEnv:
		if "BW_LIFECYCLE" in line:
		        #print "found match " + line 
			str=line.split("=")
			#print "matched " + str[1]
			host_lifecycle=str[1].rstrip('\n')
        #print "life cycle is "+ host_lifecycle 
	GEnv.close()
            

#host_name=os.environ['HOSTNAME']
host_name=socket.gethostname()
#print "host name is " + host_name
local="sc"
remote="ny"

#jcon has different patten for host naming
if "jcon" in host_name:
        cluster_name="jcon"
        host1=cluster_name+ "."+local+host_lifecycle+"."+DOMAIN_NAME
        host2="dummyhost"
        host3=cluster_name+ "."+remote+host_lifecycle+"."+DOMAIN_NAME
        host4="dummyhost"
else:
        m=re.match( r'(.+)mysql(\d{1})',host_name)
        cluster_name=m.group(1)
        #print "cluster name = "+cluster_name
        host1=cluster_name+"mysql1"+ "."+local+host_lifecycle+"."+DOMAIN_NAME
        host2=cluster_name+"mysql2"+ "."+local+host_lifecycle+"."+ DOMAIN_NAME
        host3=cluster_name+"mysql1"+ "."+remote+host_lifecycle+"."+DOMAIN_NAME
        host4=cluster_name+"mysql2"+ "."+remote+host_lifecycle+"." + DOMAIN_NAME



hosts=[host1,host2,host3,host4]
invalidhosts=[]

for host in hosts:
        #print host
        try:
               socket.gethostbyname(host) 
        except:
               e=sys.exc_info()[0]
               #print e
               invalidhosts.append(host)
               #print "remove host " + host
               continue
 
#remove invalid hosts from hosts list

for host in invalidhosts:
	hosts.remove(host)

YES=0
NO=1

mysql_cmd_line="mysql -u dbaopt -pZu0Cr0N! -Bse "
# -Bse 'show global variables like \'GTID_EXEC%\';"
mysql_password='Zu0Cr0N!'
#proc = subprocess.Popen(cmd,stdout=subprocess.PIPE)
# out = proc.communicate()

def RunSqlCommand(sql_statement, hostname=None):
	command_list = mysql_cmd_line.split()

	command_list.append (sql_statement)
 
	# Run mysql in a subprocess
	if hostname:
		command_list.append("-h"+hostname)

	#print command_list
	process = Popen(command_list, stdin=PIPE, stdout=PIPE, stderr=PIPE, close_fds=True)
 
	# pass it our commands, and get the results
	(stdout, stderr) = process.communicate()
	#print stderr
 

	#print "out put is"+stdout
	return stdout


def test():
	sql="select @@global.gtid_executed;"
	gtids=[]

	for host in hosts:
		ret=(RunSqlCommand(sql,host))
		print "Checking host "+host
		print "%s" %ret
		gtids.append(ret)
	
	#print gtids

	pregtid=gtids[0]
	result=YES

	for gtid in gtids:
		if not pregtid == gtid:
			result=NO
		else:
			pregtid=gtid	
		
        return result


def main():

      repeat=3
      count=0

      ret=test()

      while ( ret != YES and count< repeat):
         print "Difference between nodes, sleep 5 seconds, checking again..." 
         count = count+1
         time.sleep(5) 
         ret=test()

      
      if ret == YES:
            print "Executed GTID on all hosts are identical"
      else:
           print "ALARM there is GTID difference between nodes in the cluster "+cluster_name
      



main()
