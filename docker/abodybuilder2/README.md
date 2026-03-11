# ABodyBuilder2 Docker Image

Docker image for [ABodyBuilder2](https://github.com/oxpig/ImmuneBuilder) - antibody structure prediction for sequence validation.

## Overview

ABodyBuilder2 is part of the ImmuneBuilder package, providing state-of-the-art antibody structure prediction. This Docker image packages all dependencies for easy deployment.

## Quick Start

### Build the Image

```bash
cd docker/abodybuilder2
chmod +x build.sh
./build.sh
```

### Run ABodyBuilder2

```bash
# Show help
docker run --rm abodybuilder2:latest help

# Predict antibody structure from FASTA file
docker run --rm -v /path/to/data:/data abodybuilder2:latest predict \
    --fasta /data/input/antibody.fasta \
    --output /data/output/structure.pdb

# Interactive session
docker run -it --rm -v /path/to/data:/data abodybuilder2:latest bash
```

### Example: Predict Structure

```bash
# Create input FASTA file
cat > antibody.fasta << 'EOF'
>heavy_chain
EVQLVESGGGLVQPGGSLRLSCAASGFTFSSYAMSWVRQAPGKGLEWVSAISGSGGSTY
YADSVKGRFTISRDNSKNTLYLQMNSLRAEDTAVYYCARLAAAMDY
>light_chain
DIQMTQSPSSLSASVGDRVTITCRASQSISSYLNWYQQKPGKAPKLLIYAASSLQSGVP
SRFSGSGSGTDFTLTISSLQPEDFATYYCQQSYSTPLTFGGGTKVEIK
EOF

# Run prediction
docker run --rm -v $(pwd):/data abodybuilder2:latest ABodyBuilder2 \
    --fasta /data/antibody.fasta \
    --output /data/predicted_structure.pdb
```

## Push to Registry

### Docker Hub

```bash
# Login to Docker Hub
docker login

# Set username and push
export DOCKERHUB_USER=your-username
./build.sh --push --tag 1.0.0
```

### GitHub Container Registry

```bash
# Login to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_USER --password-stdin

# Set username and push
export GITHUB_USER=your-github-username
./build.sh --push --ghcr --tag 1.0.0
```

## Image Details

- **Base Image**: `python:3.10-slim`
- **PyTorch**: CPU version (for smaller image)
- **Size**: ~2-3 GB

### Installed Packages

- PyTorch (CPU)
- ImmuneBuilder (includes ABodyBuilder2)
- ANARCI (antibody numbering)
- HMMER (sequence analysis)

### GPU Support

For GPU acceleration, modify the Dockerfile to use CUDA-enabled PyTorch:

```dockerfile
# Replace:
RUN pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu

# With:
RUN pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cu118
```

Then run with GPU:

```bash
docker run --gpus all -v /path/to/data:/data abodybuilder2:latest ABodyBuilder2 ...
```

## Troubleshooting

### Memory Issues

ABodyBuilder2 can be memory-intensive. Increase Docker memory limits:

```bash
docker run --memory=8g --rm -v /data:/data abodybuilder2:latest ...
```

### Verify Installation

```bash
docker run --rm abodybuilder2:latest python -c \
    "from ImmuneBuilder import ABodyBuilder2; print('OK')"
```

## References

- [ImmuneBuilder GitHub](https://github.com/oxpig/ImmuneBuilder)
- [ABodyBuilder2 Paper](https://doi.org/10.1038/s42003-023-04927-7)
