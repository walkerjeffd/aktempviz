FROM rocker/geospatial:4.5.1

RUN apt update -y && \
    apt-get install -y \
    libpq-dev \
    unzip \
    curl \
    python3 \
    python3-pip \
    # cargo \
    # binutils \
    # gettext-base \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt/*

# Create symlinks so reticulate can find python
RUN ln -s /usr/bin/python3 /usr/bin/python

# Verify the installation
RUN python --version
RUN pip --version

# Install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm awscliv2.zip \
    && rm -rf aws

# Install Google Earth Engine Python API
RUN pip3 install --no-cache-dir --break-system-packages earthengine-api

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
    googleCloudStorageR \
    geojsonio \
    && rm -rf /tmp/downloaded_packages

# Create app directory
WORKDIR /home/rstudio

# Copy R code
COPY R/ R/
COPY _targets.R .
COPY run.R .

# Create data directory
RUN mkdir -p data/output

# Set entrypoint
ENTRYPOINT ["Rscript", "run.R"]