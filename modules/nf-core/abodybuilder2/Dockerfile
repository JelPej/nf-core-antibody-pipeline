FROM continuumio/miniconda3:latest

LABEL maintainer="nf-core"
LABEL description="ImmuneBuilder with installed weights"
LABEL version="1.1.1"
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

RUN wget -O "/opt/conda/lib/python3.10/site-packages/ImmuneBuilder/trained_model/antibody_model_1" \
    "https://zenodo.org/record/7258553/files/antibody_model_1?download=1"
RUN wget -O "/opt/conda/lib/python3.10/site-packages/ImmuneBuilder/trained_model/antibody_model_2" \
    "https://zenodo.org/record/7258553/files/antibody_model_2?download=1"
RUN wget -O "/opt/conda/lib/python3.10/site-packages/ImmuneBuilder/trained_model/antibody_model_3" \
    "https://zenodo.org/record/7258553/files/antibody_model_3?download=1"
RUN wget -O "/opt/conda/lib/python3.10/site-packages/ImmuneBuilder/trained_model/antibody_model_4" \
    "https://zenodo.org/record/7258553/files/antibody_model_4?download=1"

RUN wget -O "/opt/conda/lib/python3.10/site-packages/ImmuneBuilder/trained_model/nanobody_model_1" \
    "https://zenodo.org/record/7258553/files/nanobody_model_1?download=1"
RUN wget -O "/opt/conda/lib/python3.10/site-packages/ImmuneBuilder/trained_model/nanobody_model_2" \
    "https://zenodo.org/record/7258553/files/nanobody_model_2?download=1"
RUN wget -O "/opt/conda/lib/python3.10/site-packages/ImmuneBuilder/trained_model/nanobody_model_3" \
    "https://zenodo.org/record/7258553/files/nanobody_model_3?download=1"
RUN wget -O "/opt/conda/lib/python3.10/site-packages/ImmuneBuilder/trained_model/nanobody_model_4" \
    "https://zenodo.org/record/7258553/files/nanobody_model_4?download=1"

RUN wget -O "/opt/conda/lib/python3.10/site-packages/ImmuneBuilder/trained_model/tcr2_plus_model_1" \
    "https://zenodo.org/records/10892159/files/tcr_model_1?download=1"
RUN wget -O "/opt/conda/lib/python3.10/site-packages/ImmuneBuilder/trained_model/tcr2_plus_model_2" \
    "https://zenodo.org/record/10892159/files/tcr_model_2?download=1"
RUN wget -O "/opt/conda/lib/python3.10/site-packages/ImmuneBuilder/trained_model/tcr2_plus_model_3" \
    "https://zenodo.org/record/10892159/files/tcr_model_3?download=1"
RUN wget -O "/opt/conda/lib/python3.10/site-packages/ImmuneBuilder/trained_model/tcr2_plus_model_4" \
    "https://zenodo.org/record/10892159/files/tcr_model_4?download=1"

RUN wget -O "/opt/conda/lib/python3.10/site-packages/ImmuneBuilder/trained_model/tcr2_model_1" \
     "https://zenodo.org/record/7258553/files/tcr_model_1?download=1"
RUN wget -O "/opt/conda/lib/python3.10/site-packages/ImmuneBuilder/trained_model/tcr2_model_2" \
     "https://zenodo.org/record/7258553/files/tcr_model_2?download=1"
RUN wget -O "/opt/conda/lib/python3.10/site-packages/ImmuneBuilder/trained_model/tcr2_model_3" \
     "https://zenodo.org/record/7258553/files/tcr_model_3?download=1"
RUN wget -O "/opt/conda/lib/python3.10/site-packages/ImmuneBuilder/trained_model/tcr2_model_4" \
    "https://zenodo.org/record/7258553/files/tcr_model_4?download=1"

CMD []