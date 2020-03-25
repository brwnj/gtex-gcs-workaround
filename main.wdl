task printreads {
    String sample_id
    String project
    File alignments
    File alignments_index
    File fasta
    File fasta_index
    File fasta_dict
    File intervals

    Int disk_size = 100
    Int memory = 8
    String image = "broadinstitute/gatk:4.1.4.0"

    command {
        gatk PrintReads --gcs-project-for-requester-pays ${project} --reference ${fasta} --input ${alignments} --intervals ${intervals} --output `pwd`/${sample_id}.bam
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
    }
    meta {
        author: "Joe Brown"
        email: "brwnjm@gmail.com"
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
    String project
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
    }
    call tar_czf {
        input:
            files = printreads.bam,
            filename = "extracted_reads",
            disk_size = disk_size,
            memory = memory
    }
    meta {
        author: "Joe Brown"
        email: "brwnjm@gmail.com"
    }
}
