
echo -e "\n Masking...  \n"

#define working directory -- get thet from the part 2 prot anyways
cd ${out_dir}/maps/	

rm -R -f /CRLB_Masked
mkdir CRLB_Masked
mincmath -clobber -add Orig/Cr+PCr_sd_map.mnc Orig/GPC+PCh_sd_map.mnc CRLB_Masked/2crlbs.mnc    ###for volunteers? could be an issue in tumours
mincmath -const2 300 9999 -clobber -segment CRLB_Masked/2crlbs.mnc CRLB_Masked/mask_crlb300.mnc
mincmath -const2 0.12 9999 -clobber -segment Extra/FWHM_map.mnc CRLB_Masked/mask_F12.mnc
mincmath -clobber -add CRLB_Masked/mask_crlb300.mnc CRLB_Masked/mask_F12.mnc CRLB_Masked/mask_sum.mnc
mincmath -const2 0 0.9 -clobber -segment CRLB_Masked/mask_sum.mnc CRLB_Masked/mask_new.mnc
mincresample CRLB_Masked/mask_new.mnc -like csi_template_zf.mnc CRLB_Masked/mask_new.mncc  -tricubic -clobber

rm -R -f /Cr_Masked
mkdir Cr_Masked

mincmath -const2 0 2.5 -clobber -segment Extra/SNR_Cr_PseudoReplica_spectral_map.mnc Cr_Masked/mask_SNR.mnc  ##our snr should be twice as much by new definition
mincmath -const2 0.15 9999 -clobber -segment Extra/FWHM_Cr_map.mnc Cr_Masked/mask_FWHM.mnc
mincmath -clobber -add Cr_Masked/mask_SNR.mnc Cr_Masked/mask_FWHM.mnc Cr_Masked/mask_sum.mnc
mincmath -const2 0 0.9 -clobber -segment Cr_Masked/mask_sum.mnc Cr_Masked/mask_cr.mnc
mincresample Cr_Masked/mask_cr.mnc -like csi_template_zf.mnc Cr_Masked/mask_cr.mncc  -tricubic -clobber

rm -R -f /Met_Maps_Cr_O_masked
mkdir Met_Maps_Cr_O_masked

rm -R -f /Ratio_Maps_Cr_O_masked
mkdir Ratio_Maps_Cr_O_masked

###new part A: filter all previously done maps using these!

rm -R -f /Met_Maps_masked
mkdir Met_Maps_masked

rm -R -f /Ratio_Maps_masked
mkdir Ratio_Maps_masked

rm -R -f /Extra_Maps_masked
mkdir Extra_Maps_masked

rm -R -f /Met_Maps_Outlier_masked
mkdir Met_Maps_Outlier_masked

rm -R -f /Met_Maps_Q_O_masked
mkdir Met_Maps_Q_O_masked



###### #new for vol study: minimal criteria mask

rm -R -f /NAA_based_mask
mkdir NAA_based_mask

rm -R -f /Met_Maps_NAA_masked
mkdir Met_Maps_NAA_masked

mkdir Met_Maps_NAA_masked/CRLB_masks

rm -R -f /Met_Maps_Outlier_NAA_masked
mkdir Met_Maps_Outlier_NAA_masked

rm -R -f /Met_Maps_Q_O_NAA_masked
mkdir Met_Maps_Q_O_NAA_masked

rm -R -f /Met_Maps_double_masked
mkdir Met_Maps_double_masked

mincmath -const2 0.0001 5 -clobber -nsegment Extra/SNR_NAA_PseudoReplica_spectral_map.mnc NAA_based_mask/mask_snr.mnc
mincmath -const2 0.15 999 -clobber -nsegment Extra/FWHM_map.mnc NAA_based_mask/mask_fwhm.mnc
mincmath -clobber -mult NAA_based_mask/mask_snr.mnc NAA_based_mask/mask_fwhm.mnc NAA_based_mask/mask_naa_based.mnc
mincresample NAA_based_mask/mask_naa_based.mnc -like csi_template_zf.mnc NAA_based_mask/mask_naa_based.mncc  -tricubic -clobber


