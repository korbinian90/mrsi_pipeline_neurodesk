##to do:
###integrate into main file with 2/3d command
### set up for brainlab dicom export too
# v9: checks for interpolate to magnitude flag

# Debugging
export out_dir='/ceph/mri.meduniwien.ac.at/departments/radiology/mrsbrain/lab/Process_Results/Tumor_Patients/Part2Debugging_Jan2021/Part1_Output_TP050_01/'
export outfolder_interpolation=1
export clinical_flag=0


# Make sure that the right software versions are used by adjusting the PATH
PATH=/opt/minc/bin/:$PATH

################## if interpolation is desired, do this: ##################
if [ $outfolder_interpolation == 1 ]; then # ... run Gilbert's old code
	cd ${out_dir}/maps/

	infolder=Met_Maps_Cr_O_masked
	outfolder=Export_Neuronav
	mkdir $outfolder

		echo -e "\nConverting to nii for the neuronavigation system. 3D version with interpolation! \n"

		cp magnitude.mnc $outfolder/
	    	# create upsampled MRSI template
		zstep_orig="$(mincinfo -attvalue zspace:step ./$infolder/NAA_amp_map.mnc)"
		zstep_temp="$(echo "scale=4; 0.47" | bc)"
		zstart="$(mincinfo -attvalue zspace:start ./$infolder/NAA_amp_map.mnc)"
		zstart_new="$(echo "scale=4; $zstart-$zstep_orig/2+$zstep_temp/2" | bc)"


		echo -e "\n\nTemplate "
		###naa + template
		##3D
		mincresample $infolder/NAA_amp_map.mnc -step -2.2 -2.2 2.2 -nelements 100 100 70 -zstart $zstart_new $outfolder/template.mnc -clobber >/dev/null 2>&1
		##2D
		#mincresample $infolder/NAA_amp_map.mnc -step -0.55 -0.55 0.588 -nelements 400 400 17 -zstart $zstart_new $outfolder/template.mnc -clobber

		mincresample $infolder/NAA_amp_map.mnc -like $outfolder/template.mnc $outfolder/naa.mncc -trilinear -clobber >/dev/null 2>&1
		mincresample $outfolder/naa.mncc -like $outfolder/magnitude.mnc $outfolder/naa_resT1.mncc -trilinear -clobber >/dev/null 2>&1
		mincmath -clobber -clamp -const2 0 9999 $outfolder/naa_resT1.mncc $outfolder/naa_clamped.mncc >/dev/null 2>&1
		mnc2nii -quiet -float ./$outfolder/naa_clamped.mncc ./$outfolder/naa.nii >/dev/null 2>&1

		##### Anatomical Images #####
		echo -e "\n\nAnatomical images "
		mnc2nii -quiet -float magnitude.mnc ./$outfolder/T1w_7T_reference.nii >/dev/null 2>&1
		mnc2nii -quiet -float flair.mnc ./$outfolder/flair.nii >/dev/null 2>&1

		##### Met Maps #####
		echo -e "\n\nMetabolic maps "
		##cho
		mincresample ./$infolder/GPC+PCh_amp_map.mnc -like ./$outfolder/template.mnc ./$outfolder/cho.mncc -trilinear -clobber >/dev/null 2>&1
		mincresample ./$outfolder/cho.mncc -like $outfolder/magnitude.mnc ./$outfolder/cho_resT1.mncc -trilinear -clobber >/dev/null 2>&1
		mincmath -clobber -clamp -const2 0 9999 ./$outfolder/cho_resT1.mncc ./$outfolder/cho_clamped.mncc >/dev/null 2>&1
		mnc2nii -quiet -float ./$outfolder/cho_clamped.mncc ./$outfolder/cho.nii >/dev/null 2>&1

		##cr
		mincresample ./$infolder/Cr+PCr_amp_map.mnc -like ./$outfolder/template.mnc ./$outfolder/cr.mncc -trilinear -clobber >/dev/null 2>&1
		mincresample ./$outfolder/cr.mncc -like $outfolder/magnitude.mnc ./$outfolder/cr_resT1.mncc -trilinear -clobber >/dev/null 2>&1
		mincmath -clobber -clamp -const2 0 9999 ./$outfolder/cr_resT1.mncc ./$outfolder/cr_clamped.mncc >/dev/null 2>&1
		mnc2nii -quiet -float ./$outfolder/cr_clamped.mncc ./$outfolder/cr.nii >/dev/null 2>&1	

		##ins
		mincresample ./$infolder/Ins_amp_map.mnc -like ./$outfolder/template.mnc ./$outfolder/ins.mncc -trilinear -clobber >/dev/null 2>&1 
		mincresample ./$outfolder/ins.mncc -like $outfolder/magnitude.mnc ./$outfolder/ins_resT1.mncc -trilinear -clobber >/dev/null 2>&1
		mincmath -clobber -clamp -const2 0 9999 ./$outfolder/ins_resT1.mncc ./$outfolder/ins_clamped.mncc >/dev/null 2>&1
		mnc2nii -quiet -float ./$outfolder/ins_clamped.mncc ./$outfolder/ins.nii >/dev/null 2>&1

		##gln
		mincresample ./$infolder/Gln_amp_map.mnc -like ./$outfolder/template.mnc ./$outfolder/gln.mncc -trilinear -clobber >/dev/null 2>&1
		mincresample ./$outfolder/gln.mncc -like $outfolder/magnitude.mnc ./$outfolder/gln_resT1.mncc -trilinear -clobber >/dev/null 2>&1
		mincmath -clobber -clamp -const2 0 9999 ./$outfolder/gln_resT1.mncc ./$outfolder/gln_clamped.mncc >/dev/null 2>&1
		mnc2nii -quiet -float ./$outfolder/gln_clamped.mncc ./$outfolder/gln.nii >/dev/null 2>&1 

		##glu
		mincresample ./$infolder/Glu_amp_map.mnc -like ./$outfolder/template.mnc ./$outfolder/glu.mncc -trilinear -clobber >/dev/null 2>&1
		mincresample ./$outfolder/glu.mncc -like $outfolder/magnitude.mnc ./$outfolder/glu_resT1.mncc -trilinear -clobber >/dev/null 2>&1
		mincmath -clobber -clamp -const2 0 9999 ./$outfolder/glu_resT1.mncc ./$outfolder/glu_clamped.mncc >/dev/null 2>&1
		mnc2nii -quiet -float ./$outfolder/glu_clamped.mncc ./$outfolder/glu.nii >/dev/null 2>&1

		##gly
		mincresample ./$infolder/Gly_amp_map.mnc -like ./$outfolder/template.mnc ./$outfolder/gly.mncc -trilinear -clobber >/dev/null 2>&1
		mincresample ./$outfolder/gly.mncc -like $outfolder/magnitude.mnc ./$outfolder/gly_resT1.mncc -trilinear -clobber >/dev/null 2>&1
		mincmath -clobber -clamp -const2 0 9999 ./$outfolder/gly_resT1.mncc ./$outfolder/gly_clamped.mncc >/dev/null 2>&1
		mnc2nii -quiet -float ./$outfolder/gly_clamped.mncc ./$outfolder/gly.nii >/dev/null 2>&1

		##### Ratios ##### 
		echo -e "\n\nRatio maps "
		##gln2naa
		mincmath -clobber -zero -div $infolder/Gln_amp_map.mnc $infolder/NAA+NAAG_amp_map.mnc $outfolder/gln2naa.mnc >/dev/null 2>&1
		mincmath -clobber -clamp -const2 0 10 $outfolder/gln2naa.mnc $outfolder/gln2naa_clamped.mnc >/dev/null 2>&1
		mincresample ./$outfolder/gln2naa_clamped.mnc -like ./$outfolder/template.mnc ./$outfolder/gln2naa.mncc -trilinear -clobber >/dev/null 2>&1
		mincresample ./$outfolder/gln2naa.mncc -like $outfolder/magnitude.mnc ./$outfolder/gln2naa_resT1.mncc -trilinear -clobber >/dev/null 2>&1
		mincmath -clobber -clamp -const2 0 9999 ./$outfolder/gln2naa_resT1.mncc ./$outfolder/gln2naa_clamped.mncc >/dev/null 2>&1
		mnc2nii -quiet -float ./$outfolder/gln2naa_clamped.mncc ./$outfolder/gln2naa.nii >/dev/null 2>&1

		##gly2naa
		mincmath -clobber -zero -div $infolder/Gly_amp_map.mnc $infolder/NAA+NAAG_amp_map.mnc $outfolder/gly2naa.mnc >/dev/null 2>&1
		mincmath -clobber -clamp -const2 0 10 $outfolder/gly2naa.mnc $outfolder/gly2naa_clamped.mnc >/dev/null 2>&1
		mincresample ./$outfolder/gly2naa_clamped.mnc -like ./$outfolder/template.mnc ./$outfolder/gly2naa.mncc -trilinear -clobber >/dev/null 2>&1
		mincresample ./$outfolder/gly2naa.mncc -like $outfolder/magnitude.mnc ./$outfolder/gly2naa_resT1.mncc -trilinear -clobber >/dev/null 2>&1
		mincmath -clobber -clamp -const2 0 9999 ./$outfolder/gly2naa_resT1.mncc ./$outfolder/gly2naa_clamped.mncc >/dev/null 2>&1
		mnc2nii -quiet -float ./$outfolder/gly2naa_clamped.mncc ./$outfolder/gly2naa.nii >/dev/null 2>&1

		##cho2naa
		mincmath -clobber -zero -div ./$infolder/GPC+PCh_amp_map.mnc ./$infolder/NAA+NAAG_amp_map.mnc ./$outfolder/cho2naa.mnc >/dev/null 2>&1
		mincmath -clobber -clamp -const2 0 10 $outfolder/cho2naa.mnc ./$outfolder/cho2naa_clamped.mnc >/dev/null 2>&1
		mincresample ./$outfolder/cho2naa_clamped.mnc -like ./$outfolder/template.mnc ./$outfolder/cho2naa.mncc -trilinear -clobber >/dev/null 2>&1
		mincresample ./$outfolder/cho2naa.mncc -like $outfolder/magnitude.mnc ./$outfolder/cho2naa_resT1.mncc -trilinear -clobber >/dev/null 2>&1
		mincmath -clobber -clamp -const2 0 9999 ./$outfolder/cho2naa_resT1.mncc ./$outfolder/cho2naa_clamped.mncc >/dev/null 2>&1
		mnc2nii -quiet -float ./$outfolder/cho2naa_clamped.mncc ./$outfolder/cho2naa.nii >/dev/null 2>&1

		##ins2naa
		mincmath -clobber -zero -div ./$infolder/Ins_amp_map.mnc ./$infolder/NAA+NAAG_amp_map.mnc ./$outfolder/ins2naa.mnc >/dev/null 2>&1
		mincmath -clobber -clamp -const2 0 10 $outfolder/ins2naa.mnc ./$outfolder/ins2naa_clamped.mnc >/dev/null 2>&1
		mincresample ./$outfolder/ins2naa_clamped.mnc -like ./$outfolder/template.mnc ./$outfolder/ins2naa.mncc -trilinear -clobber >/dev/null 2>&1
		mincresample ./$outfolder/ins2naa.mncc -like $outfolder/magnitude.mnc ./$outfolder/ins2naa_resT1.mncc -trilinear -clobber >/dev/null 2>&1
		mincmath -clobber -clamp -const2 0 9999 ./$outfolder/ins2naa_resT1.mncc ./$outfolder/ins2naa_clamped.mncc >/dev/null 2>&1
		mnc2nii -quiet -float ./$outfolder/ins2naa_clamped.mncc ./$outfolder/ins2naa.nii >/dev/null 2>&1

		##### Non-clinical ratios #####
		# If this script is used for figures (i.e. not just for the clinicians), then clinical_flag != 1 and this happens:
		if ! [ $clinical_flag == 1 ]; then
		echo -e "\n\nAdditional metabolic ratio maps "
			# gln2cr
			mincmath -clobber -zero -div $infolder/Gln_amp_map.mnc $infolder/Cr+PCr_amp_map.mnc $outfolder/gln2cr.mnc >/dev/null 2>&1
			mincmath -clobber -clamp -const2 0 10 $outfolder/gln2cr.mnc $outfolder/gln2cr_clamped.mnc >/dev/null 2>&1
			mincresample ./$outfolder/gln2cr_clamped.mnc -like ./$outfolder/template.mnc ./$outfolder/gln2cr.mncc -trilinear -clobber >/dev/null 2>&1
			mincresample ./$outfolder/gln2cr.mncc -like $outfolder/magnitude.mnc ./$outfolder/gln2cr_resT1.mncc -trilinear -clobber >/dev/null 2>&1
			mincmath -clobber -clamp -const2 0 9999 ./$outfolder/gln2cr_resT1.mncc ./$outfolder/gln2cr_clamped.mncc >/dev/null 2>&1
			mnc2nii -quiet -float ./$outfolder/gln2cr_clamped.mncc ./$outfolder/gln2cr.nii >/dev/null 2>&1

			# gly2cr
			mincmath -clobber -zero -div $infolder/Gly_amp_map.mnc $infolder/Cr+PCr_amp_map.mnc $outfolder/gly2cr.mnc >/dev/null 2>&1
			mincmath -clobber -clamp -const2 0 10 $outfolder/gly2cr.mnc $outfolder/gly2cr_clamped.mnc >/dev/null 2>&1
			mincresample ./$outfolder/gly2cr_clamped.mnc -like ./$outfolder/template.mnc ./$outfolder/gly2cr.mncc -trilinear -clobber >/dev/null 2>&1
			mincresample ./$outfolder/gly2cr.mncc -like $outfolder/magnitude.mnc ./$outfolder/gly2cr_resT1.mncc -trilinear -clobber >/dev/null 2>&1
			mincmath -clobber -clamp -const2 0 9999 ./$outfolder/gly2cr_resT1.mncc ./$outfolder/gly2cr_clamped.mncc >/dev/null 2>&1
			mnc2nii -quiet -float ./$outfolder/gly2cr_clamped.mncc ./$outfolder/gly2cr.nii >/dev/null 2>&1

			# cho2cr
			mincmath -clobber -zero -div ./$infolder/GPC+PCh_amp_map.mnc ./$infolder/Cr+PCr_amp_map.mnc ./$outfolder/cho2cr.mnc >/dev/null 2>&1
			mincmath -clobber -clamp -const2 0 10 ./$outfolder/cho2cr.mnc ./$outfolder/cho2cr_clamped.mnc >/dev/null 2>&1
			mincresample ./$outfolder/cho2cr_clamped.mnc -like ./$outfolder/template.mnc ./$outfolder/cho2cr.mncc -trilinear -clobber >/dev/null 2>&1
			mincresample ./$outfolder/cho2cr.mncc -like $outfolder/magnitude.mnc ./$outfolder/cho2cr_resT1.mncc -trilinear -clobber >/dev/null 2>&1
			mincmath -clobber -clamp -const2 0 9999 ./$outfolder/cho2cr_resT1.mncc ./$outfolder/cho2cr_clamped.mncc >/dev/null 2>&1
			mnc2nii -quiet -float ./$outfolder/cho2cr_clamped.mncc ./$outfolder/cho2cr.nii >/dev/null 2>&1

			# ins2cr
			mincmath -clobber -zero -div ./$infolder/Ins_amp_map.mnc ./$infolder/Cr+PCr_amp_map.mnc ./$outfolder/ins2cr.mnc >/dev/null 2>&1
			mincmath -clobber -clamp -const2 0 10 ./$outfolder/ins2cr.mnc ./$outfolder/ins2cr_clamped.mnc >/dev/null 2>&1
			mincresample ./$outfolder/ins2cr_clamped.mnc -like ./$outfolder/template.mnc ./$outfolder/ins2cr.mncc -trilinear -clobber >/dev/null 2>&1
			mincresample ./$outfolder/ins2cr.mncc -like $outfolder/magnitude.mnc ./$outfolder/ins2cr_resT1.mncc -trilinear -clobber >/dev/null 2>&1
			mincmath -clobber -clamp -const2 0 9999 ./$outfolder/ins2cr_resT1.mncc ./$outfolder/ins2cr_clamped.mncc >/dev/null 2>&1
			mnc2nii -quiet -float ./$outfolder/ins2cr_clamped.mncc ./$outfolder/ins2cr.nii >/dev/null 2>&1
		fi


