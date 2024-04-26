#!/bin/bash
#######################################################################
#### WRITE ADDITIONAL ParAMETERS TO ParAMETER2 FILE FOR MATLAB USE ####
#######################################################################


# Open Parameter file
Par2="${tmp_dir}/Parameter2.m"
touch "$Par2"			
chmod 755 "$Par2"


# Writing flags
echo "print_individual_spectra_flag = ${print_individual_spectra_flag};" >> "$Par2"
echo "compute_SNR_flag = ${compute_SNR_flag};" >> "$Par2"
echo "SNR_treshold_flag = ${SNR_treshold_flag};" >> "$Par2"
echo "FWHM_treshold_flag = ${FWHM_treshold_flag};" >> "$Par2"
echo "spectra_stack_flag = ${spectra_stack_flag};" >> "$Par2" #BOW - NOTE - need this to enable stack of spectra output
echo "segmentation_flag = ${segmentation_flag};" >> "$Par2"
echo "nifti_flag = ${nifti_flag};" >> "$Par2"
echo "SpectralMap_flag = ${SpectralMap_flag};" >> "$Par2"
echo "UpsampledMaps_flag = ${UpsampledMaps_flag};" >> "$Par2"
echo "RatioMaps_flag = ${RatioMaps_flag};" >> "$Par2"
echo "local_folder = '${local_folder}';" >> "$Par2"
echo "convert_to_neuronav_flag = ${convert_to_neuronav_flag};" >>"$Par2"
echo "B1_correction_flag = ${B1_correction_flag};" >>"$Par2"

# Dealing with FWHM and SNR (thresholds)
echo "CRLB_treshold_value = ${CRLB_treshold_value};" >> "$Par2"
if [[ $SNR_treshold_flag -eq 1 && $FWHM_treshold_flag -eq 1 ]]; then
	echo "SNR_treshold_value = ${SNR_treshold_value};" >> "$Par2"
	echo "FWHM_treshold_value = ${FWHM_treshold_value};" >> "$Par2"
elif [[ $SNR_treshold_flag -eq 1 ]]; then
	echo "SNR_treshold_value = ${SNR_treshold_value};" >> "$Par2"
elif [[ $FWHM_treshold_flag -eq 1 ]]; then
	echo "FWHM_treshold_value = ${FWHM_treshold_value};" >> "$Par2"
else
	echo "No treshold criteria were set for FWHM or SNR"
fi

#optional
if [[ ${compute_SNR_ControlFile_flag} -eq 1 ]]; then
	echo "compute_SNR_ControlFile = '${compute_SNR_ControlFile}';" >> "$Par2"
fi

if [[ ${nifti_flag} -eq 1 ]]; then
	echo "nifti_options = '${nifti_options}';" >> "$Par2"
fi

if [[ ${spectra_stack_flag} -eq 1 ]]; then
	echo "spectra_stack_range = ${spectra_stack_range};" >> "$Par2"
fi

if [[ ${SpectralMap_flag} -eq 1 ]]; then
	echo "SpectralMap_options = '${SpectralMap_options}';" >> "$Par2"
fi

## Mandatory Input files, Output directory
echo "out_dir = '${out_dir}';" >> "$Par2"





