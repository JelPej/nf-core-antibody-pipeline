# **Project 2 — Antibody Optimization Pipeline**

## **Step-by-Step Task List**

---

## **Group 2a: 1\. AntiFold module — CDR redesign**

## **2\. BioPhi Sapiens module — humanization** 

## **3\. Connect with group 2b and create an end to end pipeline**   **Group 2b: 1\. ABodyBuilder2 module — structural verification**

## **2\. OASis module — humanness scoring** 

## **3\. Connect with group 2a and create an end to end pipeline** 

## **—----------------------------------------------------------------------**

| Tool | Link |
| ----- | ----- |
| AntiFold | [https://github.com/oxpig/AntiFold](https://github.com/oxpig/AntiFold) |
| ABodyBuilder2 (ImmuneBuilder) | [https://github.com/oxpig/ImmuneBuilder](https://github.com/oxpig/ImmuneBuilder) |
| BioPhi (Sapiens) | [https://github.com/Merck/BioPhi](https://github.com/Merck/BioPhi) |
| OASis DB (Zenodo) | [https://zenodo.org/record/5164685](https://zenodo.org/record/5164685) |

**Web servers (no install needed for testing)**

| Tool | Link |
| ----- | ----- |
| AntiFold webserver | [https://opig.stats.ox.ac.uk/webapps/antifold/](https://opig.stats.ox.ac.uk/webapps/antifold/) |
| BioPhi webserver | [https://biophi.dichlab.org](https://biophi.dichlab.org) |

##  **What is already available (use as reference)**

* nf-core pipeline template — generated with `nf-core pipelines create`  
* Test PDB structure `6y1l` — pre-staged at `/data/pdb/6y1l.pdb`  
* OASis database — pre-staged at `/data/oasis/OASis_9mers_v1.db`  
* AntiFold test data — available in the AntiFold repo at `AntiFold/data/`

**Create the pipeline skeleton first:**

```shell
cd /workspace/your_username
nf-core pipelines create
# Pipeline name:  antibody-pipeline
# Description:    End-to-end antibody CDR redesign and optimization
# Author:         Your Name

cd nf-core-antibody-pipeline/

# Confirm the test PDB is available
ls /data/pdb/6y1l.pdb
ls /data/oasis/OASis_9mers_v1.db
```

---

## **What teams need to build — 4 new modules**

---

### **1\. AntiFold module — CDR redesign**

* No official Docker image → custom Dockerfile required  
* Source: https://github.com/oxpig/AntiFold  
* Input: antibody PDB file (IMGT-numbered)  
* Output: FASTA file with redesigned CDR sequence candidates

**Read the documentation and try to run AntiFold:**

```shell
# Clone AntiFold repo — includes test PDB data
git clone https://github.com/oxpig/AntiFold.git
cd AntiFold

# Explore the test data included in the repo
ls AntiFold/data/
# Contains example PDB files ready to use

# Read the usage docs
cat README.md
```

**Write the Dockerfile:**

```
FROM python:3.9-slim
RUN pip install antifold
CMD ["python", "-m", "antifold.main", "--help"]
```

**Build and test the container:**

```shell
docker build -t antifold:latest .
docker run --rm -v /data/pdb:/data antifold:latest \
  python -m antifold.main \
    --pdb_file /data/6y1l.pdb \
    --outdir /data/antifold_output/
# Expected output: FASTA file with CDR sequence candidates
```

**Create the nf-core module:**

```shell
cd /path/to/nf-core/modules
git checkout -b add-antifold-module
nf-core modules create
# Tool name:    antifold
# Subtool:      (leave blank)
# Bioconda:     (leave blank — no package)
```

**Test data:**

```shell
# Input PDB — pre-staged
/data/pdb/6y1l.pdb

# Or use AntiFold's own test data
/workspace/AntiFold/data/4byh.pdb
```

---

### **2\. ABodyBuilder2 module — structural verification**

* No official Docker image → custom Dockerfile required  
* Source: https://github.com/oxpig/ImmuneBuilder  
* Input: FASTA file of antibody sequences (output from AntiFold), find test data while waiting for results of AntiFold   
* Output: predicted PDB structures per candidate, failed predictions flagged

**Read the documentation and try to run ABodyBuilder2:**

```shell
git clone https://github.com/oxpig/ImmuneBuilder.git
cd ImmuneBuilder
cat README.md
```

**Write the Dockerfile:**

```
FROM python:3.9-slim
RUN pip install ImmuneBuilder
CMD ["ABodyBuilder2", "--help"]
```

**Build and test the container:**

```shell
docker build -t abodybuilder2:latest .

# Write a minimal test FASTA
cat > /data/test/test_antibody.fasta << 'EOF'
>heavy
EVQLVESGGGLVQPGGSLRLSCAASGFTFSSYAMSWVRQAPGKGLEWVSAISGSGGSTYYADSVKGRFTISRDNSKNTLYLQMNSLRAEDTAVYYCAR
>light
DIQMTQSPSSLSASVGDRVTITCRASQDVNTAVAWYQQKPGKAPKLLIYSASFLYSGVPSRFSGSRSGTDFTLTISSLQPEDFATYYCQQHYTTPPTFG
EOF

docker run --rm -v /data/test:/data abodybuilder2:latest \
  ABodyBuilder2 \
    --fasta /data/test_antibody.fasta \
    --output /data/abodybuilder2_output/
# Expected output: PDB file per sequence candidate
```

**Create the nf-core module:**

```shell
cd /path/to/nf-core/modules
git checkout -b add-abodybuilder2-module
nf-core modules create
# Tool name:    abodybuilder2
# Subtool:      (leave blank)
# Bioconda:     (leave blank)
```

**Test data:**

```shell
# Input FASTA — from AntiFold output, or use the test FASTA above
/data/test/test_antibody.fasta
```

---

### **3\. BioPhi Sapiens module — humanization**

* No official Docker image → shared Dockerfile with OASis (both install together)  
* Source: https://github.com/Merck/BioPhi  
* Input: antibody sequences (output from ABodyBuilder2), find test data while waiting for Abodybuilder results   
* Output: humanized sequences

**Read the documentation and try to run BioPhi:**

```shell
pip install biophi
biophi sapiens --help
```

**Write the Dockerfile (shared with OASis):**

```
FROM continuumio/miniconda3
RUN conda install -c bioconda -c conda-forge biophi -y
CMD ["biophi", "--help"]
```

**Build and test the container:**

```shell
docker build -t biophi:latest .
docker run --rm \
  -v /data/test:/data \
  -v /data/oasis:/oasis \
  biophi:latest \
  biophi sapiens /data/test_antibody.fasta \
    --oasis-db /oasis/OASis_9mers_v1.db \
    --output /data/humanized_output/
# Expected output: humanized sequence FASTA
```

**Create the nf-core module:**

```shell
cd /path/to/nf-core/modules
git checkout -b add-biophi-sapiens-module
nf-core modules create
# Tool name:    biophi
# Subtool:      sapiens
# Bioconda:     (leave blank)
```

**Test data:**

```shell
# Input sequences — from ABodyBuilder2 output, or use test FASTA
/data/test/test_antibody.fasta
# OASis database — pre-staged
/data/oasis/OASis_9mers_v1.db
```

---

### **4\. OASis module — humanness scoring**

* Uses the same Docker image as BioPhi (both install together)  
* Requires OASis database (\~22 GB, pre-staged at `/data/oasis/`)  
* Source: https://github.com/Merck/BioPhi (OASis is part of BioPhi)  
* Input: humanized sequences (output from BioPhi)  
* Output: ranked candidates with humanness scores

**Read the documentation and try to run OASis:**

```shell

```

**Test the container (same image as BioPhi):**

```shell

```

**Create the nf-core module:**

```shell
cd /path/to/nf-core/modules
git checkout -b add-oasis-module
nf-core modules create
# Tool name:    biophi
# Subtool:      oasis
# Bioconda:     (leave blank)
```

**Test data:**

```shell
# Input — humanized sequences from BioPhi output
# OASis database — pre-staged
/data/oasis/OASis_9mers_v1.db
```

---

## **End-to-end test — wire all modules together**

Once all 4 modules are written and tested individually, connect them into the pipeline:

```shell

```

**Expected final output:**

```
results/
├── antifold/         ← CDR candidate sequences (FASTA)
├── abodybuilder2/    ← refolded PDB structures
├── biophi/sapiens/   ← humanized sequences
└── biophi/oasis/     ← ranked candidates with humanness scores
```

---

## **Task summary**

| \# | Module | Docker | Input | Output | Status |
| ----- | ----- | ----- | ----- | ----- | ----- |
| 1 | AntiFold | Custom — pip install | PDB file | FASTA candidates | 🔨 Build |
| 2 | ABodyBuilder2 | Custom — pip install | FASTA | PDB per candidate | 🔨 Build |
| 3 | BioPhi Sapiens | Shared with OASis | FASTA sequences | Humanized FASTA | 🔨 Build |
| 4 | OASis | Shared with BioPhi | Humanized FASTA | Scored CSV | 🔨 Build |
| 5 | Pipeline wiring | — | 6y1l PDB | Ranked candidates | 🔨 Last step |

---

