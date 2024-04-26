##to do:
### set up for brainlab dicom export too

cd ${out_dir}/maps/

mkdir Export_Neuronav

	echo -e "\nConverting to nii for the Neuronavigation system. 3D version!  \n"

	cp magnitude.mnc Export_Neuronav/
    	# create upsampled MRSI template
	zstep_orig="$(mincinfo -attvalue zspace:step ./Met_Maps_Cr_O_masked/NAA_amp_map.mnc)"
	zstep_temp="$(echo "scale=4; 0.47" | bc)"
	zstart="$(mincinfo -attvalue zspace:start ./Met_Maps_Cr_O_masked/NAA_amp_map.mnc)"
	zstart_new="$(echo "scale=4; $zstart-$zstep_orig/2+$zstep_temp/2" | bc)"

	###naa + template
	##3D
	mincresample Met_Maps_Cr_O_masked/NAA_amp_map.mnc -step -2.2 -2.2 2.2 -nelements 100 100 70 -zstart $zstart_new Export_Neuronav/template.mnc -clobber
	##2D
	#mincresample Met_Maps_Cr_O_masked/NAA_amp_map.mnc -step -0.55 -0.55 0.588 -nelements 400 400 17 -zstart $zstart_new Export_Neuronav/template.mnc -clobber

	mincresample Met_Maps_Cr_O_masked/NAA_amp_map.mnc -like Export_Neuronav/template.mnc Export_Neuronav/naa.mncc -trilinear -clobber
	mincresample Export_Neuronav/naa.mncc -like Export_Neuronav/magnitude.mnc Export_Neuronav/naa_resT1.mncc -trilinear -clobber
	mincmath -clobber -clamp -const2 0 9999 Export_Neuronav/naa_resT1.mncc Export_Neuronav/naa_clamped.mncc

	mnc2nii -quiet -float ./Export_Neuronav/naa_clamped.mncc ./Export_Neuronav/naa.nii
	###T1w
	mnc2nii -quiet -float magnitude.mnc ./Export_Neuronav/T1w_7T_reference.nii
	mnc2nii -quiet -float flair.mnc ./Export_Neuronav/flair.nii

	##cho
	mincresample ./Met_Maps_Cr_O_masked/GPC+PCh_amp_map.mnc -like ./Export_Neuronav/template.mnc ./Export_Neuronav/cho.mncc -trilinear -clobber
	mincresample ./Export_Neuronav/cho.mncc -like Export_Neuronav/magnitude.mnc ./Export_Neuronav/cho_resT1.mncc -trilinear -clobber
	mincmath -clobber -clamp -const2 0 9999 ./Export_Neuronav/cho_resT1.mncc ./Export_Neuronav/cho_clamped.mncc
	mnc2nii -quiet -float ./Export_Neuronav/cho_clamped.mncc ./Export_Neuronav/cho.nii

	##cr
	mincresample ./Met_Maps_Cr_O_masked/Cr+PCr_amp_map.mnc -like ./Export_Neuronav/template.mnc ./Export_Neuronav/cr.mncc -trilinear -clobber
	mincresample ./Export_Neuronav/cr.mncc -like Export_Neuronav/magnitude.mnc ./Export_Neuronav/cr_resT1.mncc -trilinear -clobber
	mincmath -clobber -clamp -const2 0 9999 ./Export_Neuronav/cr_resT1.mncc ./Export_Neuronav/cr_clamped.mncc
	mnc2nii -quiet -float ./Export_Neuronav/cr_clamped.mncc ./Export_Neuronav/cr.nii	

	##ins
	mincresample ./Met_Maps_Cr_O_masked/Ins_amp_map.mnc -like ./Export_Neuronav/template.mnc ./Export_Neuronav/ins.mncc -trilinear -clobber
	mincresample ./Export_Neuronav/ins.mncc -like Export_Neuronav/magnitude.mnc ./Export_Neuronav/ins_resT1.mncc -trilinear -clobber
	mincmath -clobber -clamp -const2 0 9999 ./Export_Neuronav/ins_resT1.mncc ./Export_Neuronav/ins_clamped.mncc
	mnc2nii -quiet -float ./Export_Neuronav/ins_clamped.mncc ./Export_Neuronav/ins.nii

	##gln
	mincresample ./Met_Maps_Cr_O_masked/Gln_amp_map.mnc -like ./Export_Neuronav/template.mnc ./Export_Neuronav/gln.mncc -trilinear -clobber
	mincresample ./Export_Neuronav/gln.mncc -like Export_Neuronav/magnitude.mnc ./Export_Neuronav/gln_resT1.mncc -trilinear -clobber
	mincmath -clobber -clamp -const2 0 9999 ./Export_Neuronav/gln_resT1.mncc ./Export_Neuronav/gln_clamped.mncc
	mnc2nii -quiet -float ./Export_Neuronav/gln_clamped.mncc ./Export_Neuronav/gln.nii

	##glu
	mincresample ./Met_Maps_Cr_O_masked/Glu_amp_map.mnc -like ./Export_Neuronav/template.mnc ./Export_Neuronav/glu.mncc -trilinear -clobber
	mincresample ./Export_Neuronav/glu.mncc -like Export_Neuronav/magnitude.mnc ./Export_Neuronav/glu_resT1.mncc -trilinear -clobber
	mincmath -clobber -clamp -const2 0 9999 ./Export_Neuronav/glu_resT1.mncc ./Export_Neuronav/glu_clamped.mncc
	mnc2nii -quiet -float ./Export_Neuronav/glu_clamped.mncc ./Export_Neuronav/glu.nii

	##gly
	mincresample ./Met_Maps_Cr_O_masked/Gly_amp_map.mnc -like ./Export_Neuronav/template.mnc ./Export_Neuronav/gly.mncc -trilinear -clobber
	mincresample ./Export_Neuronav/gly.mncc -like Export_Neuronav/magnitude.mnc ./Export_Neuronav/gly_resT1.mncc -trilinear -clobber
	mincmath -clobber -clamp -const2 0 9999 ./Export_Neuronav/gly_resT1.mncc ./Export_Neuronav/gly_clamped.mncc
	mnc2nii -quiet -float ./Export_Neuronav/gly_clamped.mncc ./Export_Neuronav/gly.nii


	##gln2naa
	mincmath -clobber -zero -div Met_Maps_Cr_O_masked/Gln_amp_map.mnc Met_Maps_Cr_O_masked/NAA+NAAG_amp_map.mnc Export_Neuronav/gln2naa.mnc
	mincmath -clobber -clamp -const2 0 10 Export_Neuronav/gln2naa.mnc Export_Neuronav/gln2naa_clamped.mnc
	mincresample ./Export_Neuronav/gln2naa_clamped.mnc -like ./Export_Neuronav/template.mnc ./Export_Neuronav/gln2naa.mncc -trilinear -clobber
	mincresample ./Export_Neuronav/gln2naa.mncc -like Export_Neuronav/magnitude.mnc ./Export_Neuronav/gln2naa_resT1.mncc -trilinear -clobber
	mincmath -clobber -clamp -const2 0 9999 ./Export_Neuronav/gln2naa_resT1.mncc ./Export_Neuronav/gln2naa_clamped.mncc
	mnc2nii -quiet -float ./Export_Neuronav/gln2naa_clamped.mncc ./Export_Neuronav/gln2naa.nii

	##gln2cr
	#mincmath -clobber -zero -div Met_Maps_Cr_O_masked/Gln_amp_map.mnc Met_Maps_Cr_O_masked/Cr+PCr_amp_map.mnc Export_Neuronav/gln2cr.mnc
	#mincmath -clobber -clamp -const2 0 10 Export_Neuronav/gln2cr.mnc Export_Neuronav/gln2cr_clamped.mnc	
	#mincresample ./Export_Neuronav/gln2cr_clamped.mnc -like ./Export_Neuronav/template.mnc ./Export_Neuronav/gln2cr.mncc -trilinear -clobber
	#mincresample ./Export_Neuronav/gln2cr.mncc -like Export_Neuronav/magnitude.mnc ./Export_Neuronav/gln2cr_resT1.mncc -trilinear -clobber
	#mincmath -clobber -clamp -const2 0 9999 ./Export_Neuronav/gln2cr_resT1.mncc ./Export_Neuronav/gln2cr_clamped.mncc
	#mnc2nii -quiet -float ./Export_Neuronav/gln2cr_clamped.mncc ./Export_Neuronav/gln2cr.nii


	##gly2naa
	mincmath -clobber -zero -div Met_Maps_Cr_O_masked/Gly_amp_map.mnc Met_Maps_Cr_O_masked/NAA+NAAG_amp_map.mnc Export_Neuronav/gly2naa.mnc
	mincmath -clobber -clamp -const2 0 10 Export_Neuronav/gly2naa.mnc Export_Neuronav/gly2naa_clamped.mnc
	mincresample ./Export_Neuronav/gly2naa_clamped.mnc -like ./Export_Neuronav/template.mnc ./Export_Neuronav/gly2naa.mncc -trilinear -clobber
	mincresample ./Export_Neuronav/gly2naa.mncc -like Export_Neuronav/magnitude.mnc ./Export_Neuronav/gly2naa_resT1.mncc -trilinear -clobber
	mincmath -clobber -clamp -const2 0 9999 ./Export_Neuronav/gly2naa_resT1.mncc ./Export_Neuronav/gly2naa_clamped.mncc
	mnc2nii -quiet -float ./Export_Neuronav/gly2naa_clamped.mncc ./Export_Neuronav/gly2naa.nii

	##gly2cr
