cwlVersion: v1.0
class: Workflow
id: alignment_pipeline
requirements:
  - class: ScatterFeatureRequirement

inputs:
  input_bam: File[]
  indexed_reference_fasta:
    type: File
    secondaryFiles: [.64.amb, .64.ann, .64.bwt, .64.pac, .64.sa, .64.alt,
    ^.dict, .fai]
  output_basename: string
  read_name_regex: string?
  sequence_grouping_tsv: File[]
  sequence_grouping_with_unmapped_tsv: File[]
  known_indels_sites_VCFs: File[]
  dbSNP_vcf: File
  output_Bam: string

outputs:
  duplicates_marked_bam:
    type: File
    outputSource: MarkDuplicates/output_markduplicates_bam
  duplicates_marked_metrics:
    type: File
    outputSource: MarkDuplicates/output_markduplicates_metrics
  sorted_bam:
    type: File
    secondaryFiles: [^.bai, ^.bam.md5]
    outputSource: SortSam/output_sorted_bam
  bqsr_report:
    type: File
    outputSource: GatherBqsrReports/output
  gatherbam:
    type: File
    outputSource: GatherBamFiles/output
  cramfile:
    type: File
    outputSource: ConvertToCram/output

steps:
  GetBwaVersion:
    run: ../tasks/GetGwaVersion.yaml
    out: [output]

  SamToFastqAndBwaMemAndMba:
    run: ../tasks/SamToFastqAndBwaMemAndMba.yaml
    in:
      input_file: input_bam
      indexed_reference_fasta:
        type: File
        secondaryFiles: [.64.amb, .64.ann, .64.bwt, .64.pac, .64.sa, .64.alt,
    ^.dict]
      bwa_version: GetBwaVersion/output
    scatter: [input_file]
    out: [output]

  MarkDuplicates:
    run: ../tasks/MarkDuplicates.yaml
    in:
      input_bams: SamToFastqAndBwaMemAndMba/output
      output_bam: output_basename + ".bam"
      metrics_filename: output_basename + ".txt"
      read_name_regex: read_name_regex
    out: [output_markduplicates_bam, output_markduplicates_metrics]

  SortSam:
    run: ../tasks/SortSam.yaml
    in:
      input_bam: MarkDuplicates/output_markduplicates_bam
    out: [output_sorted_bam]

  Expression_createsequencegrouping:
    run: ../tasks/expression_createsequencegrouping.yaml
    in:
      sequence_grouping_tsv: sequence_grouping_tsv
      sequence_grouping_with_unmapped_tsv: sequence_grouping_with_unmapped_tsv
    out: [sequence_grouping_array,sequence_grouping_with_unmapped_array]

  BaseRecalibrator:
    run: ../tasks/BaseRecalibrator.yaml
    in:
      input_bam: SortSam/output_sorted_bam
      recalibration_report_filename: recalibration_report_filename
      known_indels_sites_VCFs: known_indels_sites_VCFs
      dbSNP_vcf: dbSNP_vcf
      reference: indexed_reference_fasta
      sequence_interval: Expression_createsequencegrouping/sequence_grouping_array
    scatter: [sequence_interval]
    out: [output]

  GatherBqsrReports:
    run: ../tasks/GatherBqsrReports.yaml
    in:
      input_bqsr_reports: BaseRecalibrator/output
    out: [output]

  ApplyBQSR:
    run: ../tasks/ApplyBQSR.yaml
    in:
      reference: indexed_reference_fasta
      input_bam: SortSam/output_sorted_bam
      bqsr_report: GatherBqsrReports/output
      sequence_interval: Expression_createsequencegrouping/sequence_grouping_array
    scatter: [sequence_interval]
    out: [recalibrated_bam]

  GatherBamFiles:
      run: ../tasks/GatherBamFiles.yaml
      in:
        input_bam: ApplyBQSR/recalibrated_bam
        output_Bam: output_Bam
        compression_level: compression_level
      out: [output]

  ConvertToCram:
      run: ../tasks/ConvertToCram.yaml
      in:
        reference: indexed_reference_fasta
        input_bam: GatherBamFiles/output
      out: [output]
