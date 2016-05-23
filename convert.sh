#!/bin/bash

#  Title:        Report Conversion Tool
#  Description:  This script converts the file structure or reports containing clean.sql, sproc.sql and profile.sql files.
#
#  Created by:   Ryan Walters - August 5th 2014
#
#  Usage:        ./convert.sh
#                Follow on screen prompts
#
#  Incorporates various originally created by Deric Miguel and Ryan Walters



# ------- Default values --------
input_directory='/Users/ryan/Work/Prologic/Reports/in-test/'
output_directory='/Users/ryan/Work/Prologic/Reports/out-test/'
# -------------------------------




# ----- Communicate needed applications
echo 'Report Conversion Tool'
echo '----------------------'
echo 'Creates .properties and ddl.sql files from profile.sql, clean.sql and sproc.sql files.'
echo ''
echo 'REQUIRES: dos2unix and pcregrep - Do not continue without them.'
echo '----------------------'
# -----------------------------------



# ----- Get name of report
echo "Enter report name (ex: some_report_name): "
read report_name
# -----------------------------------



# ----- Get report input location
echo ''
echo "Default input location: $input_directory"
echo "Enter location of current report (or press enter to use default): "
read last_input

if [ "$last_input" != "" ]; then
    input_directory="$last_input"
fi
# Assemble full report location
report_location="$input_directory/$report_name"
# ------------------------------------



# ----- Get report output location
echo ''
echo "Default output location: $output_directory"
echo "Enter converted report output location (or press enter to use default): "
read last_input

if [ "$last_input" != "" ]; then
    output_directory="$last_input"
fi
if [ -d "$output_directory/$report_name" ]; then
    output_location="$output_directory/$report_name"
else
    mkdir "$output_directory/$report_name"
    output_location="$output_directory/$report_name"
fi

cp -r "$input_directory/$report_name" "$output_directory"
# ------------------------------------



# ----- Convert line endings to unix for parsing
echo "Converting files to UNIX Line Endings..."
find "$output_location" -type f -name *sql -exec dos2unix -o {} \;
# ------------------------------------



# ----- Restructure folders and remove legacy files
if [ -e "$output_location/jasper/" ]; then
    for d in $output_location/*/ ; do
        if [ "$d" != "jasper/" ]; then
            rm -r $d
        fi
    done

    mv "$output_location/jasper/*" "$output_location/"
    rm -rf "$output_location/jasper"
    echo "Reconstructed $report_name"
fi

if [ -e "$output_location/iseries/" ]; then
    rm -r "$output_location/iseries/"
    echo "Reconstructed $report_name"
fi
# -----------------------------------


# ------- Create report.properties
if [ -e $output_location/report.properties ]; then
    rm $output_location/report.properties
fi

if [ -d $output_location/db2/ ]; then
    fol="$output_location/db2"
else
    fol="$output_location/mssql"
fi
STRING=`grep "insert into RFDS_TEAMS_RPT_PROFILE" $fol/clean.sql  | cut -d'(' -f3`
REPORT_NAME=`cut -d',' -f1 <<< $STRING | sed "s/'//g"`

CAN_BE_SCHEDULED=`cut -d',' -f2 <<< $STRING | sed "s/'//g"`
REPORT=`cut -d',' -f3 <<< $STRING | sed "s/'//g"`
NOTE=`cut -d',' -f4 <<< $STRING | sed "s/'//g"`
SYSTEM_OWNED=`cut -d',' -f6 <<< $STRING | sed "s/'//g"`
SUBCATEGORY=`cut -d',' -f7 <<< $STRING | sed "s/'//g"`
REPORT_TYPE='jasper'
CONNECTION_TYPE=`cut -d',' -f9 <<< $STRING | sed "s/'//g"`
ACTIVE_FLAG=`cut -d',' -f10 <<< $STRING | sed "s/'//g"`

# Get rid of / in report filename
REPORT=`cut -d'/' -f2 <<< $REPORT`

REPORT_EXTENSION=`cut -d'.' -f2 <<< $REPORT`
if [ "$REPORT_EXTENSION" == "jrxml" ]; then
    REPORT_TYPE='jasper'
else
    REPORT_TYPE='crystal'
fi

# Replace ' ' with '!'
NOTE=`sed "s/ /!/g" <<< $NOTE`
REPORT_NAME=`sed "s/ /!/g" <<< $REPORT_NAME`

if [ "$NOTE" == "null" ]; then
    NOTE="$REPORT_NAME"
fi

STRING="$REPORT_NAME $CAN_BE_SCHEDULED $REPORT $NOTE
$SYSTEM_OWNED  $SUBCATEGORY  $ACTIVE_FLAG
$CONNECTION_TYPE  $REPORT_TYPE  $OUTPUT_TYPE"

STRING=`sed "s/ /|/g" <<< $STRING`
FINAL=`sed "s/!/ /g" <<< $STRING`

old_IFS=$IFS
IFS='|'

set $FINAL >> /dev/null

FILE="$output_location/report.properties"

echo "Report_Name=\"$1\"" > $FILE
echo "Can_Be_Scheduled=\"$2\"" >> $FILE
echo "Report=\"$3\"" >> $FILE
echo "Note=\"$4\"" >> $FILE
echo "System_Owned=\"$5\"" >> $FILE
echo "Subcategory=\"$6\"" >> $FILE
echo "Active_Flag=\"$7\"" >> $FILE
echo "Connection_Type=\"$8\"" >> $FILE
echo "Report_Type=\"$9\"" >> $FILE

printf "Output_Type=\"" >> $FILE
N=0

#grep -i "insert into TEAMS_REPORT_PROF_OUTPUT_TYPE" $fol/clean.sql | cut -d'(' -f3-4 | awk '{print substr($0, 0, length($0)-1)}' |  while read -r line; do
pcregrep -Mi "insert into TEAMS_REPORT_PROF_OUTPUT_TYPE(.*\n){0,2}#\/" $fol/clean.sql | cut -d'(' -f3-4 | awk '{print substr($0, 0, length($0)-1)}' |  while read -r line; do

    VAR=`cut -d',' -f2 <<< $line | sed "s/'//g" | sed 's/^ *//'`
    VAR=`cut -d',' -f2 <<< $line | sed "s/ '//g" | sed "s/'//g"`

    if [ $N -ge 1 ]; then
        printf "|$VAR" >> $FILE
        ((N++))
        continue
    fi

    printf "$VAR" >>$FILE

    ((N++))
