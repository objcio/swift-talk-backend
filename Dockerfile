FROM norionomura/swift:421

RUN apt-get update
RUN apt-get install -y postgresql libpq-dev cmake

WORKDIR /app

# cmark
RUN git clone -b '0.29.0' https://github.com/commonmark/cmark
RUN make -C cmark INSTALL_PREFIX=/usr/local
RUN make -C cmark install

# javascript deps

RUN apt-get install --yes curl nodejs npm

RUN update-alternatives --install /usr/bin/node node /usr/bin/nodejs 10

COPY package.json package-lock.json ./
RUN npm install

COPY assets ./assets
COPY Package.swift LinuxMain.swift ./
RUN swift package update

COPY Sources ./Sources
COPY Tests ./Tests

RUN swift test && swift build --configuration release

EXPOSE 8765

CMD [".build/release/swifttalk-server"]
