# Dockerfile for ABodyBuilder2 (ImmuneBuilder)
# Tool: ABodyBuilder2 - Antibody structure prediction for sequence validation
# Source: https://github.com/oxpig/ImmuneBuilder
FROM continuumio/miniconda3:latest

LABEL maintainer="nf-core"
LABEL description="ABodyBuilder2 - Antibody structure prediction tool from ImmuneBuilder"
LABEL version="1.0.0"
LABEL org.opencontainers.image.source="https://github.com/oxpig/ImmuneBuilder"

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    wget \
    curl \
    git \
    hmmer \
    && rm -rf /var/lib/apt/lists/*

# Create working directory
WORKDIR /app

# Install openmm + pdbfixer via conda (pip cannot do this reliably)
RUN conda install -y -c conda-forge \
    python=3.10 \
    openmm \
    pdbfixer \
    && conda clean -afy

# Install PyTorch (CPU version)
RUN pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu

# Install ANARCI
RUN pip install --no-cache-dir anarci

# Install ImmuneBuilder
RUN pip install --no-cache-dir ImmuneBuilder

# Verify ANARCI
RUN python -c "from anarci import anarci; print('✓ ANARCI installed')" || true

# Create directories
RUN mkdir -p /data/input /data/output

WORKDIR /data

# Verify full installation
RUN python -c "from ImmuneBuilder import ABodyBuilder2; print('✓ ABodyBuilder2 installed successfully')"

ENTRYPOINT ["/bin/bash"]
CMD []