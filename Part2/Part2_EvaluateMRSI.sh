#!/bin/bash
######################################################################################################################
###   28th January 2013 - change, whole script divided into two smaller parts, first is up to n.7 - postprocessing ###
###   ends up with LC model computation, second (evaluation_split.sh) continues with creation of metabolic maps    ###
######################################################################################################################

# -1. Preparations
# In case you hit ctrl-c, kill all processes, also background processes.
trap "{ TerminateProgram; echo 'Kill all processes due to user request.' ; kill 0; }" SIGINT
TerminateProgram() {
	echo -e "\n\nKill whole process & Backup: "

	cd "$calldir" || exit

	# Copy the logfile
	echo "Copy logfile to ${out_path}/UsedSourcecode/logfile.log."
	if [ -d "${out_path}/UsedSourcecode" ]; then
		cp "$logfile" "${out_path}/UsedSourcecode"
	fi

	echo "Stop tee."
	# close and restore backup; both stdout and stderr
	exec 1<&6 6<&-
	exec 2<&7 2<&-
	# Redirect stderr (2) into stdout (1)
	exec 2>&1
	sleep 1

	if [[ "$1" == "0" ]]; then # DebugFlag = 0
		rmtmpdir="y"
	elif [[ "$1" == "1" ]]; then # DebugFlag = 1
		rmtmpdir="n"
	else # DebugFlag = undefined
		read -rp "Remove $tmp_dir? [y][n]      " rmtmpdir
	fi
	if [[ "$rmtmpdir" == "y" ]] && [[ -n "$tmp_dir" ]]; then
		rm -R -f "$abs_tmp_dir"
		if [[ ! "$local_folder" == "$out_dir" ]]; then
			rm -R -f "$local_folder"
		fi
		if [ -d "$abs_tmp_dir" ]; then
			sleep 10
			rm -R -f "$abs_tmp_dir" # Try again if it didnt work
		fi
	fi
	echo "Stop now."
	echo -e "\n\n\n\t\tE N D\n\n\n"
}

run_matlab() {
	if [[ $compiled_matlab_flag -eq 1 ]]; then
		# run the compiled matlab function
		"$MatlabCompiledFunctions/$1" "$abs_tmp_dir"
	else
		# run the matlab script ($1)
		$matlabp -nodisplay -batch "addpath(genpath('$MatlabFunctionsFolder')); $1('$abs_tmp_dir')"
	fi
}

# -1.0 Debug flag
DebugFlag=0

# -1.1 Install Paths etc.
echo -e "Install Program\n\n"
source "$(dirname "${BASH_SOURCE[0]}")/InstallProgramPaths.sh"

# -1.2 Change to directory of script
calldir=$(pwd)
cd "$(dirname "${BASH_SOURCE[0]}")" || exit

# -1.3 Create directories
tmp_trunk="tmp"
tmp_num=1
tmp_dir="${tmp_folder}/${tmp_trunk}${tmp_num}"
while [ -d "$tmp_dir" ]; do
	((tmp_num = tmp_num + 1))
    tmp_dir="${tmp_folder}/${tmp_trunk}${tmp_num}"
done
export tmp_dir
mkdir "$tmp_dir"
if [ ! -d "$tmp_dir" ]; then
	echo "Could not create temporary directory. Exiting."
	exit 1
fi
chmod 775 "$tmp_dir"
abs_tmp_dir=$(readlink -f "$tmp_dir")

# -1.4 Write the script output to a logfile
logfile=${tmp_dir}/logfile.log
echo -e "Run Script with parameters:\n$0 $*\n\n"
echo -e "Run Script with parameters:\n$0 $*" >"$logfile"

exec 6<&1
exec 7<&2

exec > >(tee -a "$logfile")
exec 2> >(tee -a "$logfile" >&2)

echo -e "\n\n0.\t\tS T A R T"
date

# 1.5.
############# DEFINE ARGUMENTS/PARAMETER OPTIONS ####################

# FLAGS
# mandatory
export out_flag=0 #export so that every child process (like readcsi.sh), grandchild-process etc. can use this variable

