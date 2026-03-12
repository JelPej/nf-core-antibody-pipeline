FROM mambaorg/micromamba:1.5.8

USER root
RUN apt-get update && apt-get install -y procps && rm -rf /var/lib/apt/lists/*

RUN micromamba create -y -n biophi-env -c conda-forge -c bioconda \
    python=3.9 \
    abnumber \
    anarci \
    pip \
    git \
    && micromamba clean -a -y

SHELL ["bash", "-lc"]
ENV MAMBA_DEFAULT_ENV=biophi-env \
    PATH=/opt/conda/envs/biophi-env/bin:$PATH \
    OASIS_DB_PATH=/data/oasis/OASis_9mers_v1.db

RUN PATH=/opt/conda/envs/biophi-env/bin:$PATH \
    /opt/conda/envs/biophi-env/bin/pip install git+https://github.com/Merck/BioPhi.git

CMD ["/bin/bash"]