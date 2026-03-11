FROM continuumio/miniconda3:latest

LABEL maintainer="nf-core"
LABEL description="ABodyBuilder2 - Antibody structure prediction tool from ImmuneBuilder"
LABEL version="1.0.0"
LABEL org.opencontainers.image.source="https://github.com/oxpig/ImmuneBuilder"

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    wget \
    curl \
    git \
    hmmer \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install openmm + pdbfixer via conda (pip cannot do this reliably)
RUN conda install -y -c conda-forge \
    python=3.10 \
    openmm \
    pdbfixer \
    && conda clean -afy

RUN pip install --no-cache-dir \
    torch \
    anarci \
    ImmuneBuilder

CMD []