FROM rocker/geospatial:4.4.2

RUN apt-get update && apt-get install -y \
    libpq-dev \
    unzip \
    curl \
    cargo \
    binutils \
    gettext-base \
    nfs-common \
    stunnel4 \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt/*

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm awscliv2.zip \
    && rm -rf aws

# Install efs-utils
RUN git clone https://github.com/aws/efs-utils && \
    cd efs-utils && \
    ./build-deb.sh && \
    apt-get -y install ./build/amazon-efs-utils*deb && \
    cd .. && \
    rm -rf efs-utils

# Install required R packages
RUN install2.r --error \
    targets \
    logger \
    httr2 \
    DBI \
    RPostgres \
    daymetr \
    dataRetrieval \
    janitor \
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

# Create symlink for _targets directory
RUN ln -s /data/_targets /app/_targets

# Set entrypoint
ENTRYPOINT ["Rscript", "run.R"]