# optional
export CRLB_treshold_flag=0
export FWHM_treshold_flag=0
export SNR_treshold_flag=0
export print_individual_spectra_flag=0
export compute_SNR_flag=0
export local_folder_flag=0
export spectra_stack_flag=0
export non_lin_reg_flag=0
export compute_reg_only_flag=0
export segmentation_flag=0
export compute_seg_only_flag=0
export mask_using_CRLBs_flag=0
export nifti_flag=0
export SpectralMap_flag=0
export UpsampledMaps_flag=0
export RatioMaps_flag=0
export T1_and_water_correction_flag=0
export convert_to_brainlab_flag=0
export convert_to_neuronav_flag=0
export T1w_flag=0
export dont_compress_spectra_flag=0
export export_flag=0
export B1_correction_flag=0
export compiled_matlab_flag=0
export dataconversion="00"

# INITIALIZING
# These letters must stay in sync with the options, ":" only for options that consume an argument
while getopts 'o:a:B:d:e:f:k:l:n:N:r:s:S:t:bCKqRTuwx?' OPTION; do
	case $OPTION in

	#mandatory
	o)
		export out_flag=1
		export out_dir="$OPTARG"
		;;

	#optional
	a)
		export compute_SNR_ControlFile_flag=1
		export compute_SNR_ControlFile="$OPTARG"
		;;
	B)
		export B1_correction_flag=1
		export B1_path="$OPTARG"
		;;
	d)
		export compute_SNR_flag=1
		export print_individual_spectra_flag="$OPTARG"
		;;
	e)
		export export_flag=1
		export dataconversion=$OPTARG
		;;
	f)
		export FWHM_treshold_flag=1
		export FWHM_treshold_value="$OPTARG"
		;;
	k)
		export spectra_stack_flag=1
		export spectra_stack_range="$OPTARG"
		;;
	l)
		export local_folder_flag=1
		export local_folder="$OPTARG"
		;;
	n)
		export SNR_treshold_flag=1
		export SNR_treshold_value="$OPTARG"
		;;
	N)
		export nifti_flag=1
		export nifti_options="$OPTARG"
		;;
	r)
		export non_lin_reg_flag=1
		export non_lin_reg_type="$OPTARG"
		;;
	s)
		export CRLB_treshold_flag=1
		export CRLB_treshold_value="$OPTARG"
		;;
	S)
		export SpectralMap_flag=1
		export SpectralMap_options="$OPTARG"
		;;
	t)
		export T1w_flag=1
		export T1w_path="$OPTARG"
		;;

	#flags
	b)
		export segmentation_flag=1
		;;
	C)
		export mask_using_CRLBs_flag=1
		;;
	K)
		export compiled_matlab_flag=1
		;;
	q)
		export compute_seg_only_flag=1
		;;
	R)
		export RatioMaps_flag=1
		;;
	T)
		export T1_and_water_correction_flag=1
		;;
	u)
		export UpsampledMaps_flag=1
		;;
	w)
		export compute_reg_only_flag=1
		;;
	x)
		export dont_compress_spectra_flag=1
		;;

	?)
		printf "
Usage: %s

mandatory:
-o	[output directory]

optional:
-a	[Control file]
		Compute SNR with home-brewed script.
-B	[B1_path]
		If this option is set, B1 correction is performed. Must be set in Part1 too.
-d	[print_indiv..._flag]
		If this option is set, the SNR gets computed by our own program. If the
		print_individual_spectra_flag=1 (by using option -d 1) all spectra for
		computing the SNR are printed.
-e	[export/data conv.]
		Requires double-digit argument that specifies whether brainlab conversion and neuronav conversion are run.
		First digit: Convert to niftis for Brainlab - yes or no?
		Second digit: Convert to neuronav DICOMS - yes (2D), yes (3D), or no.
		Valid arguments are thus 00 02 03 10 12 13. Default is 00.
		Prerequisites: Brainlab conversion requires -t flag, NeuroNav conversion requires -C flag.
-f	[FWHM_treshold_value]
		If this option is set (user set the value of FWHM threshold after the flag),
		FWHM binary mask is computed from LCmodel results
