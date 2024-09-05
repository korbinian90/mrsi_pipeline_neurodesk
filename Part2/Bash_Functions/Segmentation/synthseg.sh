#!/bin/bash
# Run this script on MRF!
# Requires mnc2nii and mri_synthseg
# In the pipeline, there should be export out_dir=/path/to/your/output/directory

# Check if output directory is set, if not: use argument $1
if [ -z ${out_dir+x} ]; then
	if [ -z $1 ]; then
		echo -e "Please set the output directory using 'export out_dir=/path/to/your/output/directory' or provide the path as an argument."
		exit 1
	fi
	out_dir=$1
fi

corecount=32

if [ -e "${out_dir}/maps/magnitude.mnc" ]; then
	echo -e "\nRunning SynthSeg on magnitude.mnc..."

	mnc2nii -quiet "${out_dir}/maps/magnitude.mnc" "${out_dir}/maps/Segmentation/magnitude.nii"

	# Run synthseg
	$synthsegp \
		--i "${out_dir}/maps/Segmentation/magnitude.nii" \
		--o "${out_dir}/maps/Segmentation/" \
		--vol "${out_dir}/maps/Segmentation/ss_volumes.csv" \
		--qc "${out_dir}/maps/Segmentation/ss_qc.csv" \
		--cpu --threads $corecount

	# Clean up
	rm "${out_dir}/maps/Segmentation/magnitude.nii"
	mv "${out_dir}/maps/Segmentation/magnitude_synthseg.nii" Segmentation/ss_segmentation_fromT1.nii
	echo -e "SynthSeg (MP2RAGE) done.\n"
else
	echo -e "\nNo magnitude.mnc found. Proceeding without SynthSeg for MP2RAGE.\n"
fi

if [ -e "${out_dir}/maps/flair.mnc" ]; then
	echo -e "\nRunning SynthSeg on flair.mnc..."

	mnc2nii -quiet "${out_dir}/maps/flair.mnc" "${out_dir}/maps/Segmentation/flair.nii"

	# Run synthseg
	$synthsegp \
		--i "${out_dir}/maps/Segmentation/flair.nii" \
		--o "${out_dir}/maps/Segmentation/" \
		--vol "${out_dir}/maps/Segmentation/ss_volumes_flair.csv" \
		--qc "${out_dir}/maps/Segmentation/ss_qc_flair.csv" \
		--cpu --threads $corecount

	# Clean up
	rm "${out_dir}/maps/Segmentation/flair.nii"
	mv "${out_dir}/maps/Segmentation/flair_synthseg.nii" Segmentation/ss_segmentation_fromFLAIR.nii
	echo -e "SynthSeg (FLAIR) done.\n"
else
	echo -e "\nNo flair.mnc found. Proceeding without SynthSeg for FLAIR.\n"

fi

# echo -e "\nTo view outputs of SynthSeg, run:\ncolumn -s, -t < Segmentation/ss_qc.csv | less -#2 -N -S\nor\ncolumn -s, -t < Segmentation/ss_volumes.csv | less -#2 -N -S\n\n"

# Show csv files:
#column -s, -t < Segmentation/ss_qc.csv | less -#2 -N -S
#column -s, -t < Segmentation/ss_volumes.csv | less -#2 -N -S