#	mincmath -clobber -zero -div Met_Maps_Cr_O_masked/Gly_amp_map.mnc Met_Maps_Cr_O_masked/Cr+PCr_amp_map.mnc Export_Neuronav/gly2cr.mnc
#	mincmath -clobber -clamp -const2 0 10 Export_Neuronav/gly2cr.mnc Export_Neuronav/gly2cr_clamped.mnc	
#	mincresample ./Export_Neuronav/gly2cr_clamped.mnc -like ./Export_Neuronav/template.mnc ./Export_Neuronav/gly2cr.mncc -trilinear -clobber
#	mincresample ./Export_Neuronav/gly2cr.mncc -like Export_Neuronav/magnitude.mnc ./Export_Neuronav/gly2cr_resT1.mncc -trilinear -clobber
#	mincmath -clobber -clamp -const2 0 9999 ./Export_Neuronav/gly2cr_resT1.mncc ./Export_Neuronav/gly2cr_clamped.mncc
#	mnc2nii -quiet -float ./Export_Neuronav/gly2cr_clamped.mncc ./Export_Neuronav/gly2cr.nii


	##cho2naa
	mincmath -clobber -zero -div ./Met_Maps_Cr_O_masked/GPC+PCh_amp_map.mnc ./Met_Maps_Cr_O_masked/NAA+NAAG_amp_map.mnc ./Export_Neuronav/cho2naa.mnc
	mincmath -clobber -clamp -const2 0 10 Export_Neuronav/cho2naa.mnc ./Export_Neuronav/cho2naa_clamped.mnc
	mincresample ./Export_Neuronav/cho2naa_clamped.mnc -like ./Export_Neuronav/template.mnc ./Export_Neuronav/cho2naa.mncc -trilinear -clobber
	mincresample ./Export_Neuronav/cho2naa.mncc -like Export_Neuronav/magnitude.mnc ./Export_Neuronav/cho2naa_resT1.mncc -trilinear -clobber
	mincmath -clobber -clamp -const2 0 9999 ./Export_Neuronav/cho2naa_resT1.mncc ./Export_Neuronav/cho2naa_clamped.mncc
	mnc2nii -quiet -float ./Export_Neuronav/cho2naa_clamped.mncc ./Export_Neuronav/cho2naa.nii

	##cho2cr
