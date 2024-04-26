##to do:
### set up for brainlab dicom export too

cd ${out_dir}/maps/

mkdir Export_Neuronav_CE

	echo -e "\nConverting to nii for the Neuronavigation system. 3D version!  \n"

	cp magnitude.mnc Export_Neuronav_CE/
    	# create upsampled MRSI template
	zstep_orig="$(mincinfo -attvalue zspace:step ./Met_Maps_Cr_O_masked/NAA_amp_map.mnc)"
	zstep_temp="$(echo "scale=4; 0.47" | bc)"
	zstart="$(mincinfo -attvalue zspace:start ./Met_Maps_Cr_O_masked/NAA_amp_map.mnc)"
	zstart_new="$(echo "scale=4; $zstart-$zstep_orig/2+$zstep_temp/2" | bc)"


	echo $zstep_orig $zstep_temp $zstart $zstart_new
	sleep 3

	###naa + template
	##3D
	mincresample Met_Maps_Cr_O_masked/NAA_amp_map.mnc -step -2.2 -2.2 2.2 -nelements 100 100 70 -zstart $zstart_new Export_Neuronav_CE/template.mnc -clobber
	##2D
	#mincresample Met_Maps_Cr_O_masked/NAA_amp_map.mnc -step -0.55 -0.55 0.588 -nelements 400 400 17 -zstart $zstart_new Export_Neuronav_CE/template.mnc -clobber

#	mincresample Met_Maps_Cr_O_masked/NAA_amp_map.mnc -like Export_Neuronav_CE/template.mnc Export_Neuronav_CE/naa.mncc -trilinear -clobber
#	mincresample Export_Neuronav_CE/naa.mncc -like Export_Neuronav_CE/magnitude.mnc Export_Neuronav_CE/naa_resT1.mncc -trilinear -clobber
#	mincmath -clobber -clamp -const2 0 9999 Export_Neuronav_CE/naa_resT1.mncc Export_Neuronav_CE/naa_clamped.mncc
#	mnc2nii -quiet -float ./Export_Neuronav_CE/naa_clamped.mncc ./Export_Neuronav_CE/naa.nii
	
	###T1w
	mnc2nii -quiet -float magnitude.mnc ./Export_Neuronav_CE/T1w_7T_reference.nii
#	mnc2nii -quiet -float flair.mnc ./Export_Neuronav_CE/flair.nii

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
