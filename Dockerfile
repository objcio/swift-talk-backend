FROM norionomura/swift:421

RUN apt-get update
RUN apt-get install -y postgresql libpq-dev

WORKDIR /app

# cmark
RUN apt-get -y install cmake
RUN git clone https://github.com/commonmark/cmark
RUN make -C cmark INSTALL_PREFIX=/usr/local
RUN make -C cmark install

# javascript deps

RUN apt-get install --yes curl nodejs npm

RUN update-alternatives --install /usr/bin/node node /usr/bin/nodejs 10

# TODO use other sass impl?
RUN npm install -g sass
RUN npm install -g browserify

COPY package.json package-lock.json ./
RUN npm install

COPY assets_source ./assets_source
COPY assets ./assets
RUN browserify assets_source/javascripts/application.js > assets/application.js
COPY build-css.sh ./
RUN ./build-css.sh

COPY Package.swift ./
RUN swift package update

COPY Sources ./Sources

RUN swift build --product swifttalk-server --configuration release

COPY data ./data

EXPOSE 8765

CMD [".build/release/swifttalk-server"]