#	mincmath -clobber -zero -div ./Met_Maps_Cr_O_masked/GPC+PCh_amp_map.mnc ./Met_Maps_Cr_O_masked/Cr+PCr_amp_map.mnc ./Export_Neuronav/cho2cr.mnc
#	mincmath -clobber -clamp -const2 0 10 ./Export_Neuronav/cho2cr.mnc ./Export_Neuronav/cho2cr_clamped.mnc
#	mincresample ./Export_Neuronav/cho2cr_clamped.mnc -like ./Export_Neuronav/template.mnc ./Export_Neuronav/cho2cr.mncc -trilinear -clobber
#	mincresample ./Export_Neuronav/cho2cr.mncc -like Export_Neuronav/magnitude.mnc ./Export_Neuronav/cho2cr_resT1.mncc -trilinear -clobber
#	mincmath -clobber -clamp -const2 0 9999 ./Export_Neuronav/cho2cr_resT1.mncc ./Export_Neuronav/cho2cr_clamped.mncc
#	mnc2nii -quiet -float ./Export_Neuronav/cho2cr_clamped.mncc ./Export_Neuronav/cho2cr.nii


	##ins2naa
	mincmath -clobber -zero -div ./Met_Maps_Cr_O_masked/Ins_amp_map.mnc ./Met_Maps_Cr_O_masked/NAA+NAAG_amp_map.mnc ./Export_Neuronav/ins2naa.mnc
	mincmath -clobber -clamp -const2 0 10 Export_Neuronav/ins2naa.mnc ./Export_Neuronav/ins2naa_clamped.mnc
	mincresample ./Export_Neuronav/ins2naa_clamped.mnc -like ./Export_Neuronav/template.mnc ./Export_Neuronav/ins2naa.mncc -trilinear -clobber
	mincresample ./Export_Neuronav/ins2naa.mncc -like Export_Neuronav/magnitude.mnc ./Export_Neuronav/ins2naa_resT1.mncc -trilinear -clobber
	mincmath -clobber -clamp -const2 0 9999 ./Export_Neuronav/ins2naa_resT1.mncc ./Export_Neuronav/ins2naa_clamped.mncc
	mnc2nii -quiet -float ./Export_Neuronav/ins2naa_clamped.mncc ./Export_Neuronav/ins2naa.nii

	##ins2cr
