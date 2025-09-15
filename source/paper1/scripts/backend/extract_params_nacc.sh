#!/usr/bin/env bash

HERE=/ipl/ipl27/sfernandez/qrater_paper
DATA_DIR=${HERE}/data/raw/nacc


printf "slice,slices,x,y,z,rep,echo,seq\n" > $DATA_DIR/params.csv

for img in $DATA_DIR/links_imgs/*
do
	printf "%s:\n" $img
	slice=$(mincheader $img |
		awk -F '=' '/slice_thickness/ { split($2, a, ";"); print a[1] }')
	#printf "%s, " $slice
	slices=$(mincheader $img |
		awk -F '=' '/num_slices/ { split($2, a, ";"); print a[1] }')
	#printf "%s, " $slices
	x=$(mincinfo $img |
		awk '/^[[:space:]]*xspace/ { print $2 }')
	#printf "%s, " $x
	y=$(mincinfo $img |
		awk '/^[[:space:]]*yspace/ { print $2 }')
	#printf "%s, " $y
	z=$(mincinfo $img |
		awk '/^[[:space:]]*zspace/ { print $2 }')
	#printf "%s, " $z
	reptime=$(mincheader $img |
		awk -F '=' '/repetition_time/ { split($2, a, ";"); print a[1] }')
	#printf "%s, " $reptime
	echotime=$(mincheader $img |
		awk -F '=' '/echo_time/ { split($2, a, ";"); print a[1] }')
	#printf "%s, " $echotime
	sequence=$(mincheader $img |
		awk -F '=' '/series_description/ { split($2, a, ";"); print a[1] }' |
		tr -d '\n')
	#printf "%s\n" "$sequence"
	printf "%.3f,%f,%d,%d,%d,%.3f,%.3f,%s\n" \
		$slice $slices $x $y $z \
		$reptime $echotime "$sequence" >> $DATA_DIR/params.csv
done
