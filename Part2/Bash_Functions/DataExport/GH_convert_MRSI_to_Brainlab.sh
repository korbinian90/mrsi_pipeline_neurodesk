#!/bin/bash
# To run this as stand-alone, do this:
# export T1w_path=/path/to/MsmtData/Patients/Pt###/UNI (is UNI correct or should it be INV1, INV2, T1?)
# export out_dir=/path/to/ProcessResults/Pt###
# cd ${out_dir}/maps/
# bash /ceph/mri.meduniwien.ac.at/departments/radiology/mrsbrain/lab/Sourcecode/MRSI_Processing_ReleaseVersions/Part2_Registration_Evaluation_v1.x14.22b/GH_convert_MRSI_to_Brainlab_v3.sh 
#
#
##todo: -run in the cript -parse all niftis

####Converts nii files o dicoms for the BRAINLAB system.

# Color stuff
red=`tput setaf 1`
yel=`tput setaf 3`
resetcolor=`tput sgr0`

cd ${out_dir}/maps/

rm -R -f ./Export_Brainlab
mkdir Export_Brainlab

echo "Searching reference DICOM in this folder: "
echo $T1w_path
echo "First DICOM as reference: "
ls $T1w_path/*.IMA | head -1

DICOM_reference=$(ls $T1w_path/*.IMA | head -1)

# read -p "Stop2.2."

timerstart=`date +%s`

##karawun start
echo "Activating conda's Karawun environment."
source activate KarawunEnv_py36

echo "Starting export."
MAPS=${out_dir}/maps/Export_Neuronav/
importTractography -n ${MAPS}/*.nii.gz -o ./Export_Brainlab/ -d $DICOM_reference

#importTractography --dicom-template Dicom/1.3.12.2.1107.5.2.43.167031.2019040213095021814319052.dcm --nifti Tractography/T1brain.nii.gz Tractography/FAbrain.nii.gz -o /tmp/Conv

echo "Done. Deactivating Karawun environment."
source deactivate KarawunEnv_py36
##karawun end
timerend=`date +%s`
echo "Karawun took around "$((timerend-timerstart))" seconds."

#read -p "Continue?"

#rm -d ./Export_Brainlab/*.nii

if [ -z "$(ls -A ./Export_Brainlab)" ]; then
	echo "${yel}WARNING:${resetcolor} Brainlab export folder appears to be empty!"
else
	echo "DICOM conversion successful. Would you kindly export them to the Brainlab?"
fi


