task printreads {
    String sample_id
    File alignments
    File alignments_index
    File fasta
    File fasta_index
    File fasta_dict
    File intervals
    String? project

    Int disk_size = 100
    Int memory = 8
    String image = "broadinstitute/gatk:4.1.4.0"

    command {
        gatk PrintReads ${"--gcs-project-for-requester-pays " + project} --reference ${fasta} --input ${alignments} --intervals ${intervals} --output `pwd`/${sample_id}.bam --create-output-bam-index true
        mv `pwd`/${sample_id}.bai `pwd`/${sample_id}.bam.bai
    }
    runtime {
        memory: memory + "GB"
        cpu: 1
        disks: "local-disk " + disk_size + " HDD"
        preemptible: 2
        docker: image
    }
    output {
        File bam = "${sample_id}.bam"
        File bai = "${sample_id}.bam.bai"
        String sample = "${sample_id}"
    }
    meta {
        author: "Joe Brown"
        email: "brwnjm@gmail.com"
    }
}


task somalier_extract {
    # requires $sample to match name defined in @RG -- https://github.com/brentp/somalier/blob/master/src/somalier.nim#L25
    String sample_id
    File alignments
    File alignments_index
    File fasta
    File fasta_index

    # known sites
    File sites_vcf

    Int disk_size = 100
    Int memory = 8
    String image = "brentp/somalier:v0.2.9"

    command {
        somalier extract --out-dir `pwd`/ --fasta ${fasta} --sites ${sites_vcf} ${alignments}
    }
    runtime {
        memory: memory + "GB"
        cpu: 1
        disks: "local-disk " + disk_size + " HDD"
        preemptible: 2
        docker: image
    }
    output {
        File counts = "${sample_id}.somalier"
    }
    meta {
        author: "Joe Brown"
        email: "brwnjm@gmail.com"
        description: "Run @brentp's somalier extract across alignments (bam/cram)"
    }
}


task tar_czf {
    Array[File] files
    String filename = "archive"

    Int disk_size = 100
    Int memory = 8
    String image = "brentp/somalier:v0.2.9"

    command {
        tar -czvf `pwd`/${filename}.tar.gz --files-from=${write_lines(files)}
    }
    runtime {
        memory: memory + "GB"
        cpu: 1
        disks: "local-disk " + disk_size + " HDD"
        preemptible: 2
        docker: image
    }
    output {
        File archive = "${filename}.tar.gz"
    }
    meta {
        author: "Joe Brown"
        email: "brwnjm@gmail.com"
        description: "Compress and array of files into a single tar.gz archive"
    }
}


workflow gtex_gcs_workaround {
    String? project
    File manifest
    Array[Array[String]] sample_data = read_tsv(manifest)
    File fasta
    File fasta_index
    File fasta_dict
    File intervals

    Int disk_size = 100
    Int memory = 8

    scatter (sample in sample_data) {
        call printreads {
            input:
                sample_id = sample[0],
                project = project,
                alignments = sample[1],
                alignments_index = sample[2],
                fasta = fasta,
                fasta_index = fasta_index,
                fasta_dict = fasta_dict,
                intervals = intervals,
                disk_size = disk_size,
                memory = memory
        }
        call somalier_extract {
            input:
                sample_id = printreads.sample,
                alignments = printreads.bam,
                alignments_index = printreads.bai,
                fasta = fasta,
                fasta_index = fasta_index,
                sites_vcf = intervals
        }
    }
    call tar_czf {
        input:
            files = somalier_extract.counts,
            filename = "counts",
            disk_size = disk_size,
            memory = memory
    }
    meta {
        author: "Joe Brown"
        email: "brwnjm@gmail.com"
    }
}
