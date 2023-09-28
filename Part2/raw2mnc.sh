# Create Mincfiles out of raw files

for maptype in 'Orig/' 'Outlier_Clip/' 'QualityAndOutlier_Clip/' 'Ratio/' 'Extra/' 'SyntheticMaps/' 'Segmentation/' ''; do

	if [[ ! -d ${out_dir}/maps/${maptype} ]]; then
		continue
	fi

	for file in ${out_dir}/maps/${maptype}*.raw; do


		# Determine if file is resampled file
		res_flag=`echo $file | grep -c "_res.raw\|_zf.raw"`

		filename=${file##*/}

		if [[ $res_flag -ge 1 ]]; then
			if [[ $UpsampledMaps_flag -eq 1 ]]; then		# Probably dont even create the .raw file if it is never used...
				file_name=${file%_res.raw}
				file_name=${file_name%_zf.raw}
				echo "Convert $filename to MINC."
				rawtominc -float -clobber -like ${out_dir}/maps/csi_template_zf.mnc -input ${file} ${file_name}.mncc				#convert raw to minc
			else
				echo "Delete $filename."
			fi
		else
			file_name=${file%.raw}
			echo "Convert $filename to MINC."
			rawtominc -float -clobber -like ${out_dir}/maps/csi_template.mnc -input ${file_name}.raw ${file_name}.mnc				#convert raw to minc
			# mincresample ${file_name}.mnc -like ${tmp_dir}/csi_template_zf.mnc ${file_name}.mncc  -tricubic -clobber			#resample to doubled resolution
		fi

		
		if [[ ! ($filename == *0_pha_map.raw || $filename == *mask.raw || $filename == *mask_*.raw || $filename == *FWHM_map.raw ) ]]; then  
			rm ${file}
		fi


	done
done