-k	[spectra_stack_range]
		If this option is set, the .Coord files from LCmodel are used to create stacks of spectra
		to visualize the fit in corresponding voxels (results stored in form of .eps)
		user can set the starting point of range for stack of spectra for display purposes (in ppm)
		user can set the ending point of range for stack of spectra for display purposes (in ppm)
		Options: \"['fullrange']\", \"[ppm_start; ppm_end]\"
-l	[local_folder]
		Perform some of the file-heavy tasks in \$local_folder/tmpx (x=1,2,3,...) instead of on \$out_dir
		directly. This is faster, and if \$out_dir is mounted via nfs4, writing directly to \$out_dir
		can lead to timeouts and terrible zombie processes.
-n	[SNR_treshold_value]
		If this option is set (user set the value of SNR threshold after the flag),
		SNR binary mask is computed either for LC model SNR or (if the -d flag is set) for
		custom SNR computation method and LCmodel
-N	[\"Nifti\" or \"Both\"]
		Only create nifti-files. If \"Both\" option is used, create minc and nifti.
		If -N option is not used, creat only mnc files.
-r	[non_lin_reg_type]
		If this option is set, the non-linear registration is computed using minctools
		Options: -r \"MNI305\", \"MNI152\"
-s	[CRLB_treshold_value]
		User can set the treshold value for CRLB in the metabolic maps
-S  [\"Metabo1,Metabo2,Metabo3,...\"]
		Create a nifti-file with a map of the LCModel-spectra and -fits to view with freeview as timeseries.
		Needs freesurfer-linux-centos7_x86_64-dev-20181113-8abd50c, and MATLAB version > R2017b.
		Can only be used with -N option.
		You can pass over a list of metabolites that should be written as spectral maps in addition to the Baseline, Fit and input Spectrum.
		The name of those metabolites has to be exactly as LCModel outputs it, and cannot be a sum like Glu+Gln (LCModel doesnt fit Glx, it just writes out the SD for that).
		Example: -S \"Glu,Gln\".
		Can also output raw-data.
		Example: \"Glu,Gln,Raw-real-csi,Raw-abs-csi_FIDESI\" will output Glu and Gln from LCModel output, 
		and raw-data it will load from CombinedCSI.mat the variable csi and output the real-part of it, and it will load variable csi_FIDESI and output the abs of it.
-t	[T1 images]
		Format: DICOM. Folder of 3d T1-weighted acquisition containing DICOM files. needed for DICOM conversion here

Flags:
-b	Perform segmentation to GM, WM and CSF using bet. (If synthsegp is set, outputs synthseg as well)
-C	Mask using CRLBs.
-K	Use compiled MATLAB functions.
		No MATLAB license needed, but the functions must be compiled first (See compile.m)
-q	Compute Segmentation only.
-R	Create Ratio Maps.
-T	T1 and Water Correction.
		For T1 correction based on presets and WREF correction based on WREF scan in Part 1
		Also estimates metabolite concentrations!
		Needs segmentation, crlb masks
-u	Upsample Maps.
		Create upsampled maps by zero-filling (in future more sophisticated methods might be implemented).
-w	Compute the non-linear registration only.
-x	Do not compress Spectra.
		Previously always on, now choose to NOT compress data using this flag.

" $(basename $0) >&2

		exit 2
		;;
	esac
done

shift $((OPTIND - 1))

if [[ $SpectralMap_flag -eq 1 ]] && [[ $nifti_flag -eq 0 ]]; then
	echo -e "\n\nWARNING: -S (SpectralMap creation) option was used, but -N (Nifti-creation) was not."
	echo -e "This is not supported. Turned -N flag on.\n\n"
	sleep 2s
	export nifti_flag=1
	export nifti_options="Both"
fi

if [[ -z $print_individual_spectra_flag ]]; then
	print_individual_spectra_flag=0
fi
if [[ $CRLB_treshold_flag -eq 0 ]]; then
	export CRLB_treshold_flag=1
	export CRLB_treshold_value=20
fi

if [[ $local_folder_flag -eq 0 ]]; then
	export local_folder=$out_dir
else
	loc_trunk="local"
	loc_num=1
	loc_dir="${local_folder}/${loc_trunk}${loc_num}"
	while [ -d "$loc_dir" ]; do
		((loc_num = loc_num + 1))
		loc_dir="${local_folder}/${loc_trunk}${loc_num}"
	done
	local_folder=$loc_dir
	export local_folder
	mkdir "$local_folder"
	chmod 775 "$local_folder"
fi

# Set Part2 Directory
curdir=$(pwd)
echo ""
echo "Folders Configuration"
echo "curdir: ${curdir}"
echo "local_folder: ${local_folder}"
echo "out_dir: ${out_dir}"
echo "abs_tmp_dir: ${abs_tmp_dir}"

rm -f "${out_dir}/maps/magnitude"*.nii
rm -f "${out_dir}/maps/csi_template"*.nii
rm -f "${out_dir}/maps/mask"*.nii
rm -f "${out_dir}/AlignFreq/AlignFreq"*.nii
rm -f "${out_dir}/maps/BaselineMap.nii.gz" "${out_dir}/maps/FitMap.nii.gz" "${out_dir}/maps/SpectrumMap.nii.gz"
mkdir -p "${out_dir}/maps/Orig"
mkdir -p "${out_dir}/maps/QualityAndOutlier_Clip"
mkdir -p "${out_dir}/maps/Outlier_Clip"
mkdir -p "${out_dir}/maps/Ratio"
mkdir -p "${out_dir}/maps/Extra"

#1.
############ Uncompress CoordFiles and Spectral Files ##############
if ! [[ $compute_reg_only_flag -eq 1 || $compute_seg_only_flag -eq 1 ]]; then # Run only if the whole script is run
	echo -e "\n\n1. Uncompress the coord files\n"
	if [ ! -d "${local_folder}/spectra/CoordFiles" ]; then
		if [ -e "${out_dir}/CoordFiles.tar.gz" ]; then
			printf "\nUncompress Coordfiles ... "
			mkdir -p "${local_folder}/spectra"
			tar xfz "${out_dir}/CoordFiles.tar.gz" -C "${local_folder}/spectra"
			printf "finished."
		fi
	fi
	if [ -d "${out_dir}/spectra/CoordFiles" ]; then
		if [[ ! "$local_folder" == "$out_dir" ]]; then
			mkdir -p "${local_folder}/spectra"
			cp -R "${out_dir}/spectra/CoordFiles" "${local_folder}/spectra/CoordFiles"
		fi
	fi
	if [ -d "${out_dir}/Compressed_Spectra" ]; then
		"${curdir}/Bash_Functions/DataCompression/data_decompression.sh" -s 1 -o "$out_dir"
	fi
	if [ -d "${out_dir}/Compressed_Water_Spectra" ]; then
		"${curdir}/Bash_Functions/DataCompression/data_decompression.sh" -w 1 -o "$out_dir"
	fi
fi

#2.
############ READ CSI PARAMETERS AND I/O FOLDERS INTO PARAMETER FILE FOR MATLAB ############
echo -e "\n\n2. READ CSI PARAMETERS AND I/O FOLDERS\n\n"
bash write_parameter2.sh

#3.
############ CREATE TISSUE CONTRIBUTION IMAGES OUT OF T1 IMAGE ############
if [[ $segmentation_flag -eq 1 ]]; then
	echo -e "\n\n3. CREATE TISSUE CONTRIBUTION IMAGES OUT OF T1 IMAGE \n\n"
	rm -rf "${out_dir}/maps/Seg_temp" 2>/dev/null
	rm -r "${out_dir}/maps/Segmentation/"*.mnc 2>/dev/null
	mkdir -p "${out_dir}/maps/Segmentation" "${out_dir}/maps/Seg_temp" "${out_dir}/maps/Seg_temp/Nifti"

	bash Bash_Functions/Segmentation/segmentation.sh
	if [[ $synthsegp != '' ]]; then
		echo -e "\n\n3.1 RUNNING SYNTHSEG\n\n"
		bash Bash_Functions/Segmentation/synthseg.sh # Using SynthSeg from FreeSurfer 7.4.1
	fi

	run_matlab segmentation_simple

	echo -e "\n\n3. DEBUG -convert templates \n\n"
	bash raw2mnc_seg.sh
	echo -e "\n\n3. DEBUG -end of convert templates \n\n"
fi

# read -rp "Stop before extract_met_maps"

#4.
############ READ LCMODEL RESULTS AND STORE THEM INTO *.raw FILES; CALCULATE B1/T1 CORRECTION ############
if ! [[ $compute_reg_only_flag -eq 1 || $compute_seg_only_flag -eq 1 ]]; then # Run only if the whole script is run
	echo -e "\n\n4. READ LCMODEL RESULTS AND STORE THEM INTO *.raw!\n\n"
	if [ -d "${out_dir}/water_spectra" ]; then
		echo -e "\n\n Read LCModel water results and store them into RAW\n\n"
		echo -e "\n\n Calculate B1/T1 correction \n\n"
		run_matlab extract_met_maps
	fi
	run_matlab extract_met_maps
fi

#5.
############ READ *.coord FILES and create "stacks of spectra" for each slice ############
if ! [[ $compute_reg_only_flag -eq 1 || $compute_seg_only_flag -eq 1 ]]; then # Run only if the whole script is run
	if [[ $spectra_stack_flag -eq 1 ]]; then
		echo -e "\n\n5. READ *.coord FILES AND DISPLAY STACK OF SPECTRA IN *.eps!\n\n"
		mkdir -p "${out_dir}/figures"
		run_matlab extract_spectra
	fi
fi

#6.
############ CONVERT METABOLIC MAPS FROM *.raw TO *.mnc ############
if ! [[ $compute_reg_only_flag -eq 1 || $compute_seg_only_flag -eq 1 ]]; then # Run only if the whole script is run
	echo -e "\n\n6. CONVERT METABOLIC MAPS TO MINC FILES!\n\n"
	bash raw2mnc.sh
fi
# read -rp "Stop After raw2mnc.sh"

#7.
############ PERFORM NON LINEAR REGISTRATION TO 305 MNI BRAIN ############
if [[ $non_lin_reg_flag -eq 1 ]]; then
	echo -e "\n\n7. PERFORM NON LINEAR REGISTRATION TO $non_lin_reg_type ATLAS\n\n"
	bash Bash_Functions/Coreg/coregistration.sh
fi

#8.
############ PERFORM ADDITIONAL MASKING OF METABOLIC MAPS BASED ON SNR/FWHM AND (FROM NAA/CR) CRLBs ############ (FROM METABOLITES)
if [[ $mask_using_CRLBs_flag -eq 1 ]]; then
	echo -e "\n\n8. Generate masked mnc files.\n\n"
	# bash Bash_Functions/Masking/Met_Map_Masking.sh -o "$out_dir" # defaults to "-s 2.5 -f 0.15 -c 40"
	bash Bash_Functions/Masking/GH_MRSI_automatic_map_masking_with_CRLBS_v10.sh
fi

#9.
############ PERFORM T1, B1 correction and water referencing ############
if [[ $T1_and_water_correction_flag -eq 1 ]]; then

	if [[ $mask_using_CRLBs_flag -eq 1 ]]; then
		echo -e "\n\n9. T1 correction, B1 correction and water referencing. \n\n"
		bash Bash_Functions/WREF/GH_T1_WREF_weighting_v2.sh
	else
		echo -e "\n\n9.Please set -C to enable T1/B1 and water reference corrections! Do not forget to enable the segmentation flag too!\n\n"
	fi

fi

#10.
############ Exports and conversions ############
case $dataconversion in
00)
	export convert_to_brainlab_flag=0
	export convert_to_neuronav_flag=0
	;;
02)
	export convert_to_brainlab_flag=0
	export convert_to_neuronav_flag=1
	export convert_to_neuronav_value=2
	;;
