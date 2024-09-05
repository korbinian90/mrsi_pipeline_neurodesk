#!/bin/bash
# Script for creating masked metabolic maps.
# Originally created by Gilbert Hangel, revised by Philipp Lazen.
# Note regarding acronyms: lt and gt for "less than" and "greater than"


##### Initialize stuff #####
# Default parameters
out_dir=$PWD
SNR_limit=2.5
FWHM_limit=0.15
CRLB_limit=40
debug=0
resample=0
stddev_multiplier=6
ratio_oc=6
longfoldernames=0
delete_existing=0

# Function to display usage information
usage() {
    echo "Usage: $(basename "$0") [OPTIONS]" >&2
    echo "Options:" >&2
    echo "  -o out_dir           Specify the output directory (required). Default: current directory." >&2
    echo "  -s SNR_limit         Specify the SNR limit. Default: ${SNR_limit}." >&2
    echo "  -f FWHM_limit        Specify the FWHM limit. Default: ${FWHM_limit}." >&2
    echo "  -c CRLB_limit        Specify the CRLB limit. Default: ${CRLB_limit}." >&2
    echo "  -m stddev_multiplier Specify the standard deviation multiplier for the outlier clip. Default: ${stddev_multiplier}." >&2
    echo "  -n ratio_oc          Specify the outlier clip for ratios. Default: ${ratio_oc}." >&2
    echo "  -d                   Enable debug mode. Default: off." >&2
    echo "  -r                   Enable resampling. Default: off." >&2
    echo "  -l                   Enable long folder names including the thresholds. Default: off." >&2
    echo "  -D                   Delete existing met and ratio maps. Default: off." >&2
    echo "  -?                   Display this help message." >&2
}

# Parse command-line options
while getopts ":o:s:f:c:m:n:dDrl?" opt; do
    case $opt in
        o) out_dir=$(realpath $OPTARG) ;;
        s) SNR_limit=$OPTARG ;;
        f) FWHM_limit=$OPTARG ;;
        c) CRLB_limit=$OPTARG ;;
        d) debug=1 ;;
        r) resample=1 ;;
        m) stddev_multiplier=$OPTARG ;;
        n) ratio_oc=$OPTARG ;;
        l) longfoldernames=1 ;;
        D) delete_existing=1 ;;
        ?) usage && exit 0 ;;
        \?) echo "Invalid option: -$OPTARG" >&2
            usage
            exit 1 ;;
        :) echo "Option -$OPTARG requires an argument." >&2
           usage
           exit 1 ;;
    esac
done

# If debug mode is enabled, display debug information
if [ "$debug" == 1 ]; then
    echo "Debug mode enabled!"
    echo "SNR_limit: $SNR_limit"
    echo "FWHM_limit: $FWHM_limit"
    echo "CRLB_limit: $CRLB_limit"
    echo "Outlier clip multiplier: ${stddev_multiplier}x standard deviation"
    echo "Outlier clip multiplier for ratios: ${ratio_oc}"
    echo -e "out_dir: $(basename ${out_dir}), full path:\n${out_dir}"
    echo "Resampling: $resample"
    echo "Long folder names: $longfoldernames"
    echo "Delete existing met and ratio maps: $delete_existing"
    read -p "Proceed?"
fi

# Shift the positional parameters to ignore parsed options & check if there are any additional arguments
shift $((OPTIND - 1))
if [ "$#" -ne 0 ]; then
    echo "Error: Unexpected arguments." >&2
    usage
    exit 1
fi

# Check folder structure / out_dir
if [ ! -d "$out_dir/maps" ]; then # if there is no subfolder "maps", check if we are already in "maps"
    if [ -d "$out_dir/../maps" ]; then
        out_dir=$out_dir/..
        echo "Note: It appears the variable out_dir pointed to the 'maps' folder. I fixed that for you." 
    else
        echo "Error: 'maps' directory not found in the specified output directory (${out_dir})." >&2 && exit 1
    fi
elif [ ! -d "$out_dir/maps/Orig" ] || [ -z "$(ls -A $out_dir/maps/Orig)" ]; then
    echo "Error: 'Orig' directory in 'maps' is not found or empty (${out_dir}/maps/Orig)." >&2 && exit 1
