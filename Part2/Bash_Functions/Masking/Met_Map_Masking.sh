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

# Function to display usage information
usage() {
    echo "Usage: $(basename "$0") [-o out_dir] [-s SNR_limit] [-f FWHM_limit] [-c CRLB_limit] [-d]" >&2
    echo "Options:" >&2
    echo "  -o out_dir          Specify the output directory (required). Default: current directory." >&2
    echo "  -s SNR_limit        Specify the SNR limit. Default: ${SNR_limit}." >&2
    echo "  -f FWHM_limit       Specify the FWHM limit. Default: ${FWHM_limit}." >&2
    echo "  -c CRLB_limit       Specify the CRLB limit. Default: ${CRLB_limit}." >&2
    echo "  -d                  Enable debug mode." >&2
    echo "  -r                  Enable resampling." >&2
    echo "  -m stddev_multiplier Specify the standard deviation multiplier for the outlier clip. Default: ${stddev_multiplier}." >&2
}

# Parse command-line options
while getopts ":o:s:f:c:m:dr" opt; do
    case $opt in
        s) SNR_limit=$OPTARG ;;
        f) FWHM_limit=$OPTARG ;;
        c) CRLB_limit=$OPTARG ;;
        d) debug=1 ;;
        r) resample=1 ;;
        m) stddev_multiplier=$OPTARG ;;
        o) out_dir=$OPTARG ;;
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
    echo "Resampling: $resample"
    echo "Outlier clip multiplier: ${stddev_multiplier}x standard deviation"
    echo "out_dir: $(basename ${out_dir}), full path:\n${out_dir}"
fi

# Shift the positional parameters to ignore parsed options & check if there are any additional arguments
shift $((OPTIND - 1))
if [ "$#" -ne 0 ]; then
    echo "Error: Unexpected arguments." >&2
    usage
    exit 1
fi

# A few checks 
if [ ! -d "$out_dir/maps" ]; then
    echo "Error: 'maps' directory not found in the specified output directory (${out_dir})." >&2 && exit 1
elif [ ! -d "$out_dir/maps/Orig" ] || [ -z "$(ls -A $out_dir/maps/Orig)" ]; then
    echo "Error: 'Orig' directory in 'maps' is not found or empty (${out_dir}/maps/Orig)." >&2 && exit 1
fi






##### Begin script! #####

cd "${out_dir}/maps/" || exit 1
# rm -rf CRLB_Masked Cr_Masked Met_Maps_Cr_O_masked Ratio_Maps_Cr_O_masked Met_Maps_masked Ratio_Maps_masked Extra_Maps_masked Met_Maps_Outlier_masked Met_Maps_Q_O_masked NAA_based_mask Met_Maps_NAA_masked Met_Maps_Outlier_NAA_masked Met_Maps_Q_O_NAA_masked Met_Maps_double_masked Masks Met_Maps_SNR_FWHM_CRLB_OC-${stddev_multiplier}xSD Ratio_Maps_SNR_FWHM_CRLB_OC-${stddev_multiplier}xSD Ratio_New
mkdir -p Masks {Met,Ratio}_Maps_SNR_FWHM_CRLB{,_OC-${stddev_multiplier}xSD} Ratio_New

echo -e "\n$(basename $out_dir)"

echo -e "Creating mask_CRLBsum_FWHM, which demands a FWHM < ${FWHM_limit} and CRLB(tCho) + CRLB(tCr) < 300." 					# This takes CRLB values from tCho and tCr and calculates a joint CRLB mask
[ $debug == 1 ] && read -p "Proceed?"
mincmath -clobber -quiet -add Orig/Cr+PCr_sd_map.mnc    		Orig/GPC+PCh_sd_map.mnc  	Masks/map_CRLBsum_tCho_tCr.mnc 			# map_CRLBsum_tCho+tCr: sum of CRLBs of tCho and tCr
mincmath -clobber -quiet -nsegment -const2  300 9999     		Masks/map_CRLBsum_tCho_tCr.mnc  Masks/mask_CRLBsum_tCho_tCr-lt-300.mnc		# mask_CRLBsum-lt-300.mnc: 	sum(CRLB) < 300 --> 1
mincmath -clobber -quiet -nsegment -const2 ${FWHM_limit} 9999     	Extra/FWHM_map.mnc 		Masks/mask_FWHM-lt-${FWHM_limit}.mnc		# mask_FWHM-lt-0.15.mnc: 	FWHM < 0.15 --> 1
mincmath -clobber -quiet -mult	Masks/mask_CRLBsum_tCho_tCr-lt-300.mnc	Masks/mask_FWHM-lt-${FWHM_limit}.mnc 	Masks/mask_CRLBsum_FWHM.mnc		# mask_CRLBsum_FWHM.mnc has two conditions:		
																		# (a) FWHM < 0.15 
																		# (b) CRLB(tCho) + CRLB(tCr) < 300

