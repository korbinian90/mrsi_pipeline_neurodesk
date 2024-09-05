#!/bin/bash
# This script calculates concentration estimates based on data from an MRSI and a WREF scan. 
# The input data should already by quality filtered by Met_Map_Masking.sh.
# It also applies T1 and B1 correction maps for different metabolites which must already exist (see B1_Correction_Script.m).

echo -e "\n\e[1m--- Concentration Estimate Calculation ---\e[0m\n"

# General stuff ----------------------------------------------------------------	
# Default values
out_dir="$PWD"
debug=0
verbose=0
metabolites="NAA NAAG Glu Gln Cr+PCr GPC+PCh Ins Gly Tau GSH GABA Ser" # MM_mea currently not implemented
water_correction=1 # 1.67
# b1_correction=0 # currently always on

# Function definitions 
usage() {
  echo -e "\nUsage: $0 -o <output_directory> [-b] [-d]\n"
  echo -e "Options:"
  echo -e "  -o <output_directory>  Output directory of the maps. Default: Current directory."
  echo -e "  -m <metabolites>       Metabolites to calculate concentration estimates for.\n\t\t\t Default: $metabolites."
  echo -e "  -d                     Debugging mode. Default: off."
  echo -e "  -v                     Verbose mode. Default: off."
  echo -e "  -w <water_correction>  Apply water correction. Default: off."
  echo -e "  -?                     Show this help message."
  echo -e ""
#  echo -e "  -b                     Apply B1 correction. Default: on."
  exit 1
}

debug_pause() {
  [ $debug -eq 1 ] && read -p "$1" 
}

debug_info() {
    echo -e "out_dir: $(basename ${out_dir}), full path:\n${out_dir}"
	echo -e "Verbose: $verbose"
	echo -e "Metabolites: $metabolites\n"
	echo -e "Water correction: $water_correction\n"
	# echo -e "B1_correction: $b1_correction"
}

log() {
  [ $debug -eq 1 ] && read -p "$1" 
  [ $debug -eq 0 ] && [ $verbose -eq 1 ] && echo -e "$1"
}

# Argument parsing 
while getopts "o:m:w:bdv?" opt; do
	case ${opt} in
        o) out_dir=$(realpath $OPTARG) ;;
    	m) metabolites=$OPTARG ;;
		b) b1_correction=1 ;;
		d) debug=1 ;;
		v) verbose=1 ;;
		w) water_correction=$OPTARG ;;
		\?) usage	;;
	esac
done

# debug mode
if [ "$debug" == 1 ]; then
	echo -e "Debug mode enabled!"
	debug_info
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


# Main script ----------------------------------------------------------------
debug_pause "Starting with main script..."