03)
	export convert_to_brainlab_flag=0
	export convert_to_neuronav_flag=1
	export convert_to_neuronav_value=3
	;;
10)
	export convert_to_brainlab_flag=1
	export convert_to_neuronav_flag=0
	;;
12)
	export convert_to_brainlab_flag=1
	export convert_to_neuronav_flag=1
	export convert_to_neuronav_value=2
	;;
13)
	export convert_to_brainlab_flag=1
	export convert_to_neuronav_flag=1
	export convert_to_neuronav_value=3
	;;
14)
	export convert_to_brainlab_flag=1
	export convert_to_neuronav_flag=1
	export convert_to_neuronav_value=4
	;;
*) echo "WARNING: Unknown parameter for export_flag. Using default values (convert_to_brainlab_flag=0, convert_to_neuronav_flag=0)." ;;

esac

#### Neuronav conversion (requires the mask_using_CRLBs_flag)
if [[ $convert_to_neuronav_flag -eq 1 ]]; then
	date
	echo -e "\n\n10.1 This is a NIFTI Conversion. Have a nice day! \n\n"
	if [[ $convert_to_neuronav_value -eq 2 ]]; then
		echo -e "Prepare files for neuronav transfer. 2D MODE! \n\n"
		bash Bash_Functions/DataExport/GH_convMRSI_to_MRI_neuronavigation_v5_2D.sh
	elif [[ $convert_to_neuronav_value -eq 3 ]]; then
		echo -e "Prepare files for neuronav transfer. 3D MODE! \n\n"
		bash Bash_Functions/DataExport/GH_convMRSI_to_MRI_neuronavigation_v8_3D.sh
	elif [[ $convert_to_neuronav_value -eq 4 ]]; then
		echo -e "Prepare files for neuronav transfer. 3D MODE! \n\n"
		bash Bash_Functions/DataExport/GH_convMRSI_to_MRI_neuronavigation_v10_3D_includingCEs.sh
	fi