[ $resample == 1 ] && mincresample Masks/mask_CRLBsum_FWHM.mnc -like csi_template_zf.mnc Masks/mask_CRLBsum_FWHM.mncc -tricubic -clobber &		


echo -e "Creating mask for Cr SNR >${SNR_limit} and FWHM <${FWHM_limit}."
[ $debug == 1 ] && read -p "Proceed?"
mincmath -clobber -quiet -nsegment -const2 0.00  ${SNR_limit}	Extra/SNR_Cr_PseudoReplica_spectral_map.mnc 	Masks/mask_SNR-gt-${SNR_limit}.mnc  	 	# mask_SNR.mnc:		Cr SNR  < ${SNR_limit} --> 1
mincmath -clobber -quiet -nsegment -const2 ${FWHM_limit} 9999	Extra/FWHM_map.mnc     				Masks/mask_FWHM-lt-${FWHM_limit}.mnc 		# mask_FWHM.mnc: 	FWHM > 0.15 --> 1
mincmath -clobber -quiet -mult 					Masks/mask_SNR-gt-${SNR_limit}.mnc		Masks/mask_FWHM-lt-${FWHM_limit}.mnc \
								Masks/mask_Cr_SNR-gt-${SNR_limit}_FWHM-lt-${FWHM_limit}.mnc  					# mask_Cr_SNR-gt-2.5_FWHM-lt-0.15.mnc thus requires:
																				# (a) Cr SNR  > 2.5
																				# (b) Cr FWHM < 0.15
																		
[ $resample == 1 ] && mincresample Masks/mask_Cr_SNR-gt-${SNR_limit}_FWHM-lt-${FWHM_limit}.mnc -like csi_template_zf.mnc Masks/mask_Cr_SNR-gt-${SNR_limit}_FWHM-lt-${FWHM_limit}.mncc -tricubic -clobber &
 

echo -e "Create mask for NAA SNR >${SNR_limit} and FWHM <${FWHM_limit}."
[ $debug == 1 ] && read -p "Proceed?"
mincmath -clobber -quiet -nsegment -const2 0 ${SNR_limit}	Extra/SNR_NAA_PseudoReplica_spectral_map.mnc 	Masks/mask_NAA_SNR-gt-${SNR_limit}.mnc											
mincmath -clobber -quiet -mult 					Masks/mask_NAA_SNR-gt-${SNR_limit}.mnc 		Masks/mask_FWHM-lt-${FWHM_limit}.mnc \
								Masks/mask_NAA_SNR-gt-${SNR_limit}_FWHM-lt-${FWHM_limit}.mnc	

[ $resample == 1 ] && mincresample Masks/mask_NAA_SNR_gt${SNR_limit}_FWHM-lt-${FWHM_limit}.mnc -like csi_template_zf.mnc Masks/mask_NAA_SNR_gt${SNR_limit}_FWHM-lt-${FWHM_limit}.mncc -tricubic -clobber &


