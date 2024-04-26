#!/bin/bash
# Create Mincfiles out of raw files
for maptype in 'Orig/' 'Outlier_Clip/' 'QualityAndOutlier_Clip/' 'Ratio/' 'Extra/' 'SyntheticMaps/' 'Segmentation/' 'B1corr/' 'T1corr/' '' 'CorrectionMaps_B1c/' 'CorrectionMaps_T1c/'; do

	if [[ ! -d "${out_dir}/maps/${maptype}" ]]; then
		continue
	fi

	for file in "${out_dir}/maps/${maptype}"*.raw; do

		# Determine if file is resampled file
		res_flag=$(echo "$file" | grep -c "_res.raw\|_zf.raw")

		filename=${file##*/}

		if [[ $res_flag -ge 1 ]]; then
			file_name=${file%_res.raw}
			$rawtomincp -float -clobber -like "${out_dir}/maps/csi_template_zf.mnc" -input "$file" "${file_name}.mncc" #convert raw to minc
		else
			file_name=${file%.raw}
			$rawtomincp -float -clobber -like "${out_dir}/maps/csi_template.mnc" -input "${file_name}.raw" "${file_name}.mnc" #convert raw to minc
			# mincresample ${file_name}.mnc -like ${tmp_dir}/csi_template_zf.mnc ${file_name}.mncc  -tricubic -clobber			#resample to doubled resolution
		fi

		if [[ ! ($filename == *0_pha_map.raw || $filename == *mask.raw || $filename == *mask_*.raw || $filename == *FWHM_map.raw || $filename == *B1map.raw || $filename == Water*.raw) ]]; then
			rm "$file"
		fi

	done
done