fi

# read -rp "NeuroNav conversion should be done... Please check!"

### Brainlab conversion
if [[ $convert_to_brainlab_flag -eq 1 ]]; then
	date
	echo -e "\n\n10.2 Generate DICOMS for Brainlab from NIFTIs.\n\n"
	if [[ $T1w_flag -eq 1 ]]; then # Skip this script if the T1w_flag is not set to 1
		echo "Starting DICOM Brainlab conversion (T1w_flag=$T1w_flag)."
		bash Bash_Functions/DataExport/GH_convert_MRSI_to_Brainlab.sh
		#read -rp "Brainlab conversion should be done... Please check!"
	else
		echo "Skipping Brainlab conversion because T1w_flag=$T1w_flag."
	fi
fi

# DELETE RATIO MAPS, IF THEY ARE NOT DEMANDED
# In future, probably dont create them at all, instead of first creating them just to delete them afterwards
if [[ $RatioMaps_flag -eq 0 ]]; then
	rm -R "$out_dir/maps/Ratio"
fi

# CONVERT MNC TO NII IF DEMANDED
if [[ $nifti_flag -eq 1 ]]; then
	echo -e "\n\n10.3 Convert MNC to NII if demanded.\n\n"
	if [[ "$nifti_options" == "Nifti" ]]; then # Delete all minc-files
		bash mnc2nii_wholefolder -i "$out_dir" -d "$out_dir/maps $out_dir/AlignFreq"
	else # Do not delete minc-files
		bash mnc2nii_wholefolder -i "$out_dir"
	fi
