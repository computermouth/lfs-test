#!/bin/bash

# mysql credential 
user="bw_dbuser"
pass=""

# list of all databases
all_dbs="$(mysql -u $user -p$pass -Bse 'show databases')"        

for db in $all_dbs
     do
        if test  $db != "information_schema" 
            then if test $db != "mysql" 
            then if test $db != "sodb" 
            then if test $db != "slaptest" 
            then if test $db != "performance_schema" 
            then echo $db; mysql -u$user -p$pass $db -sN -e "SELECT * FROM panels_pane WHERE panel = 'content' AND type = 'embedded_content' AND shown = 1 AND configuration like '%quoteModule%'; "
		fi
	    fi
	   fi
        fi
    fi  
done


