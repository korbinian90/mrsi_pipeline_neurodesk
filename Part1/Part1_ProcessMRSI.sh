#!/bin/bash
###################################################################################################
###	Process 2D/3D/Multislice CSI data, prepare them for LCModel Processing and start LCModel	###
###	   Data can be miltichannel data in which case GRE/reference imaging data is used to	###
###	                             combine the individual channels.	      		  	###
###	Data can also be undersampled, in which case GRAPPA-based 2D-Caipirinha and 1D-Caipirinha	###
###						algorithms are used for Reco.						###
###################################################################################################


# -1. Preparations
# In case you hit ctrl-c, kill all processes, also background processes. Trap all exit signals and the SIGUSR1 signal.
trap "{ Trapped=1; echo Try to kill: PID: $$, PPID: $PPID; TerminateProgram; echo 'Kill all processes due to user request.'; sleep 3s; kill 0;}" SIGINT SIGUSR1
TerminateProgram(){


	echo "Stop tee."
	# close and restore backup; both stdout and stderr

	exec 1>&6 # duplicate 6 to 1 again
	exec 6>&- # close 6
	exec 2>&7 # duplicate 7 to 2 again
	exec 7>&- # close 7
	sleep 1

	echo -e "\n\nTerminate Program & Backup: "

	cd $calldir

	# Copy the logfile
	echo "Copy logfile to $out_path/UsedSourcecode/logfile.log."
	if [ -d $out_path/UsedSourcecode ]; then
		cp $logfile $out_path/UsedSourcecode
		cp $tmp_dir/ErrorFile.sh $out_path/UsedSourcecode
	fi


	if [ -f "$out_path/TempServerDir/KillLCMProcesses.sh" ]; then
		if [[ $RunLCModelOn == "" ]] || [[ $CurrentComputer == $RunLCModelOn ]]; then
			$out_path/TempServerDir/KillLCMProcesses.sh														# kill locally
		else
			if [[ $RunLCModelAs == "" ]]; then
				ssh -o PasswordAuthentication=no $RunLCModelOn "$out_path/TempServerDir/KillLCMProcesses.sh"
			else
				ssh -o PasswordAuthentication=no -l $RunLCModelAs $RunLCModelOn "$out_path/TempServerDir/KillLCMProcesses.sh"
			fi
		fi
	fi
	rm -fR $out_path/TempServerDir

	if [[ "$1" == "1" ]]; then		# DebugFlag = 1
		rmtmpdir="n"
	else
		rmtmpdir="y"		
	fi
	echo -e "\n$rmtmpdir"
	if [[ "$rmtmpdir" == "y" ]]; then

		if [ -n "${pid_list[1]}" ]; then
			echo "Wait for all LCModel Processes to terminate gracefully."
			sleep 40		# So that all lcmodel processes can close
		fi

		rm -R -f "$( dirname "${BASH_SOURCE[0]}" )/$tmp_dir"
		if [ -d "$( dirname "${BASH_SOURCE[0]}" )/$tmp_dir" ]; then
			sleep 10
			rm -R -f "$( dirname "${BASH_SOURCE[0]}" )/$tmp_dir"		# Try again if it didnt work
		fi
	fi
	echo "Stop now."
	echo -e "\n\n\n\t\tE N D\n\n\n"

	if [[ "$Trapped" == "0" ]]; then
		exit 0;
	fi
}

# -1.1 Debug flag
DebugFlag=0
Trapped=0


# -1.2 Change to directory of script
calldir=$(pwd)
cd "$( dirname "${BASH_SOURCE[0]}" )"


# -1.3 Create directories
tmp_trunk="tmp"
tmp_num=1
tmp_dir="${tmp_trunk}${tmp_num}"
while [ -d "$tmp_dir" ]; do
	let tmp_num=tmp_num+1
	tmp_dir="${tmp_trunk}${tmp_num}"	
done
export tmp_dir
mkdir $tmp_dir
chmod 775 $tmp_dir
abs_tmp_dir=$(readlink -f $tmp_dir)


# -1.4 Write the script output to a logfile
logfile=${tmp_dir}/logfile.log
hostyy=$(hostname)
echo -e "Run Script on $hostyy with parameters:\n$0 $*\n\n"
echo -e "Run Script on $hostyy with parameters:\n$0 $*" > $logfile


