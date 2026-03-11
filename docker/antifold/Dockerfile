FROM python:3.10-slim

WORKDIR /app

RUN mkdir -p /app/opt

RUN python -m pip install --no-cache-dir antifold==0.3.1

COPY Dockerfile /app/opt/Dockerfile


# --------------------------------------------------
# Optional test setup
# Uncomment only if you want to test AntiFold
# --------------------------------------------------

# RUN apt-get update && apt-get install -y \
#     wget \
#     && rm -rf /var/lib/apt/lists/*

# RUN mkdir -p /app/data && \
#     wget -O /app/data/6y1l_imgt.pdb \
#     https://raw.githubusercontent.com/oxpig/AntiFold/master/data/pdbs/6y1l_imgt.pdb

# ENTRYPOINT ["python", "-m", "antifold.main"]

# CMD ["--pdb_file", "/app/data/6y1l_imgt.pdb"]