cd ${out_dir}/maps/
log "Clearing directories..."
rm -R -f Concentration_Estimate_Maps CE_Maps CE_Stuff/Concentration_Estimate_Maps CE_Stuff/WREF CE_Stuff/Met_Maps_Corrected CE_Stuff/Ratio_to_Water CE_Stuff/Concentration_Estimate_Maps_prep CE_Stuff/Concentration_Estimate_Ratio_B1cToT1c
mkdir -p CE_Maps CE_Stuff/Concentration_Estimate_Maps CE_Stuff/WREF CE_Stuff/Met_Maps_Corrected CE_Stuff/Ratio_to_Water CE_Stuff/Concentration_Estimate_Maps_prep CE_Stuff/Concentration_Estimate_Ratio_B1cToT1c
mkdir -p CE_Stuff/CorrectionMaps
[ -d CorrectionMaps_B1c ] && mv CorrectionMaps_B1c/* CE_Stuff/CorrectionMaps/ && rm CorrectionMaps_B1c -r # backwards compatibility
[ -d CorrectionMaps_T1c ] && mv CorrectionMaps_T1c/* CE_Stuff/CorrectionMaps/ && rm CorrectionMaps_T1c -r

# Just to prevent errors when manually calling the script:
# [ ! $(which mincmath) == "/opt/minc/bin/mincmath" ] && echo "Updating PATH to change the mincmath version to /opt/minc/bin/mincmath..." && which mincmath && PATH=/opt/minc/bin:/opt/minc/1.9.18/bin:$PATH && echo "->" && which mincmath && echo -e "" 

# Correction maps are calculated as suggested by Gasparovic et al. Now all this is done in B1correction.m and saved in ${metabolite}_Comb_{T1,B1}_corr_map.mnc 

log "Correcting water for T1 and B1 effects..."
mincmath -clobber -quiet -div Met_Maps_SNR_FWHM_CRLB/Water_amp_map.mnc CE_Stuff/CorrectionMaps/water_Comb_B1_corr_map.mnc CE_Stuff/WREF/Water_amp_map_b1c.mnc &
mincmath -clobber -quiet -div Met_Maps_SNR_FWHM_CRLB/Water_amp_map.mnc CE_Stuff/CorrectionMaps/water_Comb_T1_corr_map.mnc CE_Stuff/WREF/Water_amp_map_t1c.mnc &
wait

log "Correcting metabolite maps for T1 and B1 effects..." # omitted: Asp, Ala Cit Tn Cys Try Thr
for metabolite in $metabolites; do
	mincmath -clobber -quiet -div Met_Maps_SNR_FWHM_CRLB/${metabolite}_amp_map.mnc CE_Stuff/CorrectionMaps/${metabolite}_Comb_T1_corr_map.mnc CE_Stuff/Met_Maps_Corrected/${metabolite}_amp_map_t1c.mnc &
	mincmath -clobber -quiet -div Met_Maps_SNR_FWHM_CRLB/${metabolite}_amp_map.mnc CE_Stuff/CorrectionMaps/${metabolite}_Comb_B1_corr_map.mnc CE_Stuff/Met_Maps_Corrected/${metabolite}_amp_map_b1c.mnc &
done
wait

log "Calculating ratios to water..." # omitted: Asp, Ala Cit Tn Cys Try Thr
for metabolite in $metabolites; do
	mincmath -clobber -quiet -div CE_Stuff/Met_Maps_Corrected/${metabolite}_amp_map_t1c.mnc CE_Stuff/WREF/Water_amp_map_t1c.mnc CE_Stuff/Ratio_to_Water/${metabolite}2W_t1c.mnc &
	mincmath -clobber -quiet -div CE_Stuff/Met_Maps_Corrected/${metabolite}_amp_map_b1c.mnc CE_Stuff/WREF/Water_amp_map_b1c.mnc CE_Stuff/Ratio_to_Water/${metabolite}2W_b1c.mnc &
done
wait

log "Deriving scaling factor for water correction..."
scaling1=$(echo "scale=2; 1000 / $water_correction" | bc)
scaling2=$(echo "scale=2; 1000 / $water_correction * 100" | bc)
# x 1000 (conversion to microM), x 345/158 (ADC duration ratio: the signal is proportional to the duration!) 
# Note: this constant scales multiplicatively with the concentration estimates

log "Applying water scaling (factor = $scaling1) and tissue scaling for GM/WM..."
#" concentration" maps - scale by GM/WM concentration, 1000 for micromol
mincmath -clobber -quiet -mult -const 35.9 Extra/WM_CSI_map.mnc CE_Stuff/Concentration_Estimate_Maps_prep/WM_con_map.mnc  #de graaf numbers mol/l #cant find them in d-g?  edden/harris has 36.1
mincmath -clobber -quiet -mult -const 43.3 Extra/GM_CSI_map.mnc CE_Stuff/Concentration_Estimate_Maps_prep/GM_con_map.mnc
mincmath -clobber -quiet -add CE_Stuff/Concentration_Estimate_Maps_prep/WM_con_map.mnc CE_Stuff/Concentration_Estimate_Maps_prep/GM_con_map.mnc CE_Stuff/Concentration_Estimate_Maps_prep/Water_con_map.mnc
mincmath -clobber -quiet -mult -const $scaling1 CE_Stuff/Concentration_Estimate_Maps_prep/Water_con_map.mnc CE_Stuff/Concentration_Estimate_Maps_prep/Water_con_scaling_map_microMpL.mnc 	
mincmath -clobber -quiet -mult -const $scaling2 CE_Stuff/Concentration_Estimate_Maps_prep/Water_con_map.mnc CE_Stuff/Concentration_Estimate_Maps_prep/Water_con_scaling_for_MMs.mnc 	
# 1000/1.67 microM and SNR from ADC *100 to be similar to mets. conc unknown!
wait

log "Creating CE maps..."
# omitted: Asp, Ala Cit Tn Cys Try Thr
for metabolite in $metabolites; do
	mincmath -clobber -quiet -mult CE_Stuff/Concentration_Estimate_Maps_prep/Water_con_scaling_map_microMpL.mnc CE_Stuff/Ratio_to_Water/${metabolite}2W_t1c.mnc CE_Stuff/Concentration_Estimate_Maps/${metabolite}_con_map_t1c.mnc &
	mincmath -clobber -quiet -mult CE_Stuff/Concentration_Estimate_Maps_prep/Water_con_scaling_map_microMpL.mnc CE_Stuff/Ratio_to_Water/${metabolite}2W_b1c.mnc CE_Stuff/Concentration_Estimate_Maps/${metabolite}_con_map_b1c.mnc &
done
wait

log "Clamping and cleaning up..."
for metabolite in $metabolites; do
	mincmath -clobber -quiet -const2 0 50 -clamp CE_Stuff/Concentration_Estimate_Maps/${metabolite}_con_map_t1c.mnc CE_Stuff/Concentration_Estimate_Maps/${metabolite}_con_map_t1c_clamped.mnc &
	mincmath -clobber -quiet -const2 0 50 -clamp CE_Stuff/Concentration_Estimate_Maps/${metabolite}_con_map_b1c.mnc CE_Stuff/Concentration_Estimate_Maps/${metabolite}_con_map_b1c_clamped.mnc &
done
wait

for metabolite in $metabolites; do
	cp CE_Stuff/Concentration_Estimate_Maps/${metabolite}_con_map_b1c_clamped.mnc CE_Maps/${metabolite}_con_map.mnc & 
done
wait


log "Mapping relative changes between T1c and B1c..."
for metabolite in $metabolites; do
	mincmath -clobber -quiet -div CE_Stuff/Concentration_Estimate_Maps/${metabolite}_con_map_b1c.mnc CE_Stuff/Concentration_Estimate_Maps/${metabolite}_con_map_t1c.mnc CE_Stuff/Concentration_Estimate_Ratio_B1cToT1c/${metabolite}_con_ratio_B1cToT1c.mnc &
done
wait

## Macromolecules (not parameterized)
# log "Repeat this process for macromolecules..."
# mincmath -clobber -quiet -mult -const 0.65 Extra/WM_CSI_map.mnc CE_Stuff/WREF/WM_Vcor.mnc
# mincmath -clobber -quiet -mult -const 0.78 Extra/GM_CSI_map.mnc CE_Stuff/WREF/GM_Vcor.mnc
# mincmath -clobber -quiet -add CE_Stuff/WREF/GM_Vcor.mnc CE_Stuff/WREF/WM_Vcor.mnc CE_Stuff/WREF/GM_WM_cor.mnc
# mincmath -clobber -quiet -div CE_Stuff/WREF/GM_Vcor.mnc CE_Stuff/WREF/GM_WM_cor.mnc CE_Stuff/WREF/GM_Fcor.mnc
# mincmath -clobber -quiet -div CE_Stuff/WREF/WM_Vcor.mnc CE_Stuff/WREF/GM_WM_cor.mnc CE_Stuff/WREF/WM_Fcor.mnc
# mincmath -clobber -quiet -mult -const 10.51 CE_Stuff/WREF/GM_Fcor.mnc CE_Stuff/WREF/GM_FTcor.mnc
# mincmath -clobber -quiet -mult -const 8.26 CE_Stuff/WREF/WM_Fcor.mnc CE_Stuff/WREF/WM_FTcor.mnc
# mincmath -clobber -quiet -add CE_Stuff/WREF/WM_FTcor.mnc CE_Stuff/WREF/GM_FTcor.mnc CE_Stuff/WREF/Correction_Water.mnc
# mincmath -clobber -quiet -mult Orig/Water_amp_map.mnc CE_Stuff/WREF/Correction_Water.mnc CE_Stuff/WREF/Water_amp_map_t1fc.mnc 	# fc .. fractional correction	# mult with inverse
# mincmath -clobber -quiet -mult -const 1.52 CE_Stuff/WREF/WM_Fcor.mnc CE_Stuff/T1cor/sMM_WM_FTcor.mnc
# mincmath -clobber -quiet -mult -const 1.54 CE_Stuff/WREF/GM_Fcor.mnc CE_Stuff/T1cor/sMM_GM_FTcor.mnc
# mincmath -clobber -quiet -add CE_Stuff/T1cor/sMM_WM_FTcor.mnc CE_Stuff/T1cor/sMM_GM_FTcor.mnc CE_Stuff/T1cor/sMM_T1_Correction.mnc
# mincmath -clobber -quiet -mult Met_Maps_SNR_FWHM_CRLB/MM_mea_amp_map.mnc CE_Stuff/T1cor/sMM_T1_Correction.mnc CE_Stuff/Met_Maps_Corrected/MM_mea_amp_map_t1c.mnc 		# here: "map x CorrMap^(-1)" instead of "map / CorrMap"
# mincmath -clobber -quiet -div CE_Stuff/Met_Maps_Corrected/MM_mea_amp_map.mnc CE_Stuff/WREF/Water_amp_map_t1fc.mnc CE_Stuff/Ratio_to_Water/sMM2W.mnc
# mincmath -clobber -quiet -mult CE_Stuff/Concentration_Estimate_Maps_prep/Water_con_scaling_for_MMs.mnc CE_Stuff/Ratio_to_Water/sMM2W.mnc CE_Maps/MM_mea_con_map.mnc 
# mincmath -clobber -quiet -const2 0 50 -clamp CE_Maps/MM_mea_con_map.mnc CE_Maps/MM_mea_con_map.mnc

# Logging
touch CE_Maps/info.txt 
log "The maps in CE_Maps/ are B1+ corrected and clamped to 0-50 microM." 
echo "The maps in CE_Maps/ are B1+ corrected and clamped to 0-50 microM." >> CE_Maps/info.txt
echo "" >> CE_Maps/info.txt
debug_info >> CE_Maps/info.txt
echo "Scaling factor: $scaling1" >> CE_Maps/info.txt

echo -e "CE calculation completed!\nInfo logged to CE_Maps/info.txt\n"

