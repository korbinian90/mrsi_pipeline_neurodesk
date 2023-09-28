#!/bin/bash

# Create Mincfiles out of raw files
# Find the first .mnc file and save its name (to be used as a template)
csilate=$(ls ${out_dir}/maps/Orig | find ${out_dir}/maps/Orig . -name '*.mnc' | head -1)



# From magnitude.mnc - read the information needed for converting from raw to mnc
step_magnitude=$(mincinfo ${out_dir}/maps/magnitude.mnc -attvalue xspace:step -attvalue yspace:step -attvalue zspace:step)
step_csi=$(mincinfo $csilate -attvalue xspace:step -attvalue yspace:step -attvalue zspace:step)
dircos_magnitude=$(mincinfo ${out_dir}/maps/magnitude.mnc -attvalue xspace:direction_cosines -attvalue yspace:direction_cosines -attvalue zspace:direction_cosines)
start_magnitude=$(mincinfo ${out_dir}/maps/magnitude.mnc -attvalue xspace:start -attvalue yspace:start -attvalue zspace:start)
dimlength_csi=$(mincinfo $csilate -dimlength xspace -dimlength yspace -dimlength zspace)
dircos_csi=$(mincinfo $csilate -attvalue xspace:direction_cosines -attvalue yspace:direction_cosines -attvalue zspace:direction_cosines)
dimlength_magnitude=$(mincinfo ${out_dir}/maps/magnitude.mnc -dimlength xspace -dimlength yspace -dimlength zspace)

# Convert variables into arrays
IFS=$'\n' step_magnitude=($step_magnitude)
IFS=$'\n' step_csi=($step_csi)
IFS=$'\n' dircos_magnitude=($dircos_magnitude)
IFS=$'\n' dircos_csi=($dircos_csi)
IFS=$'\n' dimlength_csi=($dimlength_csi)
IFS=$'\n' dimlength_magnitude=($dimlength_magnitude)
IFS=$'\n' start_magnitude=($start_magnitude)


xstep_seg=$(echo "scale=5; ${dimlength_magnitude[0]}*${step_magnitude[0]}/${dimlength_csi[0]}" | bc -l | xargs printf "%1.3f")
ystep_seg=$(echo "scale=5; ${dimlength_magnitude[1]}*${step_magnitude[1]}/${dimlength_csi[1]}" | bc -l | xargs printf "%1.3f")
zstep_seg=$(echo "scale=5; ${step_magnitude[2]}" | bc -l | xargs printf "%1.3f")
#xstep_seg=$(echo "scale=5; ${step_csi[0]}" | bc -l | xargs printf "%1.3f")
#ystep_seg=$(echo "scale=5; ${step_csi[1]}" | bc -l | xargs printf "%1.3f")

xstart=$(echo "scale=5; ${start_magnitude[0]}" | bc -l | xargs printf "%1.3f")
ystart=$(echo "scale=5; ${start_magnitude[1]}" | bc -l | xargs printf "%1.3f")
zstart=$(echo "scale=5; ${start_magnitude[2]}" | bc -l | xargs printf "%1.3f")


# Convert output of segmentation_simple.m from raw to mnc
#WM
echo "rawtominc -float -clobber -input ${out_dir}/maps/Seg_temp/WM_CSI_map.raw  ${out_dir}/maps/WM_CSI_map.mnc -xstep $xstep_seg -ystep $ystep_seg -zstep $zstep_seg -xstart $xstart -ystart $ystart -zstart $zstart -xdircos ${dircos_csi[0]} -ydircos ${dircos_csi[1]} -zdircos ${dircos_csi[2]} ${dimlength_magnitude[2]} ${dimlength_csi[1]} ${dimlength_csi[0]}" > ${out_dir}/maps/Seg_temp/RtoM_WM.txt
#GM
echo "rawtominc -float -clobber -input ${out_dir}/maps/Seg_temp/GM_CSI_map.raw  ${out_dir}/maps/GM_CSI_map.mnc -xstep $xstep_seg -ystep $ystep_seg -zstep $zstep_seg -xstart $xstart -ystart $ystart -zstart $zstart -xdircos ${dircos_csi[0]} -ydircos ${dircos_csi[1]} -zdircos ${dircos_csi[2]} ${dimlength_magnitude[2]} ${dimlength_csi[1]} ${dimlength_csi[0]}" > ${out_dir}/maps/Seg_temp/RtoM_GM.txt
#CSF
echo "rawtominc -float -clobber -input ${out_dir}/maps/Seg_temp/CSF_CSI_map.raw  ${out_dir}/maps/CSF_CSI_map.mnc -xstep $xstep_seg -ystep $ystep_seg -zstep $zstep_seg -xstart $xstart -ystart $ystart -zstart $zstart -xdircos ${dircos_csi[0]} -ydircos ${dircos_csi[1]} -zdircos ${dircos_csi[2]} ${dimlength_magnitude[2]} ${dimlength_csi[1]} ${dimlength_csi[0]}" > ${out_dir}/maps/Seg_temp/RtoM_CSF.txt

