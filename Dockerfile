FROM --platform=linux/amd64 swift:5.5.1

RUN set -eux; \
    sed -i \
        -e 's|http://archive.ubuntu.com/ubuntu|https://mirrors.edge.kernel.org/ubuntu|g' \
        -e 's|http://security.ubuntu.com/ubuntu|https://mirrors.edge.kernel.org/ubuntu|g' \
        /etc/apt/sources.list; \
    for attempt in 1 2 3 4 5; do \
        apt-get -o Acquire::Retries=5 -o Acquire::https::Timeout=30 update && \
        apt-get -o Acquire::Retries=5 -o Acquire::https::Timeout=30 install -y \
            libssl-dev \
            postgresql \
            libpq-dev \
            cmake && \
        break; \
        if [ "$attempt" -eq 5 ]; then exit 1; fi; \
        rm -rf /var/lib/apt/lists/*; \
        sleep 5; \
    done; \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY assets ./assets
COPY Package.swift Package.resolved ./
# RUN swift package update

COPY Sources ./Sources
COPY Tests ./Tests

RUN swift test
RUN swift build --configuration release -Xswiftc -g

EXPOSE 8765
CMD [".build/release/swifttalk-server"]