################## if interpolation is not desired, do this instead (WIP): ##################

elif ! [ $outfolder_interpolation == 1 ]; then
	cd ${out_dir}/maps/
	infolder=Met_Maps_Cr_O_masked
	outfolder=Export_Neuronav_native
	mkdir $outfolder

	echo -e "\nConverting to nii for the neuronavigation system. 3D version without von interpolation! \n"

		cp magnitude.mnc $outfolder/
	    	# create upsampled MRSI template
		zstep_orig="$(mincinfo -attvalue zspace:step ./$infolder/NAA_amp_map.mnc)"
		zstep_temp="$(echo "scale=4; 0.47" | bc)"
		zstart="$(mincinfo -attvalue zspace:start ./$infolder/NAA_amp_map.mnc)"
		zstart_new="$(echo "scale=4; $zstart-$zstep_orig/2+$zstep_temp/2" | bc)"

		###naa + template
		##3D
#		mincresample $infolder/NAA_amp_map.mnc -step -2.2 -2.2 2.2 -nelements 100 100 70 -zstart $zstart_new $outfolder/template.mnc -clobber

		cp ./$infolder/NAA_amp_map.mnc $outfolder/naa.mncc
		mincmath -clobber -clamp -const2 0 9999 $outfolder/naa.mncc $outfolder/naa_clamped.mncc
		mnc2nii -quiet -float ./$outfolder/naa_clamped.mncc ./$outfolder/naa.nii >/dev/null 2>&1
		
		##### Anatomical Images #####
		echo -e "\nAnatomical images "
		mnc2nii -quiet -float magnitude.mnc ./$outfolder/T1w_7T_reference.nii >/dev/null 2>&1
		mnc2nii -quiet -float flair.mnc ./$outfolder/flair.nii >/dev/null 2>&1

		##### Met Maps #####
		echo -e "\n\nMetabolic maps \n"
		##cho
		cp ./$infolder/GPC+PCh_amp_map.mnc ./$outfolder/cho.mncc
		mincmath -clobber -clamp -const2 0 9999 ./$outfolder/cho.mncc ./$outfolder/cho_clamped.mncc
		mnc2nii -quiet -float ./$outfolder/cho_clamped.mncc ./$outfolder/cho.nii >/dev/null 2>&1

		##cr
		cp ./$infolder/Cr+PCr_amp_map.mnc ./$outfolder/cr.mncc 
		mincmath -clobber -clamp -const2 0 9999 ./$outfolder/cr.mncc ./$outfolder/cr_clamped.mncc
		mnc2nii -quiet -float ./$outfolder/cr_clamped.mncc ./$outfolder/cr.nii >/dev/null 2>&1	

		##ins
		cp ./$infolder/Ins_amp_map.mnc ./$outfolder/ins.mncc 
		mincmath -clobber -clamp -const2 0 9999 ./$outfolder/ins.mncc ./$outfolder/ins_clamped.mncc
		mnc2nii -quiet -float ./$outfolder/ins_clamped.mncc ./$outfolder/ins.nii >/dev/null 2>&1

		##gln
		cp ./$infolder/Gln_amp_map.mnc ./$outfolder/gln.mncc 
		mincmath -clobber -clamp -const2 0 9999 ./$outfolder/gln.mncc ./$outfolder/gln_clamped.mncc
		mnc2nii -quiet -float ./$outfolder/gln_clamped.mncc ./$outfolder/gln.nii >/dev/null 2>&1

		##glu
		cp ./$infolder/Glu_amp_map.mnc ./$outfolder/glu.mncc 
		mincmath -clobber -clamp -const2 0 9999 ./$outfolder/glu.mncc ./$outfolder/glu_clamped.mncc
		mnc2nii -quiet -float ./$outfolder/glu_clamped.mncc ./$outfolder/glu.nii >/dev/null 2>&1

		##gly
		cp ./$infolder/Gly_amp_map.mnc ./$outfolder/gly.mncc 
		mincmath -clobber -clamp -const2 0 9999 ./$outfolder/gly.mncc ./$outfolder/gly_clamped.mncc
		mnc2nii -quiet -float ./$outfolder/gly_clamped.mncc ./$outfolder/gly.nii >/dev/null 2>&1

		##### Ratios ##### 
		echo -e "\n\nRatio maps \n"
		##gln2naa
		mincmath -clobber -zero -div $infolder/Gln_amp_map.mnc $infolder/NAA+NAAG_amp_map.mnc $outfolder/gln2naa.mnc
		mincmath -clobber -clamp -const2 0 10 $outfolder/gln2naa.mnc $outfolder/gln2naa_clamped.mnc
		mv ./$outfolder/gln2naa_clamped.mnc ./$outfolder/gln2naa.mncc 
		mincmath -clobber -clamp -const2 0 9999 ./$outfolder/gln2naa.mncc ./$outfolder/gln2naa_clamped.mncc
		mnc2nii -quiet -float ./$outfolder/gln2naa_clamped.mncc ./$outfolder/gln2naa.nii >/dev/null 2>&1

		##gly2naa
		mincmath -clobber -zero -div $infolder/Gly_amp_map.mnc $infolder/NAA+NAAG_amp_map.mnc $outfolder/gly2naa.mnc
		mincmath -clobber -clamp -const2 0 10 $outfolder/gly2naa.mnc $outfolder/gly2naa_clamped.mnc
		mv ./$outfolder/gly2naa_clamped.mnc ./$outfolder/gly2naa.mncc 
		mincmath -clobber -clamp -const2 0 9999 ./$outfolder/gly2naa.mncc ./$outfolder/gly2naa_clamped.mncc
		mnc2nii -quiet -float ./$outfolder/gly2naa_clamped.mncc ./$outfolder/gly2naa.nii >/dev/null 2>&1

		##cho2naa
		mincmath -clobber -zero -div ./$infolder/GPC+PCh_amp_map.mnc ./$infolder/NAA+NAAG_amp_map.mnc ./$outfolder/cho2naa.mnc
		mincmath -clobber -clamp -const2 0 10 $outfolder/cho2naa.mnc ./$outfolder/cho2naa_clamped.mnc
		mv ./$outfolder/cho2naa_clamped.mnc ./$outfolder/cho2naa.mncc 
		mincmath -clobber -clamp -const2 0 9999 ./$outfolder/cho2naa.mncc ./$outfolder/cho2naa_clamped.mncc
		mnc2nii -quiet -float ./$outfolder/cho2naa_clamped.mncc ./$outfolder/cho2naa.nii >/dev/null 2>&1

		##ins2naa
		mincmath -clobber -zero -div ./$infolder/Ins_amp_map.mnc ./$infolder/NAA+NAAG_amp_map.mnc ./$outfolder/ins2naa.mnc
		mincmath -clobber -clamp -const2 0 10 $outfolder/ins2naa.mnc ./$outfolder/ins2naa_clamped.mnc
		mv ./$outfolder/ins2naa_clamped.mnc ./$outfolder/ins2naa.mncc 
		mincmath -clobber -clamp -const2 0 9999 ./$outfolder/ins2naa.mncc ./$outfolder/ins2naa_clamped.mncc
		mnc2nii -quiet -float ./$outfolder/ins2naa_clamped.mncc ./$outfolder/ins2naa.nii >/dev/null 2>&1

		##### Non-clinical ratios #####
		# If this script is used because we need stuff for figures (i.e. if it is not just done for the clinicians), then clinical_flag != 0 and this happens:
		if ! [ $clinical_flag == 1 ]; then
		echo -e "\n\nAdditional metabolic ratio maps \n"
			#gln2cr
			mincmath -clobber -zero -div $infolder/Gln_amp_map.mnc $infolder/Cr+PCr_amp_map.mnc $outfolder/gln2cr.mnc
			mincmath -clobber -clamp -const2 0 10 $outfolder/gln2cr.mnc $outfolder/gln2cr_clamped.mnc	
			mv ./$outfolder/gln2cr_clamped.mnc ./$outfolder/gln2cr.mncc 
			mincmath -clobber -clamp -const2 0 9999 ./$outfolder/gln2cr.mncc ./$outfolder/gln2cr_clamped.mncc
			mnc2nii -quiet -float ./$outfolder/gln2cr_clamped.mncc ./$outfolder/gln2cr.nii >/dev/null 2>&1

			#gly2cr
			mincmath -clobber -zero -div $infolder/Gly_amp_map.mnc $infolder/Cr+PCr_amp_map.mnc $outfolder/gly2cr.mnc
			mincmath -clobber -clamp -const2 0 10 $outfolder/gly2cr.mnc $outfolder/gly2cr_clamped.mnc	
			mv ./$outfolder/gly2cr_clamped.mnc ./$outfolder/gly2cr.mncc 
			mincmath -clobber -clamp -const2 0 9999 ./$outfolder/gly2cr.mncc ./$outfolder/gly2cr_clamped.mncc
			mnc2nii -quiet -float ./$outfolder/gly2cr_clamped.mncc ./$outfolder/gly2cr.nii >/dev/null 2>&1

			##cho2cr
			mincmath -clobber -zero -div ./$infolder/GPC+PCh_amp_map.mnc ./$infolder/Cr+PCr_amp_map.mnc ./$outfolder/cho2cr.mnc
			mincmath -clobber -clamp -const2 0 10 ./$outfolder/cho2cr.mnc ./$outfolder/cho2cr_clamped.mnc
			mv ./$outfolder/cho2cr_clamped.mnc ./$outfolder/cho2cr.mncc 
			mincmath -clobber -clamp -const2 0 9999 ./$outfolder/cho2cr.mncc ./$outfolder/cho2cr_clamped.mncc
			mnc2nii -quiet -float ./$outfolder/cho2cr_clamped.mncc ./$outfolder/cho2cr.nii >/dev/null 2>&1

			##ins2cr
			mincmath -clobber -zero -div ./$infolder/Ins_amp_map.mnc ./$infolder/Cr+PCr_amp_map.mnc ./$outfolder/ins2cr.mnc
			mincmath -clobber -clamp -const2 0 10 ./$outfolder/ins2cr.mnc ./$outfolder/ins2cr_clamped.mnc
			mv ./$outfolder/ins2cr_clamped.mnc ./$outfolder/ins2cr.mncc 
			mincmath -clobber -clamp -const2 0 9999 ./$outfolder/ins2cr.mncc ./$outfolder/ins2cr_clamped.mncc
			mnc2nii -quiet -float ./$outfolder/ins2cr_clamped.mncc ./$outfolder/ins2cr.nii >/dev/null 2>&1
		fi
else
	echo "WARNING: Unexpected situation in NeuroNav conversion script."
fi

##### Zip niftis, remove mincs, finish script #####

echo -e "\nWrapping things up... "
gzip -f $outfolder/*.nii
rm -f $outfolder/*.mnc
rm -f $outfolder/*.mncc
echo -e "NeuroNav script completed.\n"

	###insert remove of priors!
	###add other mets
