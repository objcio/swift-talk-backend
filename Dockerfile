FROM norionomura/swift:41

RUN apt-get update
RUN apt-get install -y postgresql libpq-dev

WORKDIR /app

# cmark
RUN apt-get -y install cmake
RUN git clone https://github.com/commonmark/cmark
RUN make -C cmark INSTALL_PREFIX=/usr
RUN make -C cmark install

COPY Package.swift ./
COPY Sources ./Sources
# COPY Tests ./Tests

RUN swift package update
RUN swift build --product swifttalk-server --configuration release

EXPOSE 8765

CMD [".build/release/swifttalk-server"]
