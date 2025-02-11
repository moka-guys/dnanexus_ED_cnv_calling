#!/bin/bash
# exomedepth_cnv_analysis_v1.4.0

# The following line causes bash to exit at any point if there is any error
# and to output each line as it is executed -- useful for debugging
set -e -x -o pipefail

### Set up parameters
# split project name to get the NGS run number(s)
run=$(echo $project_name |  sed -n 's/^.*_\(NGS.*\)\.*/\1/p') 

# Get names of input files as strings
subpanel_bed_name=$(dx describe --name "$subpanel_bed")
readcount_file_name=$(dx describe --name "$readcount_file")

subpanel_bed_prefix=$(echo "$subpanel_bed_name" | sed -r  's/^[^0-9]*(Pan[0-9]+).*/\1/')

# Location of the ExomeDepth docker file
docker_file_id=project-ByfFPz00jy1fk6PjpZ95F27J:file-Gbjy9yj0JQXkKB8bfFz856V6

#read the DNA Nexus api key as a variable
API_KEY_wquotes=$(echo $DX_SECURITY_CONTEXT |  jq '.auth_token')
API_KEY=$(echo "$API_KEY_wquotes" | sed 's/"//g')
echo "$API_KEY"

#make output dir
mkdir -p /home/dnanexus/out/exomedepth_output/exomedepth_output/
# make folder to hold downloaded files
mkdir to_test

# Download inputs
dx-download-all-inputs --parallel

mark-section "Determining reference genome"
if  [[ $reference_genome_name == *.tar* ]]
	then
		echo "reference is tarball"
		exit 1
elif [[ $reference_genome_name == *.gz ]]
	then 
		gunzip $reference_genome_path
		reference_fasta=$(echo $reference_genome_path | sed 's/\.gz//g')
elif [[ $reference_genome_name == *.fa ]]
	then
		reference_fasta=$reference_genome_path
fi 

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
	dx download "$project_name":output/*"$panel"*$bam_str.ba* --auth "$API_KEY"
else
    echo "WARNING: No bam/bai files found for ${panel}"
fi
done

#Get list of all BAMs 
bam_list=(/home/dnanexus/to_test/*bam)
echo "bam list = " "${bam_list[@]}"

# Ensure that every bam file has a bai file
baifilecount=$(find . -maxdepth 1 -name "*$bam_str*.bai"  | wc -l)
if (( baifilecount < bamfilecount )); then
	echo "ONE OR MORE BAM FILE IS MISSING A BAI INDEX FILE" 1>&2
	exit 1
fi

# cd out of to_test
cd ..

mark-section "setting up Exomedepth docker image"
# download the docker file from 001_Tools...
dx download $docker_file_id --auth "${API_KEY}"
docker_file=$(dx describe ${docker_file_id} --name)
DOCKERIMAGENAME=`tar xfO ${docker_file} manifest.json | sed -E 's/.*"RepoTags":\["?([^"]*)"?.*/\1/'`
docker load < /home/dnanexus/"${docker_file}"

mark-section "Run CNV analysis using docker image"


# docker run - mount the home directory as a share
# Write log direct into output folder
# Get read count for all samples

for bam in /home/dnanexus/to_test/*bam
do
samplename=$(basename "$bam" $samplename_str) 
echo "samplename:" "$samplename"
echo "bam:" "$bam"
echo "subpanel:" "$subpanel_bed_name"
echo "trans_prob:" "$trans_prob"

# Check which QC file to you
#Extract panel type from samplename
#split samplename on '_'
panelname="$(echo $samplename | cut -d'_' -f6)"
echo $panelname
if [[ "$panelname" == *VCP1* ]]; then 
	QC_file="vcp1_qc.RData";
elif [[ "$panelname" == *VCP2* ]]; then
	QC_file="vcp2_qc.RData";
elif [[ "$panelname" == *VCP3* || "$panelname" == *CP2* ]]; then
    # cp2 and vcp3 panels use the same qc.RData (i.e. vcp3_qc.RDATA)
	QC_file="vcp3_qc.RData";
fi

#test
echo "RDATA = " "$readcount_file_name"
#for each bam run exomedepth - the string in the format v1.0.0 will be concatenated to the ouput as the app version
docker run -v /home/dnanexus:/home/dnanexus/ \
	--rm  ${DOCKERIMAGENAME} \
	exomeDepth.R \
	'v1.4.0' \
	/home/dnanexus/out/exomedepth_output/exomedepth_output/"$samplename"_output.pdf \
	/home/dnanexus/in/subpanel_bed/"$subpanel_bed_name":"$subpanel_bed_prefix" \
	/home/dnanexus/in/readcount_file/"$readcount_file_name" "$bam":"$samplename":0.01 $QC_file

done

# Upload results
dx-upload-all-outputs