# backup the original filedescriptors, first
# stdout (1) into fd6; stderr (2) into fd7
exec 6<&1							# Copy 1 to 6
exec 7<&2							# Copy 2 to 7
exec > >(tee -a $logfile)			# Copy 1 to tee which writes to logfile
exec 2> >(tee -a $logfile >&2)		# Copy 2 to tee which writes to logfile and redirect to 1 and 2 [???]





echo -e "\n\n0.\t\tS T A R T (PID $$, PPID $PPID)"
sleep 3s;
# 0.
############# DEFINE ARGUMENTS/PARAMETER OPTIONS ####################


# FLAGS
# mandatory
export csi_flag=0 			   #export so that every child process (like readcsi.sh), grandchild-process etc. can use this variable
export basis_flag=0
export out_flag=0

# optional
export image_normal_flag=0  			 
export image_flip_flag=0
export image_VC_flag=0
export T1w_flag=0
export T1w_AntiNoise_flag=0
export WaterReference_flag=0
export mask_flag=0
export hamming_flag=0
export LipidDecon_flag=0
export TwoDCaipParallelImaging_flag=0
export SliceParallelImaging_flag=0
export noisedecorrelation_flag=0
export FirstOrderPhaseCorr_flag=0
export use_phantom_flag=0
export ZeroFillMetMaps_flag=0
export InterpolateCSIResolution_flag=0
export AlignFrequency_flag=0
export dont_compute_LCM_flag=0
export LCM_ControlPath_flag=0
export LCM_ControlPath_Water_flag=0
export exponential_filter_Hz_flag=0
export control_echo_flag=0
export basis_echo_flag=0
export XPACE_motion_correction_flag=0
export julia_reconstruction=0
export old_dat_file_flag=0


# INITIALIZING
export phase_encoding_direction_is_RL_flag=0
export phase_encoding_direction_is="AP"
LipidDecon_MethodAndNoOfLoops="L1,10"
export julia_n_threads="auto"
export julia_mmap="false"


while getopts 'c:b:o:i:f:v:t:a:w:W:m:h:L:r:R:g:Fuz:I:A:lj:e:B:J:X:s:d?' OPTION
do
	case $OPTION in

#mandatory
	  c)	export csi_flag=1
			export csi_path="$OPTARG"
			;;
	  b)	export basis_flag=1
			export basis_path="$OPTARG"
			;;
	  o)	export out_flag=1
			export out_path="$OPTARG"
			;;


#optional
	  i)	export image_normal_flag=1				
			export image_normal_path="$OPTARG"
			;;
	  f)	export image_flip_flag=1				
			export image_flip_path="$OPTARG"
			;;
	  v)	export image_VC_flag=1
			export image_VC_path="$OPTARG"
			;;
	  t)	export T1w_flag=1
			export T1w_path="$OPTARG"
			;;
	  a)	export T1w_AntiNoise_flag=1
	  		export T1w_AntiNoise_path="$OPTARG"
	  		;;
	  w)	export WaterReference_flag=1
	  		export WaterReference_MethodAndFile="$OPTARG"
	  		;;
	  W)	export LCM_ControlPath_Water_flag=1
	  		export LCM_Control_Water_path="$OPTARG"
	  		;;
	  m)	export mask_flag=1
			export mask_method="$OPTARG"
			;;
	  h)	export hamming_flag=1
			export hamming_factor="$OPTARG"
			;;
	  L)	export LipidDecon_flag=1
			export LipidDecon_MethodAndNoOfLoops="$OPTARG"
			;;
	  r)	export TwoDCaipParallelImaging_flag=1
			export InPlaneCaipPattern_And_VD_Radius="$OPTARG"
			;;
	  R)	export SliceParallelImaging_flag=1
			export SliceAliasingPattern="$OPTARG"
			;;
	  g)	export noisedecorrelation_flag=1
			export noisedecorrelation_path="$OPTARG"
			;;
	  F)	export FirstOrderPhaseCorr_flag=1
	  		;;
	  u)	export use_phantom_flag=1
			;;
	  z)	export ZeroFillMetMaps_flag=1	
			export ZeroFillMetMaps="$OPTARG"
			;;
	  I)	export InterpolateCSIResolution_flag=1
			export InterpolateCSIResolution="$OPTARG"
			;;
	  A)	export AlignFrequency_flag=1
			export AlignFrequency_path="$OPTARG"
			;;
	  l)	export dont_compute_LCM_flag=1
			;;
	  j)	export LCM_ControlPath_flag=1
			export LCM_ControlPath="$OPTARG"
			;;
	  e)	export exponential_filter_Hz_flag=1
			export exponential_filter_Hz="$OPTARG"
			;;
	  B)	export basis_echo_flag=1
			export basis_echo_path="$OPTARG"
			;;
	  J)	export control_echo_flag=1
			export control_echo_path="$OPTARG"
			;;
	  X)	export XPACE_motion_correction_flag=1
			export XPACE_motion_correction_path="$OPTARG"
			;;
	  s)	export julia_reconstruction=1
	  		export julia_n_threads="$OPTARG"
			julia_mmap=${!OPTIND}
			if [[ -z $julia_mmap ]]; then
				julia_mmap="false"
			fi
	  		;;
	  d)	export old_dat_file_flag=1
	  		;;
	  ?)	printf "

