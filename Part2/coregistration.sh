########################### registration to MNI atlas #################################

MNI305_found=$(echo $non_lin_reg_type | grep -c -i "MNI305")
MNI152_found=$(echo $non_lin_reg_type | grep -c -i "MNI152")	
	
	
	############ PERFORM NON LINEAR REGISTRATION ############
	if [[ $MNI305_found > 0 ]]; then
	    echo -e "\n\n9. PERFORM NON LINEAR REGISTRATION TO 305 MNI ATLAS\n\n"
	    atlas_type=MNI_average_brain_305/average305_t1_tal_lin.mnc
	elif [[ $MNI152_found > 0 ]]; then
	    echo -e "\n\n9. PERFORM NON LINEAR REGISTRATION TO 152 NONLINEAR ATLAS\n\n"
	    atlas_type=mni_icbm152_nlin_sym_09a/mni_icbm152_t1_tal_nlin_sym_09a.mnc
	else 
	    echo -e "\n\n9. PLEASE SET THE FLAG -r TO A VALUE OF EITHER 1 OR 2 AND REPEAT THE ROUTINE\n\n"
	fi
	
		# compute linear transformation matrix
		bestlinreg_s2 -clobber ${out_dir}/maps/magnitude.mnc /net/mri.meduniwien.ac.at/departments/radiology/mrsbrain/lab/$atlas_type ${out_dir}/maps/linear_transform.xfm     
		# apply it on magnitude.mnc
		mincresample -clobber -like /net/mri.meduniwien.ac.at/departments/radiology/mrsbrain/lab/$atlas_type ${out_dir}/maps/magnitude.mnc -transformation  ${out_dir}/maps/linear_transform.xfm  ${out_dir}/maps/magnitude_linear.mnc 
		# compute non linear transformation matrix
		nlfit_s -clobber ${out_dir}/maps/magnitude_linear.mnc /net/mri.meduniwien.ac.at/departments/radiology/mrsbrain/lab/$atlas_type  ${out_dir}/maps/non_linear_transform.xfm 
		# apply it on magnitude.mnc
		mincresample -clobber -like /net/mri.meduniwien.ac.at/departments/radiology/mrsbrain/lab/$atlas_type ${out_dir}/maps/magnitude_linear.mnc -transformation  ${out_dir}/maps/non_linear_transform.xfm  ${out_dir}/maps/magnitude_nonlinear.mnc
		# concat lin & nonlin transformation matrix
		xfmconcat  ${out_dir}/maps/linear_transform.xfm  ${out_dir}/maps/non_linear_transform.xfm  ${out_dir}/maps/lin+nonlin_transform.xfm 

	# Apply transformation matrix on all .mnc files
	for mincfile in "`find ${out_dir}/maps -iname "*.mnc*" ! -iname "magnitude*.mnc" -print`";
	do
	    for z in $mincfile; do 
	    echo "$z"; # DEBUG MODE
	    mincresample -clobber -tfm_input_sampling -transformation ${out_dir}/maps/lin+nonlin_transform.xfm $z  $(dirname $z)/registered_$(basename $z);
	    done
	done


