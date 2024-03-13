#!/bin/bash
########################################################################################################
########### Segmentation of T1 (magnitude.mnc) into GM, WM and CSF #####################################
########################################################################################################
#           First step : resample one arbitrary mnc csi file to 
#	    magnitude.mnc resolution.
#	    Second step : resample the magnitude to CSI - if they
#	    have different angulation of slices
# 	    Third step : Convert this resampled magnitude to nii
# 	    for BET and segmentation (FAST)
		
		# extract brain using BET
		#  useful bet flags :
		# -f <f> fractional intensity threshold (0->1); default=0.5; smaller values 
		# give larger brain outline estimates
		# -g <g> vertical gradient in fractional intensity threshold (-1->1); 
		# default=0; positive values give larger brain outline at bottom, smaller at top
#	    Fourth step : 

## Find the first .mnc file and save its name (to be used as a template)
csilate="$out_dir/maps/csi_template.mnc"
echo -e "\nUsing this CSI template in segmentation.sh:\n$csilate\n"

# From csi - read the information needed for mincresampling the T1
step_csi=$(mincinfo $csilate -attvalue xspace:step -attvalue yspace:step -attvalue zspace:step)
dircos_csi=$(mincinfo $csilate -attvalue xspace:direction_cosines -attvalue yspace:direction_cosines -attvalue zspace:direction_cosines)
dimlength_csi=$(mincinfo $csilate -dimlength xspace -dimlength yspace -dimlength zspace)
# From magnitude
dimlength_magnitude=$(mincinfo ${out_dir}/maps/magnitude.mnc -dimlength xspace -dimlength yspace -dimlength zspace)
step_magnitude=$(mincinfo ${out_dir}/maps/magnitude.mnc -attvalue xspace:step -attvalue yspace:step -attvalue zspace:step)

## Convert variables into arrays
IFS=$'\n' step_csi=($step_csi)
IFS=$'\n' dircos_csi=($dircos_csi)
IFS=$'\n' dimlength_csi=($dimlength_csi)
IFS=$'\n' dimlength_magnitude=($dimlength_magnitude)
IFS=$'\n' step_magnitude=($step_magnitude)

# get the needed step size for csi resampling
xstep_csiToT1=$(echo "scale=5; ${step_csi[0]}/(${dimlength_magnitude[0]}/${dimlength_csi[0]})" | bc -l | xargs printf "%1.3f")
ystep_csiToT1=$(echo "scale=5; ${step_csi[1]}/(${dimlength_magnitude[1]}/${dimlength_csi[1]})" | bc -l | xargs printf "%1.3f")
zstep_T1=$(echo "scale=5; ${step_magnitude[2]}" | bc -l | xargs printf "%1.3f")
#zstep_csiToT1=$(echo "scale=5; ${step_csi[2]}/(${dimlength_magnitude[2]}/${dimlength_csi[2]})" | bc -l | xargs printf "%1.3f")

## mincresample csilate to T1 resolution
mincresample -clobber -nelements ${dimlength_magnitude[*]} -xstep $xstep_csiToT1 -ystep $ystep_csiToT1 -zstep $zstep_T1  $csilate ${out_dir}/maps/Seg_temp/Csi_resamToT1.mnc

# Apply direction cosines of MRSI on T1 dataset
echo "mincresample -clobber -xdircos ${dircos_csi[0]} -ydircos ${dircos_csi[1]} -zdircos ${dircos_csi[2]} ${out_dir}/maps/magnitude.mnc ${out_dir}/maps/Seg_temp/magnitude_resamToCsi.mnc" > ${out_dir}/maps/Seg_temp/resampleT1toCSI.txt

bash ${out_dir}/maps/Seg_temp/resampleT1toCSI.txt

# convert mnc T1 image (resampled) into nifti image
mnc2nii ${out_dir}/maps/Seg_temp/magnitude_resamToCsi.mnc ${out_dir}/maps/Seg_temp/Nifti/magnitude_resamToCsi.nii