fi

# read -rp "Stop Before creating SpectralMap."
# Create Spectrum-Nifti files (Nifti-files with the spectrum and Fit as time-courses)
echo -e "\n\nCreate Spectral NiftiMap.\n\n"
if [[ $SpectralMap_flag -eq 1 ]]; then
	run_matlab CreateSpectralNiftiMap
fi

#11.
############ Compress the SNR_Computations/failed and /succeeded folders ############
if [[ $compute_SNR_flag -eq 1 ]]; then
	echo -e "\n\n11. COMPRESS THE SNR COMPUTATION OUTPUT.\n\n"
	# jump to the folder
	cd "${out_dir}/SNR_Computations" || exit
	# Compress it
	tar cfz ./failed_n_succeeded.tar.gz failed succeeded
	# remove the uncompressed stuff
	rm -R ./failed ./succeeded
	# jump back to original folder
	cd "$curdir" || exit
else
	echo -e "\n\n11. COMPRESS the SNR computation output: SKIPPED.\n\n"
fi

#12. Compress the CoordFiles
if [ -d "${local_folder}/spectra/CoordFiles" ]; then
	echo -e "\n\n12. COMPRESS THE CoordFiles.\n\n"
	# jump to the folder
	cd "${local_folder}/spectra" || exit
	# Compress it
	tar cfz "${local_folder}/CoordFiles.tar.gz" CoordFiles
	# remove the uncompressed stuff
	rm -R ./CoordFiles
	if [[ ! "$local_folder" == "$out_dir" ]]; then
		cp "${local_folder}/CoordFiles.tar.gz" "${out_dir}/CoordFiles.tar.gz"
	fi
	# jump back to original folder
	cd "$curdir" || exit
