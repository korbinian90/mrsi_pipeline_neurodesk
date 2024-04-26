#!/bin/bash

# GH 2019: 	a short function to compress 3D MRSI data slicewise. not very efficient but works.
# PL 202107: 	update - utilize parallelization for moving and packing
#		also adding support for water_spectra
#
# Be aware of this scripts counterpart, data_decompression_v1.sh!
# 
# Possibly to do: 
# Get rid of the hardcoded 39 slices
# Check if files exist in Compressed_Spectra and if so, don't pack... But I am not sure if that would even be a good idea. 
#


# Initialize
export data_compression_spectra=0
export data_compression_water_spectra=0
export out_flag=0
currentdirectory=$PWD

while getopts 's:w:o:?' OPTION
do
	case $OPTION in 
		s)	export data_compression_spectra=1
				export data_compression_spectra="$OPTARG"			
			;;
		w) 	export data_compression_water_spectra=1
				export data_compression_water_spectra="$OPTARG"
			;;
		o)	export out_flag=1
				out_dir="$OPTARG"
			;;
		?)	printf "\ndata_compression_v2.sh
Flags: 
-s	Turns on compression of metabolite spectra
-w	Turns on compression of water spectra
-o	Defines variable out_dir. 
	This is not needed in Part2, as Part2_EvaluateMRSI.sh has already run 'export out_dir'.
	When running as a standalone, consider using '-o \$PWD' or similar.
	If out_dir is not set, the current working directory is used.
-?	Displays this short help.

Example usage: ./data_compression_v2.sh -s 1 -w 1 -o \$PWD\n"
			exit 2
			;;
	esac
done

[ $data_compression_spectra == 0 ] && [ $data_compression_water_spectra == 0 ] && echo "No flags set for data_compression_v2.sh! Not compressing anything." && exit 0


echo -e "\nCompressing data into diamonds (now in parallel :D). \n"

# If out_dir is not set:
[ -z ${out_dir} ] && echo "Variable out_dir is empty! Using current directory." && out_dir=$PWD

echo "Folder: "$out_dir
cd ${out_dir}

timerstart=`date +%s`

##################### Metabolite Spectra ##################### 

if [ $data_compression_spectra == 1 ]; then
	echo "Handling metabolite spectra..."
	if [ ! -d ./spectra ]; then 		# Quick check if folder exists
		echo "Can't find spectra/ in this directory - skipping..." && pwd 
	else
		
######## Moving spectra in subfolders based on slice 
		mkdir -p Compressed_Spectra						# Prepare folders
		for i in {01..39}							# Hardcoded to our resolution (and again below!)
		do
		   	printf "Slice $i: "
			spec_count=0							# Only process folders that actually contain spectra
			spec_count=$(find ./spectra/*z$i* -type f 2> /dev/null | wc -l) 
			if [[ "$spec_count" -ge "1" ]]; then
				mkdir -p spectra/$i
				printf "Moving %5d files...   " $spec_count		
				ls ./spectra/*z$i* | parallel mv {} ./spectra/$i
			#	mv $(find ./spectra -name '*z'$i'*') ./spectra/$i
			#	parallel -m mv $(find ./spectra -name '*z'$i'*') ./spectra/$i
			
			else
				printf "Not moving any files.   "	
			fi
						
			[ $((${i#0} % 3)) == 0 ] && printf "\n" 			# For a cleaner log: check if i mod 3 == 0. If yes, print a linebreak
			
			# echo -e "test $spec_count "
		done
		
######## Packing spectra 		
		echo -e "Commencing parallel \e[9mparking\e[0m packing of spectra..."
		
		mkdir -p spectra && cd spectra						# For safety, recreate folder spectra/ to avoid catastrophic events that would happen if it was missing
		ls ./ | parallel -P 20 "tar cfz Spectra_Slice_{}.tar.gz {}/"		# this is where the magic happens
		# mv *.tar.gz ../Compressed_Spectra 					# moving serially (legacy)
		ls ./*.tar.gz | parallel mv {} ../Compressed_Spectra			# moving parallelly

		cd ${out_dir}
		[ "$(ls -A $out_dir/Compressed_Spectra)" ] && echo "Removing spectra folder" && rm -R ./spectra || echo "Compressed_Spectra appears to be emtpy! I will keep the uncompressed files for now."
		echo "Metabolite spectra are done."					# removing original directory
	fi	
fi
timerend1=`date +%s`

##################### Water Spectra ##################### 
# Same as above

if [ $data_compression_water_spectra == 1 ]; then
	echo "Let's get to the water spectra..."

	if [ ! -d ./water_spectra ]; then
		echo "Can't find water_spectra/ in this directory - skipping..." && pwd
	else
		mkdir -p Compressed_Water_Spectra
		
######## Moving spectra in subfolders based on slice 
		for i in {01..39}
		do
		   	printf "Slice $i: "
			spec_count=0
			spec_count=$(find ./water_spectra/*z$i* -type f 2> /dev/null | wc -l) 
			if [[ "$spec_count" -ge "1" ]]; then
				mkdir -p water_spectra/$i
				printf "Moving %5d files...   " $spec_count
				ls ./water_spectra/*z$i* | parallel mv {} ./water_spectra/$i
			else
				printf "Not moving any files.   "		
			fi
			
			[ $((${i#0} % 3)) == 0 ] && printf "\n" 			# For a cleaner log: check if i mod 3 == 0. If yes, print a linebreak
		done
			
######## Packing spectra 
		echo -e "Packing water spectra..."

		mkdir -p water_spectra && cd water_spectra				# For safety, see above 
		ls ./ | parallel -P 20 "tar cfz Water_Spectra_Slice_{}.tar.gz {}/" 
		ls ./*.tar.gz | parallel mv {} ../Compressed_Water_Spectra		 
		cd ${out_dir}
		[ "$(ls -A $out_dir/Compressed_Water_Spectra)" ] && echo "Removing water_spectra folder" && rm -R ./water_spectra || echo "Compressed_Water_Spectra appears to be emtpy! I will keep the uncompressed files for now."					
	fi
fi
timerend2=`date +%s`

cd $currentdirectory
echo "Diamonds generated! This process took around "$((((timerend1-timerstart))/60))" minutes for the metabolite spectra and "$((((timerend2-timerend1))/60))" minutes for the water spectra."