Usage: %s

mandatory:
-c	[csi file]			Format: DAT, DICOM, or .mat. If a .mat file is passed over, it is expected that everything is already performed like coil combination etc.
						You can pass over several files of the same type by \'-c \"[csi_path1] [csi_path2] ...\"\'. These files get individually processed and averaged
						at the end.
-b	[basis files]		Format: .BASIS. Used for LCM fitting (for FID)
-B	[basis files]		Format: .BASIS. Used for LCM fitting (spin echo: for fidesi =  fid + echo)
-o	[output directory]

optional: 
-i	[image NORMAL]		Format: DAT or DICOM. The FoV must match that of the CSI file. Used for our coil combination and for creating mask (if no T1 is inputted)
-f	[image FLIP]		Format: DAT or DICOM. Imaging file FLIP (FOV rotated about -180 deg). Used for correcting gradient delays.
-v	[VC image]	      	Format: DAT or DICOM. Image of volume or body coil file. Used for sensmap method or for creating mask.
-t	[T1 images] 		Format: DICOM. Folder of 3d T1-weighted acquisition containing DICOM files. Used for creating mask and for visual purposes. If minc file is given instead of folder, it is treated as the magnitude file.
-a	[T1 AntiNoise images]	Format: DICOM. Folder of 3d T1-weighted acquisition containing DICOM files. Used for pre-masking the T1w image to get rid of the noise in air-areas.
-w	[Water Reference]	Format: DAT or DICOM. LCModel 'Do Water Scaling' or separate water quantification (Water maps are created). The same scan as -c [csi file], but without water suppression.
-m	[mask]			Defines how to create the mask. Options: -m \"bet\", \"thresh\", \"voi\", \"[Path_to_usermade_mask]\". If not set --> no mask used.
-h 	[100]               	Hamming filter CSI data.
-r 	[InPlaneCaipPattern_And_VD_Radius]	The InPlaneCaipPattern and the VD_Radius as used in ParallelImagingSimReco.m. Example: \"InPlaneCaipPattern = [0 0 0; 0 0 0; 0 0 1]; VD_Radius = 2;\". 
-R 	[SliceAliasingPattern]
-g 	[noisedecorr_path]	If this option is used the csi data gets noise decorrelated using noise from passed-over noise file, or if -g \" is given, by noise from the end of the FIDs at the border of the FoV or from the PRESCAN, if available. 
-F  [Nothing]               If this option is set, the spectra are corrected for the first order phase caused by an acquisition delay of the FID-sequences. You must provide a basis set with an appropriate acquisition delay. DONT USE WITH SPIN ECHO SEQUENCES.
-u	[Nothing]               If a phantom was measured. Different settings used for fitting (e.g. some metabolites are omitted)
-I	[\"nextpow2\" Or Vector]If nextpow2: Perform zerofilling to the next power of 2 in ROW and COL dimensions (e.g. from 42x42 to 64x64). If vector (e.g. [16 16 1]): Spatially Interpolate to this size.
-A	[\"\" Or Path]          Perform frequency alignment. If a mnc file is given, use these as B0-map, otherwise shift according to water peak of center voxel.
-l	[Nothing]               If this option is set, LCModel is not started, everything else is done normally. Useful for only computing the SNR.
-j	[LCM_ControlFile]       ControlFile telling LCModel how to process the data. for FID
-J	[LCM_ControlFile]       ControlFile telling LCModel how to process the data. for ECHO
-X	[XPACE MOTION LOG]       XPACE MOTION LOG
							otherwise standard values are assumed. A template file is provided in this package.
-e	[LineBroadeningInHz]    Apply an exponential filter to the spectra [Hz].
-s	[threads] [mmap] 		Use the Julia reconstruction version (less RAM usage, different reconstruction algorithm). [threads=auto] can be auto or a number. [mmap=false] can be \"true\", \"false\" or a path.
-d  [Nothing]				Use the deprecated, old dat file format (before sequence merging, 06/2023)

" $(basename $0) >&2

			exit 2
			;;
	esac
done


shift $(($OPTIND - 1))


###0. GH: measure time elapsed:

START=$(date +%s.%N)



# 1. Install Paths etc.
echo -e "\n\n1. Install Program\n\n" 
 . ./InstallProgramPaths.sh



# 2. Create Out Directories
rm -R ${out_path}/*.mat; rm -R ${out_path}/scalings/*.mat
mkdir -p ${out_path}/maps
mkdir ${out_path}/phamaps
mkdir ${out_path}/spectra
mkdir ${out_path}/scalings



#if [ -d "$out_path" ]; then
#	echo -e "\n\nWARNING: The directory\n$out_path\ndoes exist.\nd\t...\tdelete directory,\nc\t...\tcontinue with process without deleting (overwrite files),\ne\t...\tstop program\n\n"
#	read Proceed
#	if [[ "$Proceed" == "d" ]]; then
#		rm -r $out_path
#	elif [[ "$Proceed" == "e" ]]; then
#		exit
#	fi
#fi




# 3. Write Initial Parameters

echo -e "\n\n3. Write Initial Parameters\n\n" 
 . ./write_InitialParameters.sh



#read -p "Stop before Gathering info."
# 4.
############ CREATE TEMPLATES FOR CREATING METABOLIC MAPS LATER ############

echo -e "\n\n4. Gather Information, Create Minc Templates, Prepare Mask Creation.\n\n" 
if [[ $LCM_ControlPath_Water_flag -eq 1 ]]; then		# Run it twice for water referencing (it will automatically process the water ref file the first time, and the other the second time)
								# The condition is fulfilled if Control file for water is set - W2 water reference processing
	$Matlab_Compiled/GetPar_CreateTempl_MaskPart1 $abs_tmp_dir
fi

$Matlab_Compiled/GetPar_CreateTempl_MaskPart1 $abs_tmp_dir
 . ${tmp_dir}/ErrorFile.sh
if [[ $ErrorInGetPar_CreateTempl -eq 1 ]]; then
	TerminateProgram $DebugFlag
fi

#read -p "stop before create minc template"
bash ${tmp_dir}/CreateMincTemplates.sh




#read -p "Stop before creating mask."
## 5.
############# USE MASK OR CREATE MASK OUT OF (IN PRIORITY ORDER): MASK, T1_MAP, IMAGING AC, IMAGING VC, CSI ############

echo -e "\n\n5. CREATE MASK\n\n" 
./create_mask.sh


#read -p "Stop before MRSI_Reconstruction.m"
# 6.
###########   Process Data, Prepare LCModel Fitting   ############
echo -e "\n\n\n6. Process Data and Prepare LCModel Processing\n\n"
if [[ $julia_reconstruction -eq 1 ]]; then
	if [[ $LipidDecon_flag -eq 1 ]]; then
		julia_decon=$LipidDecon_MethodAndNoOfLoops
	else
		julia_decon="false"
	fi
	echo -e "\nMRSI.jl reconstruction"
	julia --threads=$julia_n_threads julia_reco.jl $old_dat_file_flag $csi_path $tmp_dir $out_path $julia_decon $julia_mmap
	echo -e "\nWriting LCM files"
	$Matlab_Compiled/julia_write_lcm_files $abs_tmp_dir
else
	if [[ $WaterReference_flag -eq 1 ]]; then		# Run it twice for water referencing (it will automatically process the water ref file the first time, and the other the second time)
		echo -e "\nProcess water reference data for water scaling."
		echo -e "\n\nRunning:\n"; echo "\"$Matlab_Compiled/MRSI_Reconstruction $abs_tmp_dir 1\""
		$Matlab_Compiled/MRSI_Reconstruction $abs_tmp_dir 1
	fi
	echo -e "\n\nRunning:\n"; echo "\"$Matlab_Compiled/MRSI_Reconstruction $abs_tmp_dir 1\""
	$Matlab_Compiled/MRSI_Reconstruction $abs_tmp_dir 1 # If we pass over several IMA or dat files, average them
fi



#read -p "Stop before LCModel fitting"
#7.
########### START LCMODEL PROCESSING OF SINGLE VOXEL DATA ON CPU CORES ############
if [[ $dont_compute_LCM_flag -eq 0 ]]; then
	curdir=$(pwd)
	CurrentComputer=$(hostname)
	if [[ $RunLCModelOn == "" ]] || [[ $CurrentComputer == $RunLCModelOn ]]; then
		./RunLCModel.sh $RunLCModelOn $tmp_dir														# Run LCModel locally
	else
		rm -fR $out_path/TempServerDir
		cp -R $tmp_dir/ $out_path/TempServerDir; RunFileOnServer=$out_path/TempServerDir/RunLCModel.sh; cp $curdir/RunLCModel.sh $RunFileOnServer
		if [[ $RunLCModelAs == "" ]]; then																									 # Run LCModel on different computer,
			ssh -o PasswordAuthentication=no $RunLCModelOn "$RunFileOnServer $RunLCModelOn $out_path/TempServerDir"					 # connecting via ssh. You need 
		else																																 # a key so that you can
			ssh -o PasswordAuthentication=no -l $RunLCModelAs $RunLCModelOn "$RunFileOnServer $RunLCModelOn $out_path/TempServerDir" # automatically connect to this computer,
		fi																																	 # without needing to type in the password!
		sleep 40
		rm -fR $out_path/TempServerDir
	fi
	sleep 10
fi



#8a: GH: finish time measurement
END=$(date +%s.%N)
DIFF=$(echo "$END - $START" | bc)
echo -e "\n\n8. Total Processing time of Part 1: " $DIFF "\n\n"



# # 8.
# ############ WRITE THE SOURCECODE THAT WAS USED TO OUT-DIR ############
# echo -e "\n\n8. Write the used sourcecode to out-dir.\n\n"

# # Copy Program where this program lies in
# curdir=$(pwd)
# curdir_folder=${curdir##*/}
# mkdir -p "$out_path/UsedSourcecode/$curdir_folder"
# cp -R $curdir/* $out_path/UsedSourcecode/$curdir_folder
# rm -R $out_path/UsedSourcecode/$curdir_folder/${tmp_dir}

# ## Copy the Run-files one level above the program
# #abovecurdir=${curdir%/*}	# Delete the thing that follows the last /
# #cp $abovecurdir/*.sh $out_path/UsedSourcecode

# # Copy the logfile
# cp $logfile $out_path/UsedSourcecode

# # Copy Matlab Functions
# MatlabFolderFound=$(find $out_path/UsedSourcecode -maxdepth 2 -type d -name 'Matlab_Functions' | grep -c Matlab_Functions)
# if [[ $MatlabFolderFound -eq 0 ]]; then
# 	cp -R $MatlabFunctionsFolder $out_path/UsedSourcecode
# fi

# ## Remove all backup-files and git-folders
# #find $out_path/UsedSourcecode -name \*.*~ -type f -delete 2> /dev/null
# #find $out_path/UsedSourcecode -name \*.git -type d -exec rm -r {} \; 2> /dev/null

# # Compress the folder
# if [ -e $out_path/UsedSourcecode_Part1.tar.gz ]; then
# 	rm $out_path/UsedSourcecode_Part1.tar.gz
# fi
# cd $out_path
# tar cfz $out_path/UsedSourcecode_Part1.tar.gz UsedSourcecode

# # Go back to the original folder
# cd $curdir

# # Delete the unzipped stuff
# rm -R -f $out_path/UsedSourcecode




#9.
############ REMOVE UNECESSARY DATA ############
if [[ $DebugFlag -eq 0 ]]; then
	echo -e "\n\n9. Remove unnecessary data!\n\n"
	rm $out_path/spectra*/*.RAW 
	rm $out_path/spectra*/*.control
	rm $out_path/water_spectra/*.RAW 
	rm $out_path/water_spectra/*.control 
	#rm -r $out_path/spectra/CoordFiles     #commented, coordfiles now used in wolfgang addition
	#rm $out_path/spectra/*.CSV
fi
TerminateProgram $DebugFlag


