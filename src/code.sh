#!/bin/bash
# exomedepth_cnv_analysis_v1.0.0

# The following line causes bash to exit at any point if there is any error
# and to output each line as it is executed -- useful for debugging
set -e -x -o pipefail

### Set up parameters
# split project name to get the NGS run number(s)
run=$(echo $project_name |  sed -n 's/^.*_\(NGS.*\)\.*/\1/p') 

# Get names of input files as strings
subpanel_bed_name=$(dx describe --name "$subpanel_bed")
readcount_file_name=$(dx describe --name "$readcount_file")

# TODO check if this is required, correctly created
subpanel_bed_prefix=$(echo "$subpanel_bed_name" | sed -r  's/^[^0-9]*(Pan[0-9]+).*/\1/')

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
echo "Run = " "$run"
echo "sub_panel_BED = " "$subpanel_bed_name"
echo "All Pan numbers to be assessed using this BED file = " "$bamfile_pannumbers"
# echo "QC_file = " $QC_file_name

mark-section "Check that there are bam files matching provided Pan numbers"

# Create an array of all the Pan numbers from the bam files in the provided project
readarray -t pans_from_bams < <(dx find data --name "*.bam" --project "$project_name" --folder /output --auth "$API_KEY" |  sed -n 's/^.*_\(Pan[0-9]*\)\_.*/\1/p' | sort | uniq)

mark-section "download bams files and indexes"
# $bamfile_pannumbers is a comma seperated list of pannumbers that should be analysed together.
# split this into an array and loop through to download BAM and BAI files
IFS=',' read -ra pannum_array <<<  $bamfile_pannumbers
for panel in "${pannum_array[@]}"; do
	
if [[ " ${pans_from_bams[*]} " =~ " ${panel} " ]]; then
    # If requested pan number has matching bam files
	dx download "$project_name":output/*"$panel"*001.ba* --auth "$API_KEY"
else
    echo "WARNING: No bam/bai files found for ${panel}"
fi
done

#Get list of all BAMs 
bam_list=(/home/dnanexus/to_test/*bam)
echo "bam list = " "${bam_list[@]}"

#count the files. Make sure there are at least 3 samples for this pan number as this is a requirement of the dockerised R script, else stop
bamfilecount=$(find . -maxdepth 1 -name "*001.bam"  | wc -l)
baifilecount=$(find . -maxdepth 1 -name "*001.bai"  | wc -l)

if (( bamfilecount < 3 )); then
	echo "LESS THAN THREE BAM FILES FOUND FOR THIS ANALYSIS" 1>&2
	exit 1
fi

# Ensure that every bam file has a bai file
if (( baifilecount < bamfilecount )); then
	echo "ONE OR MORE BAM FILE IS MISSING AN BAI INDEX FILE" 1>&2
	exit 1
fi

# cd out of to_test
cd ..

mark-section "setting up Exomedepth docker image"
# download the docker file from 001_Tools...
dx download $docker_file --auth "${API_KEY}"
docker load -i '/home/dnanexus/seglh_exomedepth_1220d31.tgz'

mark-section "Run CNV analysis using docker image"


# docker run - mount the home directory as a share
# Write log direct into output folder
# Get read count for all samples

for bam in /home/dnanexus/to_test/*bam
do
samplename=$(basename "$bam" _R1_001.bam) 
echo "samplename:" "$samplename"
echo "bam:" "$bam"
echo "subpanel:" "$subpanel_bed_name" 
#for each bam run exomedepth - the string in the format v1.0.0 will be concatenated to the ouput as the app version

# Handle optional argument relating to QC file
if [ -z "$QC_file" ]; then
	echo "Optional QC file not provided by user"
	bam_and_QC_command="$bam":"$samplename"
	else
	QC_file_path="/home/dnanexus/in/QC_file/*.RData"
	bam_and_QC_command="$bam:$samplename $QC_file_path"
fi

docker run -v /home/dnanexus:/home/dnanexus/ \
	--rm  seglh/exomedepth:1220d31 \
	exomeDepth.R \
	'v1.0.0' \
	/home/dnanexus/out/exomedepth_output/exomedepth_output/"$samplename"_output.pdf \
	/home/dnanexus/in/subpanel_bed/"$subpanel_bed_name":"$subpanel_bed_prefix" \
	/home/dnanexus/in/readcount_file/"$readcount_file_name" \
	"$bam_and_QC_command"
done

# 	for debugging run in interactive mode:
# docker run -v /home/dnanexus:/home/dnanexus/ --rm -it --entrypoint /bin/bash seglh/exomedepth:1220d31

# Upload results
dx-upload-all-outputs
