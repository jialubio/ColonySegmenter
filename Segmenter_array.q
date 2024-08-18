#!/bin/bash
#SBATCH --output=matlab.out
#SBATCH --array=19
#SBATCH --mem=32G
/opt/apps/matlabR2016a/bin/matlab -nojvm -nodisplay -singleCompThread -r "rank=$SLURM_ARRAY_TASK_ID;Segmenter_Cluster;quit"
