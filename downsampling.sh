#!/bin/bash
#Author : Prerna Rathore (HSBC)
#Version : 1.0 (original version)
#Running syntax : if you are running for 3 bucket logic
#				./script_name.sh bucket_1 bucket_2 bucket_3 3
#				
#				bucket_1 = bucket name with 15 seconds resolution data
#				bucket_2 = bucket name with 1 hour resolution data
#				bucket_3 = bucket name with 1 day resolution data
#				3 = downsample logic - this parameter is optional, by default it takes 3 bucket design, 
#										but if we need to make it 5 bucket design the value should be 5. 
#				if you are using downsample logic 5, please pass the parameters as
#				./script_name.sh bucket_1 bucket_2 bucket_3 5 bucket_4 bucket_5
#				bucket_1 = bucket name with 15 seconds resolution data
#				bucket_2 = bucket name with 1 minutes resolution data
#				bucket_3 = bucket name with 5 minutes resolution data 
#				5 = downsample logic - 5 will run the 5 bucket logic for downsampling.
#				bucket_4 = bucket name with 1 hour resolution data
#				bucket-5 = bucket name with 1 day resolution data
#___________________________________________________________________________________________________________________________________________#

## Function for determining the start and stop time for downsampling ##

Start_Stop_Time () {
##echo "$1 $2 $3"
"/c/Program Files/InfluxData/influxdb2-client-2.4.0-windows-amd64/influxdb2-client-2.4.0-windows-amd64/influx.exe" query --raw << END_COMMAND
	data = from(bucket: "$1")
	|> range (start: $2)
	|> keep(columns: ["_time"])
	|> first(column: "_time")
	|> yield()
	
END_COMMAND
}

#___________________________________________________________________________________________________________________________________________#

## Function for downsampling ##

Downsample_data () 

{

"/c/Program Files/InfluxData/influxdb2-client-2.4.0-windows-amd64/influxdb2-client-2.4.0-windows-amd64/influx.exe" query --raw << END_COMMAND
data = from(bucket: "$1")
|> range (start: $3, stop: $4)
|> aggregateWindow (every: $5, fn : mean, createEmpty : false)
|> to (bucket : "$2")
END_COMMAND

}

#___________________________________________________________________________________________________________________________________________#


##______MAIN Starts here______##



Logic=$4 ## fourth parameter to the script


case "$Logic" in
   "3"|"") 
   
	system_fifteen_seconds=$1 ## first parameter to the script
	system_one_hour=$2 ## second parameter to the script
	system_one_day=$3 ## third parameter to the script
	## Variables for extracting the last time before 7 days ##
	startTime='-8d'

	## Call the function for extracting the last time before 7 days##

	return_function=$(Start_Stop_Time $system_fifteen_seconds $startTime)

	startTimeRange=${return_function##*,}
	startTimeRange="${startTimeRange%T*}"
	#stopTimeRange=$(date +"%Y-%m-%d" -d "$startTimeRange + 1 day")
	stopTimeRange="${startTimeRange}T23:59:59Z"
	##stopTimeRange='now()'
	startTimeRange="${startTimeRange}T00:00:00Z"
	echo "$startTimeRange"
	echo "$stopTimeRange"
	
	
	
	if [ -n "$startTimeRange" ]
	then
	echo "downsampling the data"
	aggregationWindow=1h 

	## Call the function for downsampling 7 days data into 1h resolution and write to second bucket ##

	Status=$(Downsample_data $system_fifteen_seconds $system_one_hour $startTimeRange $stopTimeRange $aggregationWindow)
	echo "first downsampling is done - data loaded in system_one_hour bucket"
	
	## Call the function for downsampling 7 days data into 1d resolution and write to third bucket ##
	aggregationWindow=1d

	Status_downsample=$(Downsample_data $system_fifteen_seconds $system_one_day $startTimeRange $stopTimeRange $aggregationWindow)
	echo "second downsampling is done - data loaded in system_one_day bucket"

	##Delete the data we just downsampled from the 15 seconds resolution bucket
	"/c/Program Files/InfluxData/influxdb2-client-2.4.0-windows-amd64/influxdb2-client-2.4.0-windows-amd64/influx.exe" delete --bucket $system_fifteen_seconds --start $startTimeRange --stop $stopTimeRange
	echo "data before 7 days is deleted"
	
	else
	echo "No data before 7 days to downsample"
	fi	

   ;;
   "5") 
   echo "no logic defined for 5 yet"  
   ;;
   *)  
      echo "Invalid parameters to the script" 
      exit 1 # Command to come out of the program with status 1
      ;; 
esac

