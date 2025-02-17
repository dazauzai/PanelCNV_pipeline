# PanelCNV_pipeline

## Overview
This pipeline is designed for **Target Panel Sequencing (TPS)** data analysis. It includes:
- **Preprocessing**: FastQC, TrimGalore, BWA, Samtools, Picard.
- **Base Quality Score Recalibration (BQSR)**: GATK.
- **Variant Calling**: GATK, bcftools.
- **Copy Number Variation (CNV) Analysis**: CNVkit, Control-FREEC.
- **Annotation**: ANNOTSV.
- **Visualization**: MultiQC, Event by Chr.

### 🔧 Features in Design
- Additional annotation enhancements.
- Improved visualization capabilities.
- Extended CNV/SV support.

## Features
- Fully automated pipeline for **Target Panel Sequencing**.
- Supports **GATK, Samtools, BWA, ANNOTSV, CNVkit, Control-FREEC, Decon, CNV-z, Panel-cn, CNVPanelizer**, and visualization tools.
- Compatible with **human genome (hg38/hg19)**.

## Installation
You can install this pipeline using one of the following methods:

### 1️⃣ Install via Docker
```bash
git clone https://github.com/dazauzai/PanelCNV_pipeline.git
cd PanelCNV_pipeline
docker build -t panel_cnv_pipeline .
```
To run the pipeline with Docker:
```bash
docker run --rm -v /path/to/data:/data -v /path/to/output:/output panel_cnv_pipeline \
    -b /data/bam_directory -o /output -r /data/reference_genome \
    -t /data/tumor_sample -d /data/dbsnp_vcf -P /data/pon_file
```

### 2️⃣ Install via Git Clone
```bash
gh repo clone dazauzai/PanelCNV_pipeline
cd PanelCNV_pipeline
```

### 3️⃣ Install via Direct Download
```bash
wget https://github.com/dazauzai/PanelCNV_pipeline/archive/main.zip
unzip main.zip
cd PanelCNV_pipeline
```

## Usage
Run the pipeline using the following command:
```bash
bash main.sh -b <bam_directory> -o <output_dir> -r <reference_genome> \
             -t <tumor_sample> -d <dbsnp_vcf> -P <panel_pon_file>
```

## Parameters
| Parameter | Description | Required |
|-----------|-------------|----------|
| `-b` | Input directory containing BAM files | ✅ Required |
| `-o` | Output directory for results | ✅ Required |
| `-r` | Reference genome file (e.g., hg38.fa) | ✅ Required |
| `-t` | Tumor sample BAM file | ✅ Required |
| `-d` | Known SNP database (e.g., dbSNP VCF), required for Control-FREEC if not using hg38 | Optional |
| `-P` | PON file for CNVkit, used as a reference file for CNV calling | Optional |

## Output Files
Output varies by tool but generally includes **BED files** for CNV results and additional variant information.

## Future Improvements
- Adding support for CNV and SV detection.
- Improved visualization with interactive reports.
- Expansion to non-human genomes.
Acknowledgments

We sincerely thank the developers of the following tools that make this pipeline possible:

CNVkit

Control-FREEC

DECoN

PanelCN

CNV-Z

CNVPanelizer

Samtools

BEDTools

AnnotateSV

GATK

BWA
## License
This pipeline is open-source under the MIT License.

## Contact
For questions, please contact dazauzai.

