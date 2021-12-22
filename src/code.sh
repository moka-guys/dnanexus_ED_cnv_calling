#!/bin/bash
# exomedepth_cnv_analysis_v1.0.0

# The following line causes bash to exit at any point if there is any error
# and to output each line as it is executed -- useful for debugging
set -e -x -o pipefail

### Set up parameters
#TODO Check if still needed
# split project name to get the NGS run number(s)
run=$(echo $project_name |  sed -n 's/^.*_\(NGS.*\)\.*/\1/p') # Variable not currently used

# Add this if still required
subpanel_bed_prefix=TODO 

# Location of the ExomeDepth docker file
docker_file=project-ByfFPz00jy1fk6PjpZ95F27J:file-G6kfZYQ0jy1vZ0BF33KZpQjJ

#read the DNA Nexus api key as a variable
API_KEY=$(dx cat project-FQqXfYQ0Z0gqx7XG9Z2b4K43:mokaguys_nexus_auth_key)

#make output dir
mkdir -p /home/dnanexus/out/exomedepth_output/exomedepth_output/
# make folder to hold downloaded files
mkdir to_test

# Download inputs
dx-download-all-inputs --parallel

# cd to test dir
cd to_test

mark-section "determine run specific variables"
echo "sub_panel_BED = " $subpanel_bed
echo "reference_genome = " $reference_genome
echo "All Pan numbers to be assessed using this BED file = " $bamfile_pannumbers
echo "QC_file = " $QC_file

# $bamfile_pannumbers is a comma seperated list of pannumbers that should be analysed together.
# split this into an array and loop through to download BAM and BAI files
IFS=',' read -ra pannum_array <<<  $bamfile_pannumbers
for panel in ${pannum_array[@]};
do
	# check there is at least one bam file with that pan number to download otherwise the dx download command will fail
	num_detected_bams=$(dx ls $project_name:output/*001.ba* --auth $API_KEY | grep -c $panel )
	if [ num_detected_bams > 0 ] ;
	then
		# download all the BAM and BAI files for this project/pan number
		dx download $project_name:output/*$panel*001.ba* --auth $API_KEY
				else
			echo $panel " related bams not found in " $project_name
	fi
done

#Get list of all BAMs 
bam_list=(/home/dnanexus/to_test/*bam)
echo "bam list = " ${bam_list[@]}

#TODO Check if still needed
#count the files. make sure there are at least 3 samples for this pan number, else stop
filecount="$(ls *001.ba* | grep . -c)"
if (( $filecount < 6 )); then
	echo "LESS THAN THREE BAM FILES FOUND FOR THIS ANALYSIS" 1>&2
	exit 1
fi

# cd out of to_test
cd ..

mark-section "setting up Exomedepth docker image"
# download the docker file from 001_Tools...
dx download $docker_file --auth "${API_KEY}"

mark-section "Run CNV analysis using docker image"
# docker run - mount the home directory as a share
# Write log direct into output folder
#Get read count for all samples
docker load -i '/home/dnanexus/seglh_exomedepth_1220d31.tgz'

for bam in /home/dnanexus/dnanexus_ED_cnv_calling/to_test/*bam
#TODO Clean up generation of sample name
do
samplename=$(python -c "basename='$bam'; print basename.split('/')[4].split('_R1')[0]")
echo "samplename:"$samplename
echo "bam:"$bam
#for each bam run exomedepth
# TODO rewrite command and add comment
docker run -v /home/dnanexus:/home/dnanexus --rm  seglh/exomedepth:1220d31 exomeDepth.R 'v1.0.0' /home/dnanexus/out/exomedepth_output/exomedepth_output/"$samplename"_output.pdf $subpanel_bed_path:$subpanel_bed_prefix $readcount_file_path $bam:$samplename $QC_file_path
done

# Upload results
dx-upload-all-outputs


