FROM norionomura/swift:41

RUN apt-get update
RUN apt-get install -y postgresql libpq-dev

WORKDIR /app

# cmark
RUN apt-get -y install cmake
RUN git clone https://github.com/commonmark/cmark
RUN make -C cmark INSTALL_PREFIX=/usr/local
RUN make -C cmark install

# javascript deps

COPY package.json ./
COPY package-lock.json ./
RUN apt-get install --yes curl
# RUN curl --silent --location https://deb.nodesource.com/setup_4.x | sudo bash -
RUN apt-get install --yes nodejs npm 

RUN update-alternatives --install /usr/bin/node node /usr/bin/nodejs 10

RUN npm install
RUN npm install -g sass 
# TODO use other sass impl?
COPY assets ./assets
COPY build-css.sh ./
RUN ./build-css.sh

COPY Package.swift ./
RUN swift package update

COPY Sources ./Sources
# COPY Tests ./Tests

RUN swift build --product swifttalk-server --configuration release

COPY data ./data
COPY .env* ./

EXPOSE 8765

CMD [".build/release/swifttalk-server"]
