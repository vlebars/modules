process PICARD_ADDORREPLACEREADGROUPS {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/picard:3.1.1--hdfd78af_0' :
        'biocontainers/picard:3.1.1--hdfd78af_0' }"

    input:
    tuple val(meta), path(bam)
    tuple val(meta2), path(fasta)
    tuple val(meta3), path(fasta_index)

    output:
    tuple val(meta), path("*.bam") , emit: bam,  optional: true
    tuple val(meta), path("*.bai") , emit: bai,  optional: true
    tuple val(meta), path("*.cram"), emit: cram, optional: true
    path "versions.yml"            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args        ?: ''
    def prefix = task.ext.prefix    ?: "${meta.id}"
    def suffix = task.ext.suffix    ?: "${bam.getExtension()}"
    def reference = fasta ? "--REFERENCE_SEQUENCE ${fasta}" : ""
    def create_index = ( suffix == "bam" )? "--CREATE_INDEX" : ""
    def avail_mem = 3072
    if (!task.memory) {
        log.info '[Picard AddOrReplaceReadGroups] Available memory not known - defaulting to 3GB. Specify process memory requirements to change this.'
    } else {
        avail_mem = (task.memory.mega*0.8).intValue()
    }

    if ("$bam" == "${prefix}.${suffix}") error "Input and output names are the same, use \"task.ext.prefix\" to disambiguate!"

    """
    picard \\
        -Xmx${avail_mem}M \\
        AddOrReplaceReadGroups \\
        $args \\
        $reference \\
        $create_index \\
        --INPUT ${bam} \\
        --OUTPUT ${prefix}.${suffix}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        picard: \$(picard AddOrReplaceReadGroups --version 2>&1 | grep -o 'Version:.*' | cut -f2- -d:)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix    ?: "${meta.id}"
    def suffix = task.ext.suffix    ?: "${bam.getExtension()}"
    if ("$bam" == "${prefix}.${suffix}") error "Input and output names are the same, use \"task.ext.prefix\" to disambiguate!"
    def create_index = ""
    if (suffix == "bam") {
        create_index = "touch ${prefix}.${suffix}.bai"
    }
    """
    touch ${prefix}.${suffix}
    ${create_index}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        picard: \$(picard AddOrReplaceReadGroups --version 2>&1 | grep -o 'Version:.*' | cut -f2- -d:)
    END_VERSIONS
    """
}
