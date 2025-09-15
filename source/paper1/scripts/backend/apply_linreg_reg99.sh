#!/usr/bin/env bash

## Apply Linear registrations to the 99 cases in QC experiment for linear
## registration

HERE=/ipl/ipl27/sfernandez/qrater_paper

# Directories
NATIVES=${HERE}/data/regist99/nat
XFMS=${HERE}/data/regist99/xfms
OUTPUT=${HERE}/data/regist99/reg

# Template
ICBM2009c=${HERE}/data/mni_icbm152_t1_tal_nlin_asym_09c.mnc

# List
# ID,Subject,Session,Database,scan
LIST=${HERE}/data/raw/list_cases_linreg_scans.csv

# Bash array
mapfile -t lines < $LIST

# Iterate through lines — skip Header
for line in "${lines[@]:1}"
do
	# Check if there is an existing image
	# 2 native images were not found
	image=$(printf $line | cut -d, -f5)
	if [ ! -z $image ]
	then
		# Parse other needed columns
		case=$(printf $line | cut -d, -f1)
		sub=$(printf $line | cut -d, -f2)
		vis=$(printf $line | cut -d, -f3)

		# Native image
		native=${NATIVES}/$(basename $image)

		# Transformation
		xfm1=${XFMS}/tal_${sub}_${vis}.xfm
		xfm2=${XFMS}/tal_xfm_${sub}_${vis}.xfm
		if [ -f $xfm1 ] || [ -f $xfm2 ]
		then
			[ -f $xfm1 ] && xfm=$xfm1
			[ -f $xfm2 ] && xfm=$xfm2

			# Apply registration
			outfile=${OUTPUT}/${case}.mnc
			#if [  -f $outfile ]
			#then
				mincresample \
					-clobber \
					-like $ICBM2009c \
					-transformation $xfm \
					$native $outfile
			#fi
		else printf "Missing xfm: %s,%s\n%s\n" $sub $vis $native
		fi
	fi
done