bash ${out_dir}/maps/Seg_temp/RtoM_WM.txt
bash ${out_dir}/maps/Seg_temp/RtoM_GM.txt
bash ${out_dir}/maps/Seg_temp/RtoM_CSF.txt

# Resample to get single segmented slice with the same thickness as MRSI slice
# TODO - Right now, we use mincresample, which is interpolating all slices in segmentation to create thick SI-like slice
# Better approach is only averaging all segmentation slices (maybe it is not a big difference)
########################################################################
########################################################################
# Reorder dimensions and flip the z direction according to metabolic maps
########################################################################
########################################################################
mincreshape -clobber -dimorder xspace,yspace,zspace ${out_dir}/maps/WM_CSI_map.mnc ${out_dir}/maps/Seg_temp/WM_CSI_map_reorder.mnc
mincreshape -clobber -dimorder xspace,yspace,zspace ${out_dir}/maps/GM_CSI_map.mnc ${out_dir}/maps/Seg_temp/GM_CSI_map_reorder.mnc
mincreshape -clobber -dimorder xspace,yspace,zspace ${out_dir}/maps/CSF_CSI_map.mnc ${out_dir}/maps/Seg_temp/CSF_CSI_map_reorder.mnc

mincreshape -clobber +zdirection ${out_dir}/maps/Seg_temp/WM_CSI_map_reorder.mnc ${out_dir}/maps/WM_CSI_map.mnc
mincreshape -clobber +zdirection ${out_dir}/maps/Seg_temp/GM_CSI_map_reorder.mnc ${out_dir}/maps/GM_CSI_map.mnc
mincreshape -clobber +zdirection ${out_dir}/maps/Seg_temp/CSF_CSI_map_reorder.mnc ${out_dir}/maps/CSF_CSI_map.mnc
# Find the attributes
step_seg=$(mincinfo ${out_dir}/maps/WM_CSI_map.mnc -attvalue xspace:step -attvalue yspace:step -attvalue zspace:step)
start_seg=$(mincinfo ${out_dir}/maps/WM_CSI_map.mnc -attvalue xspace:start -attvalue yspace:start -attvalue zspace:start)
# step_csi already defined above
start_csi=$(mincinfo $csilate -attvalue xspace:start -attvalue yspace:start -attvalue zspace:start)

IFS=$'\n' step_seg=($step_seg)
IFS=$'\n' start_seg=($start_seg)
IFS=$'\n' start_csi=($start_csi)


StartPos=$(echo "scale=5; ${start_csi[2]}-${step_csi[2]}/2+${step_seg[2]}" | bc -l | xargs printf "%1.1f")
NumOfSlices=$(echo "scale=5; ${step_csi[2]}/${step_seg[2]}" | bc -l | xargs printf "%1.0f")

dimlength_magnitude=$(mincinfo ${out_dir}/maps/magnitude.mnc -dimlength xspace -dimlength yspace -dimlength zspace)
StartPos_voxel=$(worldtovoxel ${out_dir}/maps/WM_CSI_map.mnc 0 0 $StartPos)

# Create an array
x=( $StartPos_voxel )
eval y=($x)  # For some stupid reason, to create array, I need to run it twice? no idea why
# Round it to be used in next step
step_final=$(echo "scale=5; ${y[2]}" | bc -l | xargs printf "%1.0f") 


# Cut out the slab out of segmentation maps that correspond to MRSI slice thickness
echo "mincreshape -clobber ${out_dir}/maps/WM_CSI_map.mnc ${out_dir}/maps/WM_CSI_map_slab.mnc -dimrange zspace=$step_final,$NumOfSlices" > ${out_dir}/maps/Seg_temp/CutaSlabWM.txt
echo "mincreshape -clobber ${out_dir}/maps/GM_CSI_map.mnc ${out_dir}/maps/GM_CSI_map_slab.mnc -dimrange zspace=$step_final,$NumOfSlices" > ${out_dir}/maps/Seg_temp/CutaSlabGM.txt
echo "mincreshape -clobber ${out_dir}/maps/CSF_CSI_map.mnc ${out_dir}/maps/CSF_CSI_map_slab.mnc -dimrange zspace=$step_final,$NumOfSlices" > ${out_dir}/maps/Seg_temp/CutaSlabCSF.txt

bash ${out_dir}/maps/Seg_temp/CutaSlabWM.txt
bash ${out_dir}/maps/Seg_temp/CutaSlabGM.txt
bash ${out_dir}/maps/Seg_temp/CutaSlabCSF.txt