done

printf "\"\n" >> $FILE

prev_directory=`pwd`
cd $fol
SUBS=`find . -maxdepth 1 | grep jasper | xargs -i echo {} | sed "s/.\///g" | tr '\n' '|'`
SUBS_LEN=${#SUBS}
SUBS_LEN=`expr $SUBS_LEN - 1`
if [ $SUBS_LEN -gt 0 ]; then
    SUBS=${SUBS:0:$SUBS_LEN}
fi
echo "Sub_Reports=\"$SUBS\"" >> $output_location/report.properties
cd $prev_directory

echo 'Report_DDL_Dependencies="ddl.sql"' >> $output_location/report.properties
# -----------------------------------



# ----- Creating parameters.properties
if [ -e $output_location/parameters.properties ]; then
    rm $output_location/parameters.properties
fi

if [ -d $output_location/db2/ ]; then
    fol="$output_location/db2"
else
    fol="$output_location/mssql"
fi
grep "TEAMS_RPT_PROFILE_PARAMETER" $fol/profile.sql | cut -d'(' -f3-4 | awk '{print substr($0, 0, length($0)-1)}' |  while read -r line; do
#pcregrep -Mi "TEAMS_RPT_PROFILE_PARAMETER(.*\n){0,5}#\/" $1/db2/profile.sql | cut -d'(' -f1-2 | awk '{print substr($0, 0, length($0)-1)}' |  while read -r line; do
    VAR=`cut -d',' -f2 <<< $line | sed "s/'//g" | sed 's/^ *//'`
    VAR=`cut -d',' -f2 <<< $line | sed "s/ '//g" | sed "s/'//g"`

    VAR2=`cut -d',' -f3 <<< $line | sed "s/'//g" | sed 's/^ *//'`
    VAR2=`cut -d',' -f3 <<< $line | sed "s/ '//g" | sed "s/'//g"`

    VAR3=`cut -d',' -f4 <<< $line | sed "s/* ^//g" | sed 's/^ *//' | awk '{print substr($0, 2)}'`
    VAR3=`cut -d',' -f4 <<< $line | sed "s/ '//g" | sed "s/'//g" | awk '{print substr($0, 2)}'`

    VAR4=`cut -d',' -f5 <<< $line | sed "s/* ^//g" | sed 's/^ *//' | awk '{print substr($0, 2)}'`
    VAR4=`cut -d',' -f5 <<< $line | sed "s/ '//g" | sed "s/'//g" | awk '{print substr($0, 2)}'`

    VAR5=`cut -d',' -f6 <<< $line | sed "s/* ^//g" | sed 's/^ *//'`
    VAR5=`cut -d',' -f6 <<< $line | sed "s/ '//g" | sed "s/'//g"`

    VAR6=`cut -d',' -f7 <<< $line | sed "s/* ^//g" | sed 's/^ *//'`
    VAR6=`cut -d',' -f7 <<< $line | sed "s/ '//g" | sed "s/'//g"`

    VAR7=`cut -d',' -f8 <<< $line | sed "s/* ^//g" | sed 's/^ *//' | sed "s/ '//g" | sed "s/'//g" | awk '{print substr($0, 1)}'`

    VAR8=`cut -d',' -f9 <<< $line | sed "s/* ^//g" | sed 's/^ *//'`
    VAR8=`cut -d',' -f9 <<< $line | sed "s/ '//g" | sed "s/'//g"`
    VAR8=`cut -d',' -f9 <<< $line | sed "s/ '//g" | sed "s/)//g" | sed "s/'//g"`


    echo "$VAR|$VAR2|$VAR3|$VAR4|$VAR5|$VAR6|$VAR7|$VAR8" >> $output_location/parameters.properties
done

if [ -e $output_location/parameters.properties ]; then
    echo 'parameter_file="parameters.properties"' >> $output_location/report.properties
fi
# -----------------------------------



# ----- Create drop_down.properties
if [ -e $output_location/drop_down.properties ]; then
    rm $output_location/drop_down.properties
fi

if [ -d $output_location/db2/ ]; then
    fol="$output_location/db2"
else
    fol="$output_location/mssql"
fi

grep "TEAMS_RPT_PROF_PARAM_LIST_ITEM" $fol/profile.sql | cut -d'(' -f3-4 | awk '{print substr($0, 0, length($0)-1)}' |  while read -r line; do
    VAR=`cut -d',' -f2 <<< $line | sed "s/'//g" | sed 's/^ *//'`
    VAR=`cut -d',' -f2 <<< $line | sed "s/ '//g" | sed "s/'//g"`

    VAR2=`cut -d',' -f3 <<< $line | sed "s/'//g" | sed 's/^ *//'`
    VAR2=`cut -d',' -f3 <<< $line | sed "s/ '//g" | sed "s/)//g" | sed "s/'//g"`

    echo "$VAR|$VAR2" >> $output_location/drop_down.properties
done

if [ -e $output_location/drop_down.properties ]; then
    echo 'drop_down_file="drop_down.properties"' >> $output_location/report.properties
fi
# ----------------------------------



# ----- Create ddl.sql files
for d in $output_location/*/ ; do
    first_time=1
    touch $d/ddl.sql
    if [ -e "$d/clean.sql" ]; then

        # Check for any widgets
        pcregrep -Mi "insert into RFDS_TEAMS_RPT_PARAMETER_TYPE(.*\n){0,100}#\/" $d/clean.sql | sed "s/#\//go\n/g" |  while read line2; do
            if [ $first_time -eq 1 ]; then
                echo "@continue on error" > $d/ddl.sql
                first_time=0
            fi
            echo "$line2" >> $d/ddl.sql
        done

        # Add drop tables
        grep -i "DROP PROCEDURE " $d/clean.sql |  while read -r line; do
            if [ $first_time -eq 1 ]; then
                echo "@continue on error" > ddl.sql
                first_time=0
            fi
            echo "$line" >> ddl.sql
            echo "go" >> ddl.sql
            echo "" >> ddl.sql
        done

        pcregrep -Mi "CREATE FUNCTION(.*\n){0,100}#\/" $d/clean.sql | sed "s/#\//go\n/g" |  while read line2; do
            if [ $first_time -eq 1 ]; then
                echo "@stop on error" > $d/ddl.sql
                first_time=0
            fi
            echo "$line2" >> $d/ddl.sql
        done

        mkdir $d/old
        mv $d/clean.sql $d/old/clean.sql
        mv $d/profile.sql $d/old/profile.sql
    else
        mkdir $d/old
    fi

    # Reformat sproc to reflect
    first_time=1
    write_line=0
    started_comment=0
    sub_comment=0
    find $d/ -type f -iname "sproc*" | while read file_name; do
        if [ $first_time = 1 ]; then
            echo "@stop on error" >> $d/ddl.sql
        fi

        while read line; do
            if [ "$line" = "/#" ]; then
                write_line=1
                started_comment=1
            fi

            if [ "$line" = "/*" ]; then
                sub_comment=1
                write_line=0
            fi

            if [ $write_line -eq 1 ] && [ $started_comment -eq 0 ]; then
                if [ "$line" = "#/" ]; then
                    echo "go" >> $d/ddl.sql
                    started_comment=0
                    write_line=0
                else
                    echo "$line" >> $d/ddl.sql
                fi
            fi

            if [ "$line" = "*/" ]; then
                sub_comment=0
                write_line=1
            fi

            started_comment=0
        done < $file_name
        if [ "$line" == "#/" ]; then
            echo "go" >> $d/ddl.sql
        fi
        echo "" >> $d/ddl.sql
        mv $d/$file_name $d/old/
        first_time=1
        write_line=0
        sub_comment=0
    done
done