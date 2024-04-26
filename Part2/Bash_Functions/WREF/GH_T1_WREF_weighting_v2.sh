#!/bin/bash
# This script calculates the T1 correction for water maps.
# It also applies T1 and B1 correction maps for different metabolites which must already exist (see B1_Correction_Script.m).

# Concentration Estimate Calculation
# v2: WIP - should work with B1 correction (2021/10)

####TODO:
###  gly - even lower should be far less in wm? GABA - any T1 and concentration knowledge beyond guesses? research!
debugging=0

echo -e "\nWATER REFERENCE preparation."
cd "${out_dir}/maps/" || exit
[ $debugging -eq 1 ] && echo -e "\nDEBUG MODE\n" && pwd # && echo -e "\n"

echo -e "\nClearing directories..."
rm -R -f ./WREF ./T1cor ./Met_Maps_m_t1c ./Met_Maps_m_b1c ./Ratio_to_Water ./Concentration_Estimate_Maps ./Concentration_Estimate_Maps_prep ./Concentration_Estimate_Maps_clamped ./Concentration_Estimate_Ratio_B1cToT1c
mkdir -p WREF T1cor
mkdir -p Met_Maps_m_t1c Met_Maps_m_b1c
mkdir -p Ratio_to_Water Ratio_to_Water_t1c Ratio_to_Water_b1c
mkdir -p Concentration_Estimate_Maps Concentration_Estimate_Maps_t1c Concentration_Estimate_Maps_b1c
mkdir -p Concentration_Estimate_Maps_prep
mkdir -p Concentration_Estimate_Maps_clamped Concentration_Estimate_Maps_clamped_t1c Concentration_Estimate_Maps_clamped_b1c Concentration_Estimate_Ratio_B1cToT1c

# Just to prevent errors when manually calling the script:
[ ! "$(which mincmath)" == "/opt/minc/bin/mincmath" ] && echo "Updating PATH to change the mincmath version to /opt/minc/bin/mincmath..." && which mincmath && PATH=/opt/minc/bin:/opt/minc/1.9.18/bin:$PATH && echo "->" && which mincmath && echo -e ""

sleep 1

[ $debugging -eq 1 ] && echo -e "\n" && read -p "Pause 1" && echo -e "\n"
# Legacy: mincmath calculations, like Gasparovic. Now all this is done in B1correction.m and saved in water_Comb_T1_corr_map.mnc

# For B1 corr water...
mincmath -clobber -div Orig/Water_amp_map.mnc CorrectionMaps_B1c/water_Comb_B1_corr_map.mnc WREF/Water_amp_map_b1fc.mnc
mincmath -clobber -div Orig/Water_amp_map.mnc CorrectionMaps_T1c/water_Comb_T1_corr_map.mnc WREF/Water_amp_map_t1fc.mnc

[ $debugging -eq 1 ] && echo -e "\n" && read -p "Pause 2"
echo -e "\nApply T1 and B1 weighting to Cr_O_masked maps" # omitted: Asp, Ala Cit Tn Cys Try Thr
for metabolite in NAA NAAG Glu Gln Cr+PCr GPC+PCh Ins Gly Tau GSH GABA Ser; do
	mincmath -clobber -div Met_Maps_Cr_O_masked/${metabolite}_amp_map.mnc CorrectionMaps_T1c/${metabolite}_Comb_T1_corr_map.mnc Met_Maps_m_t1c/${metabolite}_amp_map.mnc
	mincmath -clobber -div Met_Maps_Cr_O_masked/${metabolite}_amp_map.mnc CorrectionMaps_B1c/${metabolite}_Comb_B1_corr_map.mnc Met_Maps_m_b1c/${metabolite}_amp_map.mnc
done

[ $debugging -eq 1 ] && echo -e "\n" && read -p "Pause 4"
echo -e "\nRatios to WATER" # omitted: Asp, Ala Cit Tn Cys Try Thr
for metabolite in NAA NAAG Glu Gln Cr+PCr GPC+PCh Ins Gly Tau GSH GABA Ser; do
	mincmath -clobber -div Met_Maps_m_t1c/${metabolite}_amp_map.mnc WREF/Water_amp_map_t1fc.mnc Ratio_to_Water_t1c/${metabolite}2W.mnc
	mincmath -clobber -div Met_Maps_m_b1c/${metabolite}_amp_map.mnc WREF/Water_amp_map_b1fc.mnc Ratio_to_Water_b1c/${metabolite}2W.mnc
done

[ $debugging -eq 1 ] && echo -e "\n" && read -p "Pause 5"
echo -e "\nCrescendo: Creation of estimated Metabolite Maps!"
#" concentration" maps - scale by GM/WM concentration, 1000 for micromol
mincmath -clobber -mult -const 35.9 Extra/WM_CSI_map.mnc Concentration_Estimate_Maps_prep/WM_con_map.mnc #de graaf numbers mol/l #cant find them in d-g?  edden/harris has 36.1
mincmath -clobber -mult -const 43.3 Extra/GM_CSI_map.mnc Concentration_Estimate_Maps_prep/GM_con_map.mnc
mincmath -clobber -add Concentration_Estimate_Maps_prep/WM_con_map.mnc Concentration_Estimate_Maps_prep/GM_con_map.mnc Concentration_Estimate_Maps_prep/Water_con_map.mnc
mincmath -clobber -mult -const 379 Concentration_Estimate_Maps_prep/Water_con_map.mnc Concentration_Estimate_Maps/Water_con_scaling_map_microMpL.mnc # 1000/sqrt(368 ms / 211 ms)/2 = 757 (Root of ratio of ADC durations)
# Note: this constant scales multiplicatively with the concentration estimates
# 1000/1.67=598 microM and SNR from ADC % adjusted 20211104
mincmath -clobber -mult -const 37900 Concentration_Estimate_Maps_prep/Water_con_map.mnc Concentration_Estimate_Maps/Water_con_scaling_for_MMs.mnc # 1000/1.67 microM and SNR from ADC *100 to be similar to mets. conc unknown!

