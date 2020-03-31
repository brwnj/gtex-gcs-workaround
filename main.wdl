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
    }
    meta {
        author: "Joe Brown"
        email: "brwnjm@gmail.com"
    }
}