# find the nii file in Segmentation folder
nif_magnitude=($(find ${out_dir}/maps/Seg_temp/Nifti -iname "*.nii" -print))
echo -e "\n\n0. PERFORM BET brain extraction\n\n"
bet2 $nif_magnitude ${out_dir}/maps/Segmentation/magnitude_resamToCsi_bet.nii -f 0.33 -g 0
bet2 $nif_magnitude ${out_dir}/maps/Segmentation/magnitude_resamToCsi_bet -f 0.33 -g 0 -m -n
# Run only if .nii files do not exist
if [[ ! -f ${out_dir}/maps/Segmentation/magnitude_resamToCsi_bet_pve_0.nii ]]; then
	# segment the T1 image into 3 tissue types using FAST
	echo -e "\n\n0. PERFORM FAST segmentation\n\n"
	fast -t 1 -o ${out_dir}/maps/Segmentation/magnitude_resamToCsi_bet -n 3 ${out_dir}/maps/Segmentation/magnitude_resamToCsi_bet.nii.gz
	echo -e "\n\n0. UNZIP the created files\n\n"
	# Unzip to use for mask
	gzip -d -f ${out_dir}/maps/Segmentation/magnitude_resamToCsi_bet_mask.nii.gz

	# Unzip the segmented images
	gzip -d -f ${out_dir}/maps/Segmentation/magnitude_resamToCsi_bet_pve_0.nii.gz
	gzip -d -f ${out_dir}/maps/Segmentation/magnitude_resamToCsi_bet_pve_1.nii.gz
	gzip -d -f ${out_dir}/maps/Segmentation/magnitude_resamToCsi_bet_pve_2.nii.gz
else
	echo -e "\n\n0. Skipping FAST segmentation - files are already here.\n\n"
fi

echo -e "\n\n0. nii2mnc\n\n"
# Convert nifti segmented maps into minc files
nii2mnc ${out_dir}/maps/Segmentation/magnitude_resamToCsi_bet_pve_0.nii ${out_dir}/maps/Seg_temp/magnitude_resamToCsi_bet_pve_0.mnc	
nii2mnc ${out_dir}/maps/Segmentation/magnitude_resamToCsi_bet_pve_1.nii ${out_dir}/maps/Seg_temp/magnitude_resamToCsi_bet_pve_1.mnc
nii2mnc ${out_dir}/maps/Segmentation/magnitude_resamToCsi_bet_pve_2.nii ${out_dir}/maps/Seg_temp/magnitude_resamToCsi_bet_pve_2.mnc
	
#get the step size of segmented image
step_segmented=$(mincinfo ${out_dir}/maps/Seg_temp/magnitude_resamToCsi_bet_pve_1.mnc -attvalue xspace:step -attvalue yspace:step -attvalue zspace:step)

# convert into array
IFS=$'\n' step_segmented=($step_segmented)

## get the needed step size for template resampling
xsteplate=$(echo "scale=5; ${step_segmented[0]}*(${dimlength_magnitude[0]}/${dimlength_csi[0]})" | bc -l | xargs printf "%1.3f")
ysteplate=$(echo "scale=5; ${step_segmented[1]}*(${dimlength_magnitude[1]}/${dimlength_csi[1]})" | bc -l | xargs printf "%1.3f")
zsteplate=$(echo "scale=5; ${step_segmented[2]}*(${dimlength_magnitude[2]}/${dimlength_csi[2]})" | bc -l | xargs printf "%1.3f")

#xsteplate=$(echo "scale=5; ${step_csi[0]}" | bc -l | xargs printf "%1.3f")
#ysteplate=$(echo "scale=5; ${step_csi[1]}" | bc -l | xargs printf "%1.3f")
#zsteplate=$(echo "scale=5; ${step_csi[2]}" | bc -l | xargs printf "%1.3f")

echo -e "\n\n0. Create last templates\n\n"
#mincresample -nelements ${dimlength_csi[*]} -xstep $xsteplate -ystep $ysteplate -zstep $zsteplate ${out_dir}/maps/magnitude_resamToCsi_bet_pve_0.mnc ${out_dir}/maps/template_bet_pve_0.mnc

#read -p "Stop before fucking up"

#mincresample -nelements ${dimlength_csi[*]} -xstep $xsteplate -ystep $ysteplate -zstep $zsteplate ${out_dir}/maps/Seg_temp/magnitude_resamToCsi_bet_pve_0.mnc ${out_dir}/maps/Seg_temp/template_bet_pve_0.mnc
mincresample -nelements ${dimlength_csi[*]} -xstep $xsteplate -ystep $ysteplate -zstep $zsteplate ${out_dir}/maps/Seg_temp/magnitude_resamToCsi_bet_pve_1.mnc ${out_dir}/maps/Seg_temp/template_bet_pve_1.mnc
mincresample -nelements ${dimlength_csi[*]} -xstep $xsteplate -ystep $ysteplate -zstep $zsteplate ${out_dir}/maps/Seg_temp/magnitude_resamToCsi_bet_pve_2.mnc ${out_dir}/maps/Seg_temp/template_bet_pve_2.mnc





