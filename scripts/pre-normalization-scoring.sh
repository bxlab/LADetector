#!/bin/sh

######################################
#TO DO before you run this script
SCRIPTS=PATH_TO_DamID-LADetector_folder
#Enter the path of your scripts folder/1_fastq_quality_trimmer.pl.
BUILD=PATH_TO_reference_index_folder
#Enter the path of your reference index folder.
#mm9 and hg38 are provided
BINS=PATH_TO_genomic_bins
#Enter the path to your genomic_bins.bed file. 
#####################################

DIRS=$(dirname "${SCRIPTS}")


#getting prefix for input filenames 
input=$1
prefix="${input%.*}"

if [ $2 ]      #this will be true (on slurm) if the user enters 1 after the input file path.  
then 
	module load bowtie
	module load samtools
	module load bedtools
fi

#1.  quality trim
perl $DIRS/1_fastq_quality_trimmer.pl $1 $prefix.qualitytrimmed         

#2. remove internal dsAdr
perl $DIRS/2_remove_internal_adaptors.pl $prefix.qualitytrimmed $prefix.bowtie1Input

#3. 1st bowtie run
bowtie --maxbts 125 -n 2 --max --strata -e 70 -l 28 $BUILD -q $prefix.bowtie1Input --un $prefix.bowtie1_unmapped  -S $prefix.bowtie1_mapped.sam

#4.  Trim 5' ends
perl $DIRS/4_trim_5_prime_end.pl $prefix.bowtie1_unmapped $prefix.bowtie2Input

#5.  2nd bowtie run
bowtie --maxbts 125 -n 2 --max --strata -e 70 -l 28 $BUILD -q $prefix.bowtie2Input --un $prefix.bowtie2_unmapped  -S $prefix.bowtie2_mapped.sam

#6. find the identifiers of the unmapped reads
perl $DIRS/6_rebuild_5prime_A.pl $prefix.bowtie2_unmapped $prefix.bowtie2_unmappedID

#7. find the untrimmed (5' untrimmed) reads corresponding to the IDs in step 6.
perl $DIRS/7_rebuild_5prime_B.pl $prefix.bowtie2_unmappedID $prefix.bowtie1_unmapped $prefix.bowtie3Input_pre-trimmed

#8. trim 3' ends of reads from step 7.
perl $DIRS/8_trim_3_prime.pl $prefix.bowtie3Input_pre-trimmed $prefix.bowtie3Input

#9.  3rd bowtie run
bowtie --maxbts 125 -n 2 --max --strata -e 70 -l 28 $BUILD -q $prefix.bowtie3Input --un $prefix.bowtie3_unmapped  -S $prefix.bowtie3_mapped.sam

#10. Convert all sam files (3 of them) to bams
samtools view -bS $prefix.bowtie1_mapped.sam > $prefix.bowtie1_mapped.bam
samtools view -bS $prefix.bowtie2_mapped.sam > $prefix.bowtie2_mapped.bam
samtools view -bS $prefix.bowtie3_mapped.sam > $prefix.bowtie3_mapped.bam

#11. Concatenate the bam files
samtools merge -f $prefix.bowtie_mapped_all.bam $prefix.bowtie1_mapped.bam $prefix.bowtie2_mapped.bam $prefix.bowtie3_mapped.bam

#12. convert the bam file to bed
bedtools bamtobed -i $prefix.bowtie_mapped_all.bam > $prefix.bowtie_mapped_all.bed

#13. Perform bedtools intersect on Dpn bins.
bedtools intersect -wb -a $prefix.bowtie_mapped_all.bed -b $BINS>$prefix.intersect.output

#14. Count number of reads that overlap each bin.
perl $DIRS/14_counting_readNum_per_Bin.pl $BINS $prefix.intersect.output $prefix.preNormalization.score

#15. Count number of mapped reads
wc -l $prefix.bowtie_mapped_all.bed > $prefix.mappedReadCounts



