FROM rocker/geospatial:4.5.1

RUN apt-get update && apt-get install -y \
    libpq-dev \
    unzip \
    curl \
    cargo \
    binutils \
    gettext-base \
    python3.13 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt/*

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm awscliv2.zip \
    && rm -rf aws

# Install Google Earth Engine Python API
RUN pip3 install --no-cache-dir earthengine-api

# Install required R packages
RUN install2.r --error \
    targets \
    logger \
    httr2 \
    DBI \
    RPostgres \
    dataRetrieval \
    janitor \
    rgee \
    reticulate \
    paws.storage \
    && rm -rf /tmp/downloaded_packages

# Create app directory
WORKDIR /app

# Copy R code
COPY R/ R/
COPY _targets.R .
COPY run.R .

# Set default environment variables
ENV AKTEMPVIZ_DATA_DIR=/data

# Create data directory
RUN mkdir -p /data

# Set entrypoint
ENTRYPOINT ["Rscript", "run.R"]