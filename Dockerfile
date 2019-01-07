FROM norionomura/swift:421

RUN apt-get update
RUN apt-get install -y postgresql libpq-dev cmake

WORKDIR /app

# cmark
RUN git clone https://github.com/commonmark/cmark
RUN make -C cmark INSTALL_PREFIX=/usr/local
RUN make -C cmark install

# javascript deps

RUN apt-get install --yes curl nodejs npm

RUN update-alternatives --install /usr/bin/node node /usr/bin/nodejs 10

# TODO use other sass impl?
RUN npm install -g sass browserify

COPY package.json package-lock.json ./
RUN npm install

COPY assets_source ./assets_source
COPY assets ./assets
# RUN browserify assets_source/javascripts/application.js > assets/application.js
# COPY build-css.sh ./
# RUN ./build-css.sh

COPY Package.swift LinuxMain.swift ./
RUN swift package update

COPY Sources ./Sources
COPY Tests ./Tests

RUN swift test && swift build --configuration release

COPY data ./data

EXPOSE 8765

CMD [".build/release/swifttalk-server"]

# RUN apt-get install --yes automake libc6-dbg
# RUN git clone git://sourceware.org/git/valgrind.git && cd valgrind  && ./autogen.sh && ./configure --prefix=/usr/local && make && make install
# COPY episode108.txt .
# RUN swift build --product highlight-html
# CMD ["cat episode108.txt | .build/debug/highlight-html"]
#
# # valgrind --leak-check=full .build/debug/highlight-html < episode108.txt
