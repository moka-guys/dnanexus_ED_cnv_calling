# dnanexus_ED_cnv_analysis_v1.0.0
Performs CNV calling using ExomeDepth.

Exome depth is run in two stages. Firstly, read counts are calculated, before CNVs are called using the read counts. Read counts are calculated over the entire genome whereas the CNV calling can be performed using a subpanel.

# What does the app do?
This app runs the CNV calling stage.

# How the app works?

The app takes in a readcount file generated by https://github.com/moka-guys/dnanexus\_ED\_readcount_analysis, the docker image will pick the most appropriate reference samples and run exomedepth for a given sample. 


For further details on the usage of the docker image please refer to https://github.com/moka-guys/seglh-cnv/tree/main/exomedepth

# Input
- DNAnexus project name where the BAM and the indexes are stored (BAMs/BAIs MUST be present in the /output folder)
- Readcount file generated using https://github.com/moka-guys/dnanexus\_ED\_readcount_analysis
- QC file containing QC parameters (Optional) - generated using https://github.com/moka-guys/dnanexus\_ED\_readcount_analysis
- List of comma seperated pan numbers (Pan4127,Pan4129,Pan4130,Pan4049)
- Test specific BED file
See CLI command below for an example of inputs.

# Output
- output.pdf - Exomedepth CNV report with all QC information
- output.tex - Intermediate file used to create PDF
- tables-1.pdf, tables-2.pdf etc - Plots for inclusion in the generated reports
- output.bed - CNVs in BED format (whole panel)
- output.RData 

# Running from the CLI:

The app can be run from the dx CLI.  The example below shows the code used to run test samples through this app:

```bash
dx run project-G0pKxX80pgqFk9Vy8p6vQbKv:applet-G7B5Zxj0pgq9Q8JfP0jpY3y4 -iproject_name=003_220103_exomeDepth_calling_test -ireadcount_file=project-G6jb1k807Xjj1J984K6kfP13:file-G6kg5q80gvvz37qZ4ZPbvZ8Q -ibamfile_pannumbers=Pan4127,Pan4129,Pan4130,Pan4049 -isubpanel_bed=project-ByfFPz00jy1fk6PjpZ95F27J:file-G6kZpqQ0jy1q1Zk94G3qbVyV -iQC_file=project-G6jb1k807Xjj1J984K6kfP13:file-G66X1Z80p6PG52GFK4zfpY7y

```
# Debugging

For debugging issues with the `docker` image it can be helpful to `ssh` into a 'held for debugging' job in DNA nexus and run the `docker` image in interactive mode:

```bash
docker run -v /home/dnanexus:/home/dnanexus/ --rm -it --entrypoint /bin/bash seglh/exomedepth:1220d31
```