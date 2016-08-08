# automated-ChIP-and-RNAseq-pipeline-deployment

Deployed on headnode by $ ./analysis_v4.sh

Asks the user for minimal information to define the parameters for the analysis, automates VM spin up, injects / installs need software for analysis, creates / attaches scratch, moves files from long term storage to scratch, performs analysis up to counts or peak calling, pushes data to an accessible web server, then cleans everything up. 

NOTE: injest files need to be merged before running pipeline.