#	mincmath -clobber -zero -div ./Met_Maps_Cr_O_masked/Ins_amp_map.mnc ./Met_Maps_Cr_O_masked/Cr+PCr_amp_map.mnc ./Export_Neuronav/ins2cr.mnc
#	mincmath -clobber -clamp -const2 0 10 ./Export_Neuronav/ins2cr.mnc ./Export_Neuronav/ins2cr_clamped.mnc
#	mincresample ./Export_Neuronav/ins2cr_clamped.mnc -like ./Export_Neuronav/template.mnc ./Export_Neuronav/ins2cr.mncc -trilinear -clobber
#	mincresample ./Export_Neuronav/ins2cr.mncc -like Export_Neuronav/magnitude.mnc ./Export_Neuronav/ins2cr_resT1.mncc -trilinear -clobber
#	mincmath -clobber -clamp -const2 0 9999 ./Export_Neuronav/ins2cr_resT1.mncc ./Export_Neuronav/ins2cr_clamped.mncc
#	mnc2nii -quiet -float ./Export_Neuronav/ins2cr_clamped.mncc ./Export_Neuronav/ins2cr.nii


	echo -e "\nNow the CE maps.  \n"

for met_in in Cr+PCr Glu GPC+PCh Ins NAA; do 	#Cr+PCr Gln Glu Gly GPC+PCh GSH Ins NAA NAAG Ser Tau
	# set out variable
	case ${met_in} in 
		"Cr+PCr") met_out=cr;;
		"Glu") met_out=glu;; 
		"GPC+PCh") met_out=cho;; 
		"Ins") met_out=ins;; 
		"NAA") met_out=naa;; 
	esac

	echo ""
	echo $met_out
		# resample first to template, then to T1w image
		mincresample -trilinear -clobber \
		./Concentration_Estimate_Maps_clamped_b1c/${met_in}_con_map.mnc -like \
		./Export_Neuronav_CE/template.mnc \
		./Export_Neuronav_CE/${met_out}.mncc 
		
		mincresample -trilinear -clobber \
		./Export_Neuronav_CE/${met_out}.mncc -like \
		./Export_Neuronav_CE/magnitude.mnc \
		./Export_Neuronav_CE/${met_out}_resT1.mncc 
		
#		mincmath -clobber -clamp -const2 0 9999 \
#		./Export_Neuronav_CE/${met_out}_resT1.mncc \
#		./Export_Neuronav_CE/${met_out}_clamped.mncc

		mnc2nii -quiet -float \
		./Export_Neuronav_CE/${met_out}_resT1.mncc \
		./Export_Neuronav_CE/${met_out}_CE.nii
	 sleep 1
done
	
echo "" && echo "Packing..."
	gzip -f Export_Neuronav_CE/*.nii
echo "Removing..."
	rm -f Export_Neuronav_CE/*.mnc
	rm -f Export_Neuronav_CE/*.mncc


###insert remove of priors!

###add other mets
