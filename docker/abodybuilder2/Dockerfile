FROM continuumio/miniconda3

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install openmm and pdbfixer via conda (not reliably pip-installable)
RUN conda install -y -c conda-forge \
    python=3.9 \
    openmm \
    pdbfixer \
    && conda clean -afy

# Install ImmuneBuilder and anarci via pip
RUN pip install --no-cache-dir \
    ImmuneBuilder \
    anarci

CMD ["ABodyBuilder2", "--help"]