else
	echo -e "\n\n12. COMPRESS the CoordFiles: SKIPPED.\n\n"
fi

#13.
############ Remove Seg_temp ############
echo -e "\n\n13. REMOVE Seg_temp FOLDER.\n\n"
rm -R -f "${out_dir}/maps/Seg_temp"

#14. Compress the Spectra Folders
cd "$curdir" || exit
if [ $dont_compress_spectra_flag -eq 0 ]; then
	echo -e "\n\n14. COMPRESS folders spectra/ and water_spectra/ using data_compression.sh (running in the background).\n\n"
	"${curdir}/Bash_Functions/DataCompression/data_compression.sh" -s 1 -w 1 -o "$out_dir" && echo "Compression of spectra completed." & # v3 -> no output, ampersand -> runs in background
else
	echo -e "\n\n14. COMPRESS folders spectra/ and water_spectra/: SKIPPED.\n\n"
fi

############ WRITE THE SOURCECODE THAT WAS USED TO OUT-DIR ############
echo -e "\n\n15. WRITE THE USED SOURCECODE TO out-dir.\n\n"

# Copy Program where this program lies in
curdir_folder=${curdir##*/}
mkdir -p "$local_folder/UsedSourcecode/$curdir_folder"
rsync -a --skip-compress="*" "$curdir"/* "${local_folder}/UsedSourcecode/${curdir_folder}" --exclude .git --exclude "$tmp_dir" --no-owner --no-group

# Copy Matlab Functions
MatlabFolderFound=$(find "${local_folder}/UsedSourcecode" -maxdepth 2 -type d -name 'Matlab_Functions' | grep -c Matlab_Functions)
if [[ $MatlabFolderFound -eq 0 ]]; then
	rsync -a --skip-compress="*" "$MatlabFunctionsFolder" "${local_folder}/UsedSourcecode" --exclude .git --no-owner --no-group
fi

# Remove all backup-files from UsedSourcecode folder
find "${local_folder}/UsedSourcecode" -name \*.*~ -type f -delete 2>/dev/null
find "${local_folder}/UsedSourcecode" -name \*.git -type d -exec rm -r {} \; 2>/dev/null

# Copy the Parameter2.m file and logfile
cp "${tmp_dir}/Parameter2.m" "${local_folder}/UsedSourcecode/Parameter2.m"
cp "$logfile" "${local_folder}/UsedSourcecode/logfile.log"

# Compress the folder
if [ -e "${out_dir}/UsedSourcecode_Part2.tar.gz" ]; then
	rm "${out_dir}/UsedSourcecode_Part2.tar.gz"
fi
cd "$local_folder" || exit
tar cfz "${local_folder}/UsedSourcecode_Part2.tar.gz" UsedSourcecode
cd "$curdir" || exit

# Delete the uncompressed stuff
rm -R -f "${local_folder}/UsedSourcecode"
if [[ ! "$local_folder" == "$out_dir" ]]; then
	cp "${local_folder}/UsedSourcecode_Part2.tar.gz" "${out_dir}/UsedSourcecode_Part2.tar.gz"
fi

# Copy the logfile and remove the tmp_dir as last step
echo "Copy logfile from ${logfile} to ${local_folder}/logfile_part2.log"
cp "$logfile" "${local_folder}/logfile_part2.log"
rm -R "$abs_tmp_dir"

TerminateProgram $DebugFlag