# ${out_dir}/maps/


		MAPS=${out_dir}/maps/Orig/*
	for f in $MAPS; do
			file_name=$(basename $f)		
			ext="${f##*.}"			
			echo "Mask $file_name with mask_new!"
			if [[ "$ext" = "mnc" ]]; then			
			mincmath -clobber -mult -quiet CRLB_Masked/mask_new.mnc $f Met_Maps_masked/${file_name}
			fi
			if [[ "$ext" = "mncc" ]]; then	
			mincmath -clobber -mult -quiet CRLB_Masked/mask_new.mncc $f Met_Maps_masked/${file_name}
			fi			
	done


		MAPS=${out_dir}/maps/Ratio/*
	for f in $MAPS; do
			file_name=$(basename $f)		
			ext="${f##*.}"			
			echo "Mask $file_name with mask_new!"
			if [[ "$ext" = "mnc" ]]; then
			mincmath -clobber -mult -quiet CRLB_Masked/mask_new.mnc $f Ratio_Maps_masked/${file_name}
			fi
			if [[ "$ext" = "mncc" ]]; then	
			mincmath -clobber -mult -quiet CRLB_Masked/mask_new.mncc $f Ratio_Maps_masked/${file_name}
			fi
	done

		MAPS=${out_dir}/maps/Extra/*
	for f in $MAPS; do
			file_name=$(basename $f)		
			ext="${f##*.}"			
			echo "Mask $file_name with mask_new!"
			if [[ "$ext" = "mnc" ]]; then
			mincmath -clobber -mult -quiet CRLB_Masked/mask_new.mnc $f Extra_Maps_masked/${file_name}
			fi
			if [[ "$ext" = "mncc" ]]; then	
			mincmath -clobber -mult -quiet CRLB_Masked/mask_new.mncc $f Extra_Maps_masked/${file_name}
			fi
	done

		MAPS=${out_dir}/maps/Outlier_Clip/*
	for f in $MAPS; do
			file_name=$(basename $f)		
			ext="${f##*.}"			
			echo "Mask $file_name with mask_new!"
			if [[ "$ext" = "mnc" ]]; then
			mincmath -clobber -mult -quiet CRLB_Masked/mask_new.mnc $f Met_Maps_Outlier_masked/${file_name}
			fi
			if [[ "$ext" = "mncc" ]]; then	
			mincmath -clobber -mult -quiet CRLB_Masked/mask_new.mncc $f Met_Maps_Outlier_masked/${file_name}
			fi
	done

		MAPS=${out_dir}/maps/QualityAndOutlier_Clip/*
	for f in $MAPS; do
			file_name=$(basename $f)		
			ext="${f##*.}"			
			echo "Mask $file_name with mask_new!"
			if [[ "$ext" = "mnc" ]]; then
			mincmath -clobber -mult -quiet CRLB_Masked/mask_new.mnc $f Met_Maps_Q_O_masked/${file_name}
			fi
			if [[ "$ext" = "mncc" ]]; then	
			mincmath -clobber -mult -quiet CRLB_Masked/mask_new.mncc $f Met_Maps_Q_O_masked/${file_name}
			fi
	done


##### new stuff

		MAPS=${out_dir}/maps/Orig/*
	for f in $MAPS; do
			file_name=$(basename $f)		
			ext="${f##*.}"			
			echo "Mask $file_name with mask_new!"
			if [[ "$ext" = "mnc" ]]; then			
			mincmath -clobber -mult -quiet NAA_based_mask/mask_naa_based.mnc $f Met_Maps_NAA_masked/${file_name}
			fi
			if [[ "$ext" = "mncc" ]]; then	
			mincmath -clobber -mult -quiet NAA_based_mask/mask_naa_based.mncc $f Met_Maps_NAA_masked/${file_name}
			fi			
	done

		MAPS=${out_dir}/maps/Outlier_Clip/*
	for f in $MAPS; do
			file_name=$(basename $f)		
			ext="${f##*.}"			
			echo "Mask $file_name with mask_new!"
			if [[ "$ext" = "mnc" ]]; then
			mincmath -clobber -mult -quiet NAA_based_mask/mask_naa_based.mnc $f Met_Maps_Outlier_NAA_masked/${file_name}
			fi
			if [[ "$ext" = "mncc" ]]; then	
			mincmath -clobber -mult -quiet NAA_based_mask/mask_naa_based.mncc $f Met_Maps_Outlier_NAA_masked/${file_name}
			fi
	done

		MAPS=${out_dir}/maps/QualityAndOutlier_Clip/*
	for f in $MAPS; do
			file_name=$(basename $f)		
			ext="${f##*.}"			
			echo "Mask $file_name with mask_new!"
			if [[ "$ext" = "mnc" ]]; then
			mincmath -clobber -mult -quiet NAA_based_mask/mask_naa_based.mnc $f Met_Maps_Q_O_NAA_masked/${file_name}
			fi
			if [[ "$ext" = "mncc" ]]; then	
			mincmath -clobber -mult -quiet NAA_based_mask/mask_naa_based.mncc $f Met_Maps_Q_O_NAA_masked/${file_name}
			fi
	done


###

		MAPS=${out_dir}/maps/Met_Maps_masked/*
	for f in $MAPS; do
			file_name=$(basename $f)		
			ext="${f##*.}"			
			echo "Mask $file_name with mask_new!"
			if [[ "$ext" = "mnc" ]]; then			
			mincmath -clobber -mult -quiet NAA_based_mask/mask_naa_based.mnc $f Met_Maps_double_masked/${file_name}
			fi
			if [[ "$ext" = "mncc" ]]; then	
			mincmath -clobber -mult -quiet NAA_based_mask/mask_naa_based.mncc $f Met_Maps_double_masked/${file_name}
			fi			
	done



##############crlb_setting



		MAPS=${out_dir}/maps/Met_Maps_NAA_masked/*
	for f in $MAPS; do
			file_name=$(basename $f)		
			ext="${f##*.}"			
			echo "Create mask for $file_name with CRLB_range 0-40!"
			if [[ "$ext" = "mnc" ]]; then			
			mincmath -clobber -const2 0.0001 40 -segment -quiet $f Met_Maps_NAA_masked/CRLB_masks/${file_name}
			fi			
	done


###############################newest: cr mask

		MAPS=${out_dir}/maps/Outlier_Clip/*
	for f in $MAPS; do
			file_name=$(basename $f)
			ext="${f##*.}"			
			echo "Mask $file_name with Cr mask (robust for tumors?)!"
			if [[ "$ext" = "mnc" ]]; then
			mincmath -clobber -mult -quiet Cr_Masked/mask_cr.mnc $f Met_Maps_Cr_O_masked/${file_name}
			fi
			if [[ "$ext" = "mncc" ]]; then	
			mincmath -clobber -mult -quiet Cr_Masked/mask_cr.mncc $f Met_Maps_Cr_O_masked/${file_name}
			fi
	done

###############################newest: cr mask ratios

		MAPS=${out_dir}/maps/Ratio/*
	for f in $MAPS; do
			file_name=$(basename $f)
			ext="${f##*.}"			
			echo "Mask $file_name with Cr mask (robust for tumors?)!"
			if [[ "$ext" = "mnc" ]]; then
			mincmath -clobber -mult -quiet Cr_Masked/mask_cr.mnc $f Ratio_Maps_Cr_O_masked/${file_name}
			fi
			if [[ "$ext" = "mncc" ]]; then	
			mincmath -clobber -mult -quiet Cr_Masked/mask_cr.mncc $f Ratio_Maps_Cr_O_masked/${file_name}
			fi
	done
