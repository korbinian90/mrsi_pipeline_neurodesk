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
	echo "Copy logfile to $out_path/UsedSourcecode/logfile.log."
	if [ -d "$out_path/UsedSourcecode" ]; then
		cp "$logfile" "$out_path/UsedSourcecode"
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

# -1.1 Debug flag
DebugFlag=0

# -1.2 Change to directory of script
calldir=$(pwd)
cd "$(dirname "${BASH_SOURCE[0]}")" || exit

# -1.3 Create directories
tmp_trunk="${calldir}/tmp"
tmp_num=1
tmp_dir="${tmp_trunk}${tmp_num}"
while [ -d "$tmp_dir" ]; do
	((tmp_num = tmp_num + 1))
	tmp_dir="${tmp_trunk}${tmp_num}"
done
export tmp_dir
mkdir "$tmp_dir"
chmod 775 "$tmp_dir"
abs_tmp_dir=$(readlink -f "$tmp_dir")

# -1.4 Write the script output to a logfile
logfile=$tmp_dir/logfile.log
echo -e "Run Script with parameters:\n$0 $*\n\n"
echo -e "Run Script with parameters:\n$0 $*" >"$logfile"

exec 6<&1
exec 7<&2

exec > >(tee -a "$logfile")
exec 2> >(tee -a "$logfile" >&2)

echo -e "\n\n0.\t\tS T A R T"

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
export B1_correction_flag=0

# INITIALIZING

while getopts 'o:d:s:n:f:a:l:k:r:N:B:SuRwbqCT?' OPTION; do # DONT FORGET TO PUT GETOPS BACK IF SOME OF THE FLAGS ARE UNCOMMENTED
	case $OPTION in

	#mandatory
	o)
		export out_flag=1
		export out_dir="$OPTARG"
		;;

	#optional
	d)
		export compute_SNR_flag=1
		export print_individual_spectra_flag="$OPTARG"
		;;
	s)
		export CRLB_treshold_flag=1
		export CRLB_treshold_value="$OPTARG"
		;;
	n)
		export SNR_treshold_flag=1
		export SNR_treshold_value="$OPTARG"
		;;
	f)
		export FWHM_treshold_flag=1
		export FWHM_treshold_value="$OPTARG"
		;;
	a)
		export compute_SNR_ControlFile_flag=1
		export compute_SNR_ControlFile="$OPTARG"
		;;
	l)
		export local_folder_flag=1
		export local_folder="$OPTARG"
		;;
	k)
		export spectra_stack_flag=1
		export spectra_stack_range="$OPTARG"
		;;
	r)
		export non_lin_reg_flag=1
		export non_lin_reg_type="$OPTARG"
		;;
	N)
		export nifti_flag=1
		export nifti_options="$OPTARG"
		;;
	B)
		export B1_correction_flag=1
		export B1_path="$OPTARG"
		;;
	S)
		export SpectralMap_flag=1
		;;
	u)
		export UpsampledMaps_flag=1
		;;
	R)
		export RatioMaps_flag=1
		;;
	w)
		export compute_reg_only_flag=1
		;;
	b)
		export segmentation_flag=1
		;;
	q)
		export compute_seg_only_flag=1
		;;
	C)
		export mask_using_CRLBs_flag=1
		;;
	T)
		export T1_and_water_correction_flag=1
		;;
	?)
		printf "

Usage: %s

mandatory:
-o	[output directory]

optional: 
-d	[print_indiv..._flag]   If this option is set, the SNR gets computed by our own program. If the
				print_individual_spectra_flag=1 (by using option -d 1) all spectra for 
				computing the SNR are printed.
-b      [segmentation_matrix_size]
				If segmentation to GM, WM and CSF should be performed.

-s	[CRLB_treshold_value]	user can set the treshold value for CRLB in the metabolic maps
-n	[SNR_treshold_value]    if this option is set (user set the value of SNR threshold after the flag),
				SNR binary mask is computed either for LC model SNR or (if the -d flag is set) for
				custom SNR computation method and LCmodel            
-f	[FWHM_treshold_value]   if this option is set (user set the value of FWHM threshold after the flag),
				FWHM binary mask is computed from LCmodel results
-a [Control file] Compute SNR with home-brewed script.
-l [local_folder] Perform some of the file-heavy tasks in \$local_folder/tmpx (x=1,2,3,...) instead of on \$out_dir
                 directly. This is faster, and if \$out_dir is mounted via nfs4, writing directly to \$out_dir
                  can lead to timeouts and terrible zombie processes. 