fi

##### Begin script! #####
if [ $longfoldernames == 1 ]; then
    metfolder=Met_Maps_SNR-gt-${SNR_limit}_FWHM-lt-${FWHM_limit}_CRLB-lt-${CRLB_limit}
    ratiofolder=Ratio_Maps_SNR-gt-${SNR_limit}_FWHM-lt-${FWHM_limit}_CRLB-lt-${CRLB_limit}
else
    metfolder=Met_Maps_SNR_FWHM_CRLB
    ratiofolder=Ratio_Maps_SNR_FWHM_CRLB
fi

# Create directories and delete existing ones if requested
cd ${out_dir}/maps/
[ $delete_existing == 1 ] && echo "Deleting existing folders." && rm -rf {Met,Ratio}_Maps_SNR*FWHM*CRLB* Ratio_Ńew Masks
mkdir -p Ratio_New Masks/Mets ${metfolder}{,_OC-${stddev_multiplier}xSD} ${ratiofolder}{,_OC-${ratio_oc}}

# Info file
touch $metfolder/infos.txt
echo -e "Patient: $(basename $(realpath "$out_dir"))\nFull path: $(realpath "$out_dir")\nSNR limit: ${SNR_limit}\nFWHM limit: ${FWHM_limit}\nCRLB limit: ${CRLB_limit}\nOutlier clip multiplier: ${stddev_multiplier}x standard deviation\nOutlier clip multiplier for ratios: ${ratio_oc}\nResampling: ${resample}\nLong folder names: ${longfoldernames}\nDelete existing met and ratio maps: ${delete_existing}\nInfo file location: ${metfolder}/infos.txt" > $metfolder/infos.txt

# Start with operations 
echo -e "\n$(basename $(realpath "$out_dir"))"

# Create tCho+tCr CRLB mask
{
	echo -e "Creating mask_CRLBsum_FWHM, which demands a FWHM < ${FWHM_limit} and CRLB(tCho) + CRLB(tCr) < 300. Note that this is not used."
	[ $debug == 1 ] && read -p "Proceed?"
	mincmath -clobber -quiet -add Orig/Cr+PCr_sd_map.mnc Orig/GPC+PCh_sd_map.mnc Masks/map_CRLBsum_tCho_tCr.mnc
	mincmath -clobber -quiet -nsegment -const2 300 9999 Masks/map_CRLBsum_tCho_tCr.mnc Masks/mask_CRLBsum_tCho_tCr-lt-300.mnc
	mincmath -clobber -quiet -nsegment -const2 ${FWHM_limit} 9999 Extra/FWHM_map.mnc Masks/mask_FWHM-lt-${FWHM_limit}.mnc
	mincmath -clobber -quiet -mult Masks/mask_CRLBsum_tCho_tCr-lt-300.mnc Masks/mask_FWHM-lt-${FWHM_limit}.mnc Masks/mask_CRLBsum-lt-300_FWHM-lt-${FWHM_limit}.mnc

	[ $resample == 1 ] && mincresample Masks/mask_CRLBsum-lt-300_FWHM-lt-${FWHM_limit}.mnc -like csi_template_zf.mnc Masks/mask_CRLBsum_FWHM_FWHM-lt-${FWHM_limit}.mncc -tricubic -clobber &
}  

