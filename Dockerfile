FROM swift:5.0.1

RUN echo ""

# workaround to make this work with the swift 5 image: 
# https://forums.swift.org/t/lldb-install-precludes-installing-python-in-image/24040
# RUN  mv /usr/lib/python2.7/site-packages /usr/lib/python2.7/dist-packages; ln -s dist-packages /usr/lib/python2.7/site-packages

RUN apt-get update
RUN apt-get install -y --fix-missing libssl-dev
RUN apt-get install -y postgresql libpq-dev cmake

WORKDIR /app

COPY assets ./assets
COPY Package.swift LinuxMain.swift ./
RUN swift package update

COPY Sources ./Sources
COPY Tests ./Tests

RUN swift test
RUN swift build --configuration release -Xswiftc -g

EXPOSE 8765
CMD [".build/release/swifttalk-server"]