echo -e "Create CRLB masks (CRLB <${CRLB_limit}%)."
[ $debug == 1 ] && read -p "Proceed?"
for f in Orig/*_amp_map.mnc; do
		file_name=$(basename "$f")
		met="${file_name%_amp_map.mnc}"
		
		mincmath -clobber -quiet -segment -const2 0 ${CRLB_limit} Orig/${met}_sd_map.mnc Masks/mask_CRLB-lt-${CRLB_limit}_${met}_tmp.mnc 	
		mincmath -clobber -quiet -mult Masks/mask_CRLB-lt-${CRLB_limit}_${met}_tmp.mnc  mask.mnc Masks/mask_CRLB-lt-${CRLB_limit}_${met}.mnc &
done
wait

echo -e "Combine Cr SNR mask, FWHM mask and metabolite-specific CRLB mask."
[ $debug == 1 ] && read -p "Proceed?"
for f in Orig/*_amp_map.mnc; do
		# use regexp to find the metabolite name (name of the * in the Orig/*_amp_map.mnc)
		file_name=$(basename "$f")
		met="${file_name%_amp_map.mnc}"
		
		mincmath -clobber -quiet -mult Masks/mask_CRLB-lt-${CRLB_limit}_${met}.mnc Masks/mask_Cr_SNR-gt-${SNR_limit}_FWHM-lt-${FWHM_limit}.mnc Masks/mask_CRLB_FWHM_SNR_${met}.mnc &
done
wait

echo -e "Apply combined Cr SNR mask, FWHM mask, met-CRLB masks, a brain mask and an outlier filter to Origs."
[ $debug == 1 ] && read -p "Proceed?"
for f in Orig/*_amp_map.mnc; do
		file_name=$(basename "$f")
		met="${file_name%_amp_map.mnc}"
		
		mincmath -clobber -quiet -mult Orig/${met}_amp_map.mnc 			Masks/mask_CRLB_FWHM_SNR_${met}.mnc  	Met_Maps_SNR_FWHM_CRLB/${met}_amp_map.mnc		

		# Outlier clip: clamp to [0, n*stddev]		
		output=$(mincstats Orig/${met}_amp_map.mnc -stddev)
		oc=$(echo "$output" | grep -oP 'Stddev:\s+\K\d+(\.\d+)?' | awk "{printf \"%.0f\", (\$1 * ${stddev_multiplier}) + 0.5}")
		mincmath -clobber -quiet -clamp -const2 0 $oc Met_Maps_SNR_FWHM_CRLB/${met}_amp_map.mnc Met_Maps_SNR_FWHM_CRLB_OC-${stddev_multiplier}xSD/${met}_amp_map_tmp.mnc 
		mincmath -clobber -quiet -mult Met_Maps_SNR_FWHM_CRLB_OC-${stddev_multiplier}xSD/${met}_amp_map_tmp.mnc mask.mnc Met_Maps_SNR_FWHM_CRLB_OC-${stddev_multiplier}xSD/${met}_amp_map.mnc &
done
wait

echo -e "Creating Ratio_New."
[ $debug == 1 ] && read -p "Proceed?"
for denom in NAA+NAAG Cr+PCr; do
	echo -e "Ratios to ${denom}"
		for f in Orig/*_amp_map.mnc; do
		file_name=$(basename "$f")
		met="${file_name%_amp_map.mnc}"
		[ ${met} == ${denom} ] && continue  	 	
		
		mincmath -clobber -quiet -div Met_Maps_SNR_FWHM_CRLB_OC-${stddev_multiplier}xSD/${met}_amp_map.mnc Met_Maps_SNR_FWHM_CRLB_OC-${stddev_multiplier}xSD/${denom}_amp_map.mnc Ratio_New/${met}_RatTo${denom}_map.mnc &
	done
done
wait

echo -e "Apply combined Cr SNR mask, FWHM mask, met-CRLB masks, a brain mask and an outlier filter to Ratios."
[ $debug == 1 ] && read -p "Proceed?"
for denom in NAA+NAAG Cr+PCr; do
	echo -e "Ratios to ${denom}"	
	for f in Ratio_New/*_RatToCr+PCr_map.mnc; do
		file_name=$(basename "$f")
		met="${file_name%_RatToCr+PCr_map.mnc}"
		[ ${met} == ${denom} ] && continue  	 	
		
		mincmath -clobber -quiet -mult Ratio_New/${met}_RatTo${denom}_map.mnc 				Masks/mask_CRLB_FWHM_SNR_${met}.mnc  	Ratio_Maps_SNR_FWHM_CRLB/${met}_RatTo${denom}_map_tmp.mnc	# Enumerator CRLB mask
		mincmath -clobber -quiet -mult Ratio_Maps_SNR_FWHM_CRLB/${met}_RatTo${denom}_map_tmp.mnc 	Masks/mask_CRLB_FWHM_SNR_${denom}.mnc  	Ratio_Maps_SNR_FWHM_CRLB/${met}_RatTo${denom}_map.mnc 	# Denominator CRLB mask 
		
		# Outlier clip: clamp to [0, n*stddev]
		output=$(mincstats Ratio_New/${met}_RatTo${denom}_map.mnc -stddev)
		oc=$(echo "$output" | grep -oP 'Stddev:\s+\K\d+(\.\d+)?' | awk "{printf \"%.0f\", (\$1 * ${stddev_multiplier}) + 0.5}")
		mincmath -clobber -quiet -clamp -const2 0 $oc 	Ratio_Maps_SNR_FWHM_CRLB/${met}_RatTo${denom}_map.mnc 		Ratio_Maps_SNR_FWHM_CRLB_OC-${stddev_multiplier}xSD/${met}_RatTo${denom}_map_tmp.mnc 
		mincmath -clobber -quiet -mult 			Ratio_Maps_SNR_FWHM_CRLB_OC-${stddev_multiplier}xSD/${met}_RatTo${denom}_map_tmp.mnc mask.mnc 	Ratio_Maps_SNR_FWHM_CRLB_OC-${stddev_multiplier}xSD/${met}_RatTo${denom}_map.mnc &
	done
done

wait
echo -e "Remove tmp files.\n"
rm -f Masks/*_tmp.mnc {Met,Ratio}_Maps_SNR_FWHM_CRLB{,_OC-${stddev_multiplier}xSD}/*_tmp.mnc 