# Create SNR and FWHM masks
{
	echo -e "Create mask for SNR >${SNR_limit} and FWHM <${FWHM_limit}."
	[ $debug == 1 ] && read -p "Proceed?"
	mincmath -clobber -quiet -nsegment -const2 ${FWHM_limit} 9999 Extra/FWHM_map.mnc Masks/mask_FWHM-lt-${FWHM_limit}.mnc

	if [ -f Extra/SNR_map.mnc ]; then
	    snr_file="Extra/SNR_map.mnc"
	    echo "Using SNR_map.mnc in Extra/ for SNR mask." >> $metfolder/infos.txt
	elif [ -f Extra/SNR_NAA_PseudoReplica_spectral_map.mnc ]; then
	    snr_file="Extra/SNR_NAA_PseudoReplica_spectral_map.mnc"
	    echo "Using SNR_NAA_PseudoReplica_spectral_map.mnc in Extra/ for SNR mask." >> $metfolder/infos.txt
	elif [ -f Extra/SNR_Cr_PseudoReplica_spectral_map.mnc ]; then
	    snr_file="Extra/SNR_Cr_PseudoReplica_spectral_map.mnc"
	    echo "Using SNR_Cr_PseudoReplica_spectral_map.mnc in Extra/ for SNR mask." >> $metfolder/infos.txt
	else
	    echo "Error: No SNR file found in the Extra directory." >&2 
	    exit 1
	fi
	mincmath -clobber -quiet -nsegment -const2 0 ${SNR_limit} ${snr_file} Masks/mask_SNR-gt-${SNR_limit}.mnc
	mincmath -clobber -quiet -mult Masks/mask_SNR-gt-${SNR_limit}.mnc Masks/mask_FWHM-lt-${FWHM_limit}.mnc Masks/mask_SNR-gt-${SNR_limit}_FWHM-lt-${FWHM_limit}.mnc
	[ $resample == 1 ] && mincresample Masks/mask_SNR-gt-${SNR_limit}_FWHM-lt-${FWHM_limit}.mnc -like csi_template_zf.mnc Masks/mask_SNR-gt-${SNR_limit}_FWHM-lt-${FWHM_limit}.mncc -tricubic -clobber &
} 

