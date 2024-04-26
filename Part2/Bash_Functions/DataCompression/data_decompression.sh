#!/bin/bash

# PL202108: A short function to decompress spectra and water spectra, useful for rerunning part 2 of the processing pipeline.
# 
# Note: Currently this script does not delete the folders Compressed_Spectra and Compressed_Water_Spectra/ after extraction!
# However, when the spectra are packed again, these folders are overwritten anyways.

# Initialize
export data_compression_spectra=0
export data_compression_water_spectra=0
export out_flag=0

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
		?)	printf "data_compression_v2.sh
Flags: 
-s	Turns on compression of metabolite spectra
-w	Turns on compression of water spectra
-o	Defines variable out_dir. This is not needed in Part2, as out_dir has already been specified by higher level scripts.
-?	Displays this short help.\n"
			exit 2
			;;
	esac
done

[ $data_compression_spectra == 0 ] && [ $data_compression_water_spectra == 0 ] && echo "No flags set for data_decompression_v1.sh! Not decompressing anything." && exit 0


echo -e "\nExtracting data from archives... \n"

if [ $out_flag == 0 ]; then out_dir=$PWD; echo "No out_dir specified, using current working directory instead."; fi

echo -e "Folder: "$out_dir"\n"
cd ${out_dir}
timerstart=`date +%s`


##################### Metabolite Spectra ##################### 

if [ $data_compression_spectra == 1 ]; then
	echo "Handling metabolite spectra..."
	# Starting with spectra
	mkdir -p spectra/
	cd Compressed_Spectra/
	for i in *.tar.gz; do 
		printf "$(echo $i | tr -dc "0-9") " 
		tar -xf $i 
	done; printf "\n"
#	mv ./??/* ../spectra/	#possibly error: argument list too long
	for slice in {01..39}; do [ -d ./$slice ] && printf "$slice " && mv ./$slice/* ../spectra/; done
	rm -r ./??/
	echo -e "\n"
	cd ..
fi
timerend1=`date +%s`

##################### Water Spectra ##################### 
# Same as above

if [ $data_compression_water_spectra == 1 ]; then
	echo "Let's get to the water spectra..."
	mkdir -p water_spectra/
	cd Compressed_Water_Spectra/
		for i in *.tar.gz; do 
		printf "$(echo $i | tr -dc "0-9") " 
		tar -xf $i 
	done; printf "\n"
	for slice in {01..39}; do [ -d ./$slice ] && printf "$slice " && mv ./$slice/* ../water_spectra/; done
	rm -r ./??/
	echo -e "\n"
	cd ..		
fi
timerend2=`date +%s`

echo -e "Extraction done! This process took around "$((((timerend1-timerstart))/60))" minutes for the metabolite spectra and "$((((timerend2-timerend1))/60))" minutes for the water spectra.\n"

exit 0 

# old extraction code from part2
#	echo -e "\n Checking for Compressed_Spectra and Compressed_Water_spectra \n\n"
#
#	if [ -d "${out_dir}/Compressed_Spectra" ]; then
#		echo -e "\n Compressed_Spectra/ found. Uncompressing... \n\n"
#		for i in Compressed_Spectra/*; do 
#			printf "$(echo $i | tr -dc "0-9") " 
#			tar -xf $i --directory spectra
#		done; printf "\n"
#		
#		mv spectra/*/* spectra/
#		rm -r spectra/??/
#	fi
#
#	if [ -d "${out_dir}/Compressed_Water_Spectra" ]; then
#		echo -e "\n Compressed_Water_Spectra/ found. Uncompressing... \n\n"
#		for i in Compressed_Water_Spectra/*; do 
#			printf "$(echo $i | tr -dc "0-9") " 
#			tar -xf $i --directory water_spectra
#		done; printf "\n"
#		
#		mv water_spectra/*/* water_spectra/
#		rm -r water_spectra/??/


