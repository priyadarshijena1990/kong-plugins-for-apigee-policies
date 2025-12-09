FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    luarocks \
    unzip

# Install busted
RUN luarocks install busted

# Install kong-pongo
RUN curl -Ls https://get.konghq.com/pongo | bash -s

# Set up the workspace
WORKDIR /app
COPY . .

# Set the entrypoint
ENTRYPOINT ["/usr/local/bin/pongo"]