# Create CRLB masks
{
	echo -e "Create CRLB masks (CRLB <${CRLB_limit}%)."
	[ $debug == 1 ] && read -p "Proceed?"
	for f in Orig/*.mnc; do
	    file_name=$(basename "$f")
	    ext="${f##*.}"
	    met=$(basename "$f" | cut -d '_' -f 1)
	    [ ${met} == "MM" ] && met="MM_mea" # Exception for MM_mea

	    if [[ "$f" =~ "_sd_" ]]; then
		mincmath -clobber -quiet -segment -const2 0 ${CRLB_limit} Orig/${met}_sd_map.mnc Masks/Mets/mask_CRLB-lt-${CRLB_limit}_${met}_tmp.mnc
		mincmath -clobber -quiet -mult Masks/Mets/mask_CRLB-lt-${CRLB_limit}_${met}_tmp.mnc mask.mnc Masks/Mets/mask_CRLB-lt-${CRLB_limit}_${met}.mnc &
	    fi
	done
	wait
} 
wait

# Combine SNR, FWHM and CRLB masks
echo -e "Combine SNR mask, FWHM mask and metabolite-specific CRLB mask."
[ $debug == 1 ] && read -p "Proceed?"
for f in Orig/*_amp_map.mnc; do
    met=$(basename "$f" | cut -d '_' -f 1)
    [ ${met} == "MM" ] && met="MM_mea" # Exception for MM_mea
    mincmath -clobber -quiet -mult Masks/Mets/mask_CRLB-lt-${CRLB_limit}_${met}.mnc Masks/mask_SNR-gt-${SNR_limit}_FWHM-lt-${FWHM_limit}.mnc Masks/Mets/mask_CRLB-lt-${CRLB_limit}_SNR-gt-${SNR_limit}_FWHM-lt-${FWHM_limit}_${met}.mnc &
done
wait

# Apply masks to metabolic maps
echo -e "Apply combined SNR mask, FWHM mask, metabolite-specific CRLB masks, a brain mask and an outlier filter to Origs."
[ $debug == 1 ] && read -p "Proceed?"
for f in Orig/*_amp_map.mnc; do
    met=$(basename "$f" | cut -d '_' -f 1)
    [ ${met} == "MM" ] && met="MM_mea" # Exception for MM_mea

    mincmath -clobber -quiet -mult Orig/${met}_amp_map.mnc Masks/Mets/mask_CRLB-lt-${CRLB_limit}_SNR-gt-${SNR_limit}_FWHM-lt-${FWHM_limit}_${met}.mnc ${metfolder}/${met}_amp_map.mnc

    # Outlier clip: clamp to [0, n*stddev]
    output=$(mincstats Orig/${met}_amp_map.mnc -stddev)
    oc=$(echo "$output" | grep -oP 'Stddev:\s+\K\d+(\.\d+)?' | awk "{printf \"%.0f\", (\$1 * ${stddev_multiplier}) + 0.5}")
    mincmath -clobber -quiet -clamp -const2 0 $oc ${metfolder}/${met}_amp_map.mnc ${metfolder}_OC-${stddev_multiplier}xSD/${met}_amp_map_tmp.mnc
    mincmath -clobber -quiet -mult ${metfolder}_OC-${stddev_multiplier}xSD/${met}_amp_map_tmp.mnc mask.mnc ${metfolder}_OC-${stddev_multiplier}xSD/${met}_amp_map.mnc &
done
wait

# Recreate ratio maps
echo -e "Creating Ratio_New."
[ $debug == 1 ] && read -p "Proceed?"
# Define a function and run it for both cases in parallel
create_ratios() {
    local denom=$1
    echo -e "-Ratios to ${denom}"
    for f in Orig/*_amp_map.mnc; do
        met=$(basename "$f" | cut -d '_' -f 1)
        [ ${met} == "MM" ] && met="MM_mea" # Exception for MM_mea
        [ ${met} == ${denom} ] && continue

        mincmath -clobber -quiet -div ${metfolder}_OC-${stddev_multiplier}xSD/${met}_amp_map.mnc ${metfolder}_OC-${stddev_multiplier}xSD/${denom}_amp_map.mnc Ratio_New/${met}_RatTo${denom}_map.mnc
    done
    wait
}
create_ratios "NAA+NAAG" &
create_ratios "Cr+PCr" &
create_ratios "GPC+PCh" &
wait

echo -e "Apply combined SNR mask, FWHM mask, metabolite-specific CRLB masks, a brain mask and an outlier filter to Ratios."
[ $debug == 1 ] && read -p "Proceed?"
# Define a function and run it for both cases in parallel
apply_masks_and_filters() {
    local denom=$1
    echo -e "-Ratios to ${denom}"
    for f in Ratio_New/*_RatToCr+PCr_map.mnc; do
        met=$(basename "$f" | cut -d '_' -f 1)
        [ ${met} == "MM" ] && met="MM_mea" # Exception for MM_mea
        [ ${met} == ${denom} ] && continue

        mincmath -clobber -quiet -mult Ratio_New/${met}_RatTo${denom}_map.mnc Masks/Mets/mask_CRLB-lt-${CRLB_limit}_SNR-gt-${SNR_limit}_FWHM-lt-${FWHM_limit}_${met}.mnc ${ratiofolder}/${met}_RatTo${denom}_map_tmp.mnc
        mincmath -clobber -quiet -mult ${ratiofolder}/${met}_RatTo${denom}_map_tmp.mnc Masks/Mets/mask_CRLB-lt-${CRLB_limit}_SNR-gt-${SNR_limit}_FWHM-lt-${FWHM_limit}_${denom}.mnc ${ratiofolder}/${met}_RatTo${denom}_map.mnc

        # Outlier clip: clamp to [0, ratio_oc]
        mincmath -clobber -quiet -clamp -const2 0 $ratio_oc ${ratiofolder}/${met}_RatTo${denom}_map.mnc ${ratiofolder}_OC-${ratio_oc}/${met}_RatTo${denom}_map_tmp.mnc
        mincmath -clobber -quiet -mult ${ratiofolder}_OC-${ratio_oc}/${met}_RatTo${denom}_map_tmp.mnc mask.mnc ${ratiofolder}_OC-${ratio_oc}/${met}_RatTo${denom}_map.mnc &
    done
    wait
}
apply_masks_and_filters "NAA+NAAG" &
apply_masks_and_filters "Cr+PCr" &
apply_masks_and_filters "GPC+PCh" &
wait

echo -e "Remove tmp files.\n" 
rm -f Masks/*_tmp.mnc Masks/Mets/*_tmp.mnc ${metfolder}{,_OC-${stddev_multiplier}xSD}/*_tmp.mnc ${ratiofolder}{,_OC-${ratio_oc}}/*_tmp.mnc