echo "x685"

[ $debugging -eq 1 ] && echo -e "\n" && read -p "Pause 6"
# omitted: Asp, Ala Cit Tn Cys Try Thr
for metabolite in NAA NAAG Glu Gln Cr+PCr GPC+PCh Ins Gly Tau GSH GABA Ser; do
	mincmath -clobber -mult Concentration_Estimate_Maps/Water_con_scaling_map_microMpL.mnc Ratio_to_Water_t1c/${metabolite}2W.mnc Concentration_Estimate_Maps_t1c/${metabolite}_con_map.mnc
	mincmath -clobber -mult Concentration_Estimate_Maps/Water_con_scaling_map_microMpL.mnc Ratio_to_Water_b1c/${metabolite}2W.mnc Concentration_Estimate_Maps_b1c/${metabolite}_con_map.mnc
done

echo -e "\nEstimate Maps: Done!"
[ $debugging -eq 1 ] && echo -e "\n" && read -p "Pause 7" && echo -e "\n"
echo -e "Now Needed: Clamping!"

for metabolite in NAA NAAG Glu Gln Cr+PCr GPC+PCh Ins Gly Tau GSH GABA Ser; do
	mincmath -clobber -const2 0 50 -clamp Concentration_Estimate_Maps_t1c/${metabolite}_con_map.mnc Concentration_Estimate_Maps_clamped_t1c/${metabolite}_con_map.mnc
	mincmath -clobber -const2 0 50 -clamp Concentration_Estimate_Maps_b1c/${metabolite}_con_map.mnc Concentration_Estimate_Maps_clamped_b1c/${metabolite}_con_map.mnc
done

echo -e "\nMapping relative changes between T1c and B1c..."
for metabolite in NAA NAAG Glu Gln Cr+PCr GPC+PCh Ins Gly Tau GSH GABA Ser; do
	mincmath -clobber -div Concentration_Estimate_Maps_clamped_b1c/${metabolite}_con_map.mnc Concentration_Estimate_Maps_clamped_t1c/${metabolite}_con_map.mnc Concentration_Estimate_Ratio_B1cToT1c/${metabolite}_ratio_b1c2t1c.mnc
done

echo -e "\nRepeat this process for macromolecules..."
## Macromolecules (not parameterized)

mincmath -clobber -mult -const 0.65 Extra/WM_CSI_map.mnc WREF/WM_Vcor.mnc
mincmath -clobber -mult -const 0.78 Extra/GM_CSI_map.mnc WREF/GM_Vcor.mnc
mincmath -clobber -add WREF/GM_Vcor.mnc WREF/WM_Vcor.mnc WREF/GM_WM_cor.mnc
mincmath -clobber -div WREF/GM_Vcor.mnc WREF/GM_WM_cor.mnc WREF/GM_Fcor.mnc
mincmath -clobber -div WREF/WM_Vcor.mnc WREF/GM_WM_cor.mnc WREF/WM_Fcor.mnc
mincmath -clobber -mult -const 10.51 WREF/GM_Fcor.mnc WREF/GM_FTcor.mnc
mincmath -clobber -mult -const 8.26 WREF/WM_Fcor.mnc WREF/WM_FTcor.mnc
mincmath -clobber -add WREF/WM_FTcor.mnc WREF/GM_FTcor.mnc WREF/Correction_Water.mnc
mincmath -clobber -mult Orig/Water_amp_map.mnc WREF/Correction_Water.mnc WREF/Water_amp_map_t1fc.mnc # fc .. fractional correction	# mult with inverse

mincmath -clobber -mult -const 1.52 WREF/WM_Fcor.mnc T1cor/sMM_WM_FTcor.mnc
mincmath -clobber -mult -const 1.54 WREF/GM_Fcor.mnc T1cor/sMM_GM_FTcor.mnc
mincmath -clobber -add T1cor/sMM_WM_FTcor.mnc T1cor/sMM_GM_FTcor.mnc T1cor/sMM_T1_Correction.mnc
mincmath -clobber -mult Met_Maps_Cr_O_masked/MM_mea_amp_map.mnc T1cor/sMM_T1_Correction.mnc Met_Maps_m_t1c/MM_mea_amp_map.mnc # here: "map x CorrMap^(-1)" instead of "map / CorrMap"
mincmath -clobber -div Met_Maps_m_t1c/MM_mea_amp_map.mnc WREF/Water_amp_map_t1fc.mnc Ratio_to_Water/sMM2W.mnc
mincmath -clobber -mult Concentration_Estimate_Maps/Water_con_scaling_for_MMs.mnc Ratio_to_Water/sMM2W.mnc Concentration_Estimate_Maps/MM_mea_con_map.mnc
mincmath -clobber -const2 0 50 -clamp Concentration_Estimate_Maps/MM_mea_con_map.mnc Concentration_Estimate_Maps_clamped/MM_mea_con_map.mnc

echo -e "\nGH_T1_WREF_weighting_v2.sh completed!\n\n"