-k	[spectra_stack_range]	if this option is set, the .Coord files from LCmodel are used to create stacks of spectra
				to visualize the fit in corresponding voxels (results stored in form of .eps)
      				user can set the starting point of range for stack of spectra for display purposes (in ppm)
				user can set the ending point of range for stack of spectra for display purposes (in ppm)
				Options: \"['fullrange']\", \"[ppm_start; ppm_end]\"
-r	[non_lin_reg_type]	if this option is set, the non-linear registration is computed using minctools, Options: -r \"MNI305\", \"MNI152\"
-w	[compute_reg_only_flag] If this option is set, only the non-linear registration is computed. 
-q	[compute_seg_only_flag] If this option is set, only the segmentation is computed. 
-C	[mask_using_CRLBs_flag]
-N  [\"Nifti\" or \"Both\"] Only create nifti-files. If \"Both\" option is used, create minc and nifti. If -N option is not used, creat only mnc files.
-B	[B1_path]		If this option is set, B1 correction is performed. Must be set in Part1 too.
-S  [SpectralMap_flag] 		Create a nifti-file with a map of the LCModel-spectra and -fits to view with freeview as timeseries.\nNeeds freesurfer-linux-centos7_x86_64-dev-20181113-8abd50c, and MATLAB version > R2017b. Can only be used with -N option.
-u  [UpsampledMaps_flag]	Create upsampled maps by zero-filling (in future more sophisticated methods might be implemented).
-R  [RatioMaps_flag]		Create Ratio maps.
-T	[T1_and_water_correction_flag] For T1 correction based on presets and WREF correction based on WREF scan in Part 1 - needs segmentation, crlb masks. Also estimates metabolite concentrations!

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
	loc_dir="$local_folder/$loc_trunk$loc_num"
	while [ -d "$loc_dir" ]; do
		((loc_num = loc_num + 1))
		loc_dir="$local_folder/$loc_trunk$loc_num"
	done
	local_folder=$loc_dir
	export local_folder
	mkdir "$local_folder"
	chmod 775 "$local_folder"
fi

# 1. Install Paths etc.
echo -e "\n\n1. Install Program\n\n"
. ./InstallProgramPaths.sh

# Create directories
#if [ ! -d $out_dir ]; then
#	mkdir -p ${out_dir}
#fi

rm -f "$out_dir/maps/magnitude"*.nii
rm -f "$out_dir/maps/csi_template"*.nii
rm -f "$out_dir/maps/mask"*.nii
rm -f "$out_dir/AlignFreq/AlignFreq"*.nii
rm -f "$out_dir/maps/BaselineMap.nii.gz" "$out_dir/maps/FitMap.nii.gz" "$out_dir/maps/SpectrumMap.nii.gz"
mkdir -p "$out_dir/maps/Orig"
mkdir "$out_dir/maps/QualityAndOutlier_Clip"
mkdir "$out_dir/maps/Outlier_Clip"
mkdir "$out_dir/maps/Ratio"
mkdir "$out_dir/maps/Extra"
#1.
############ Uncompress the CoordFiles ##############
if ! [[ $compute_reg_only_flag -eq 1 || $compute_seg_only_flag -eq 1 ]]; then # Run only if the whole script is run
	echo -e "\n\nUncompress the coord files\n\n"
	if [ ! -d "$local_folder/spectra/CoordFiles" ]; then
		if [ -e "$out_dir/CoordFiles.tar.gz" ]; then
			printf "\nUncompress Coordfiles ... "
			mkdir "$local_folder/spectra"
			tar xfz "$out_dir/CoordFiles.tar.gz" -C "$local_folder/spectra"
			wait
			printf "finished."
		fi
	fi
	if [ -d "$out_dir/spectra/CoordFiles" ]; then
		if [[ ! "$local_folder" == "$out_dir" ]]; then
			mkdir "$local_folder/spectra"
			cp -R "$out_dir/spectra/CoordFiles" "$local_folder/spectra/CoordFiles"
		fi
	fi

#if [ -d "$out_dir/water_spectra" ]; then
#echo -e "\n\ Uncompress the water spectra coord files\n\n"

fi

#2.
############ READ CSI PARAMETERS AND I/O FOLDERS INTO PARAMETER FILE FOR MATLAB ############
echo -e "\n\n2. READ CSI PARAMETERS AND I/O FOLDERS\n\n"
./write_parameter2.sh

#3.
############ CREATE TISSUE CONTRIBUTION IMAGES OUT OF T1 IMAGE ############
if [[ $segmentation_flag -eq 1 ]]; then
	echo -e "\n\n3. CREATE TISSUE CONTRIBUTION IMAGES OUT OF T1 IMAGE \n\n" #### WAS SECTION 7 UNTIL 2021-10-18
	rm -rf "$out_dir/maps/Seg_temp" 2>/dev/null
	rm -r "$out_dir/maps/Segmentation/"*.mnc 2>/dev/null
	mkdir -p "$out_dir"/maps/Segmentation "$out_dir"/maps/Seg_temp "$out_dir"/maps/Seg_temp/Nifti

	./segmentation.sh
	# ./synthseg.sh 			# Using SynthSeg from FreeSurfer 7.4.1

	$Matlab_Compiled/segmentation_simple "$abs_tmp_dir"
	echo -e "\n\n4. DEBUG -convert templates \n\n"
	./raw2mnc_seg.sh # PROBLEM
	echo -e "\n\n4. DEBUG -end of convert templates \n\n"
fi

# read -rp "Stop before extract_met_maps"

#4.
############ READ LCMODEL RESULTS AND STORE THEM INTO *.raw FILES ############
if ! [[ $compute_reg_only_flag -eq 1 || $compute_seg_only_flag -eq 1 ]]; then # Run only if the whole script is run
	echo -e "\n\n4. READ LCMODEL RESULTS AND STORE THEM INTO *.raw!\n\n"
	if [ -d "$out_dir/water_spectra" ]; then
		echo -e "\n\n Read LCModel water results and store them into RAW\n\n"
		$Matlab_Compiled/extract_met_maps "$abs_tmp_dir"
	fi
	$Matlab_Compiled/extract_met_maps "$abs_tmp_dir"
fi

#5.
############ READ *.coord FILES and create "stacks of spectra" for each slice ############
if ! [[ $compute_reg_only_flag -eq 1 || $compute_seg_only_flag -eq 1 ]]; then # Run only if the whole script is run
	if [[ $spectra_stack_flag -eq 1 ]]; then
		echo -e "\n\n5. READ *.coord FILES AND DISPLAY STACK OF SPECTRA IN *.eps!\n\n"
		mkdir -p "$out_dir/figures"
		$Matlab_Compiled/extract_spectra "$abs_tmp_dir"
	fi
fi

#6.
############ CONVERT METABOLIC MAPS FROM *.raw TO *.mnc ############
if ! [[ $compute_reg_only_flag -eq 1 || $compute_seg_only_flag -eq 1 ]]; then # Run only if the whole script is run
	echo -e "\n\n6. CONVERT METABOLIC MAPS TO MINC FILES!\n\n"
	./raw2mnc.sh
fi
# read -rp "Stop After raw2mnc.sh"

#7.
############ PERFORM NON LINEAR REGISTRATION TO 305 MNI BRAIN ############
if [[ $non_lin_reg_flag -eq 1 ]]; then
	echo -e "\n\n7. PERFORM NON LINEAR REGISTRATION TO $non_lin_reg_type ATLAS\n\n"
	./coregistration.sh
fi

# read -rp "Stop before CRLB masking"
#8.
############ PERFORM SEGMENTATION AND MASKING with CRLBs ############
if [[ $mask_using_CRLBs_flag -eq 1 ]]; then
	echo -e "\n\n8.A Generate masked mnc files.\n\n"
	./GH_MRSI_automatic_map_masking_with_CRLBS_v10.sh
fi


#9.
############ PERFORM T1, B1 correction and water referencing ############
if [[ $T1_and_water_correction_flag -eq 1 ]]; then

	if [[ $mask_using_CRLBs_flag -eq 1 ]]; then
		echo -e "\n\n9. T1 correction, B1 correction and water referencing. \n\n"
		./GH_T1_WREF_weighting_v2.sh
	else
		echo -e "\n\n9.Please set -C to enable T1/B1 and water reference corrections! Do not forget to enable the segmentation flag too!\n\n"
	fi

fi

# DELETE RATIO MAPS, IF THEY ARE NOT DEMANDED
# In future, probably dont create them at all, instead of first creating them just to delete them afterwards
if [[ $RatioMaps_flag -eq 0 ]]; then
	rm -R "$out_dir/maps/Ratio"
fi

# CONVERT MNC TO NII IF DEMANDED
if [[ $nifti_flag -eq 1 ]]; then
	if [[ "$nifti_options" == "Nifti" ]]; then # Delete all minc-files
		./mnc2nii_wholefolder -i "$out_dir" -d "$out_dir/maps $out_dir/AlignFreq"
	else # Do not delete minc-files
		./mnc2nii_wholefolder -i "$out_dir"
	fi
fi

# Create Spectrum-Nifti files (Nifti-files with the spectrum and Fit as time-courses)
# read -rp "Stop Before creating SpectralMap."
echo -e "\n\nCreate Spectral NiftiMap.\n\n"
if [[ $SpectralMap_flag -eq 1 ]]; then
	$Matlab_Compiled/CreateSpectralNiftiMap "$abs_tmp_dir"
fi

# 7.
############ WRITE THE SOURCECODE THAT WAS USED TO OUT-DIR ############
echo -e "\n\nWRITE THE USED SOURCECODE TO out-dir.\n\n"

# # Copy Program where this program lies in
# curdir=$(pwd)
# curdir_folder=${curdir##*/}
# mkdir -p "$local_folder/UsedSourcecode/$curdir_folder"
# rsync -a --skip-compress="*" $curdir/* $local_folder/UsedSourcecode/$curdir_folder --exclude .git --exclude ${tmp_dir}
# #rm -R $out_dir/UsedSourcecode/$curdir_folder/${tmp_dir}

# # Copy Matlab Functions
# MatlabFolderFound=$(find $local_folder/UsedSourcecode -maxdepth 2 -type d -name 'Matlab_Functions' | grep -c Matlab_Functions)
# if [[ $MatlabFolderFound -eq 0 ]]; then
# 	rsync -a --skip-compress="*" $MatlabFunctionsFolder $local_folder/UsedSourcecode --exclude .git
# fi

# ## Copy the Run-files one level above the program
# #abovecurdir=${curdir%/*}	# Delete the thing that follows the last /
# #cp $abovecurdir/Run*.sh $out_dir/UsedSourcecode

# # Copy the logfile
# cp $logfile $local_folder/UsedSourcecode

# # Copy the Parameter2.m file
# cp ${tmp_dir}/Parameter2.m $local_folder/UsedSourcecode/Parameter2.m
# # Remove all backup-files
# find $local_folder/UsedSourcecode -name \*.*~ -type f -delete 2> /dev/null
# find $local_folder/UsedSourcecode -name \*.git -type d -exec rm -r {} \; 2> /dev/null
# # Compress the folder
# if [ -e $out_dir/UsedSourcecode_Part2.tar.gz ]; then
# 	rm $out_dir/UsedSourcecode_Part2.tar.gz
# fi
# cd $local_folder

# tar cfz $local_folder/UsedSourcecode_Part2.tar.gz UsedSourcecode
# # Go back to the original folder
# cd $curdir
# # Delete the uncompressed stuff
# rm -R -f $local_folder/UsedSourcecode
# if [[ ! "$local_folder" == "$out_dir" ]]; then
# 	cp $local_folder/UsedSourcecode_Part2.tar.gz $out_dir/UsedSourcecode_Part2.tar.gz
# fi

#8. Compress the SNR_Computations/failed and /succeeded folders
if [[ $compute_SNR_flag -eq 1 ]]; then
	echo -e "\n\nCOMPRESS THE SNR COMPUTATION OUTPUT.\n\n"
	# jump to the folder
	cd "$out_dir/SNR_Computations" || exit
	# Compress it
	tar cfz ./failed_n_succeeded.tar.gz failed succeeded
	# remove the uncompressed stuff
	rm -R ./failed ./succeeded
	# jump back to original folder
	cd "$curdir" || exit
fi

#9. Compress the CoordFiles
if [ -d "$local_folder/spectra/CoordFiles" ]; then
	echo -e "\n\nCOMPRESS THE CoordFiles.\n\n"
	# jump to the folder
	cd "$local_folder/spectra" || exit
	# Compress it
	tar cfz "$local_folder/CoordFiles.tar.gz" CoordFiles
	# remove the uncompressed stuff
	rm -R ./CoordFiles
	if [[ ! "$local_folder" == "$out_dir" ]]; then
		cp "$local_folder/CoordFiles.tar.gz" "$out_dir/CoordFiles.tar.gz"
	fi
	# jump back to original folder
	cd "$curdir" || exit
fi

echo -e "\n\nREMOVE Seg_temp FOLDER.\n\n"

rm -R -f "$out_dir/maps/Seg_temp"

TerminateProgram $DebugFlag
