FROM mambaorg/micromamba:1.5.8

USER root
RUN apt-get update && apt-get install -y --no-install-recommends procps && rm -rf /var/lib/apt/lists/*
USER $MAMBA_USER

# Create environment with BioPhi (+ OASis) installed
RUN micromamba create -y -n biophi-env -c conda-forge -c bioconda biophi python=3.9 && \
    micromamba clean -a -y

# Use bash as shell
SHELL ["bash", "-lc"]

# Default env + PATH when container starts
ENV MAMBA_DEFAULT_ENV=biophi-env \
    PATH=/opt/conda/envs/biophi-env/bin:$PATH \
    OASIS_DB_PATH=/data/oasis/OASis_9mers_v1.db

# No build-time health check – we'll test at runtime
CMD ["/bin/bash"]
