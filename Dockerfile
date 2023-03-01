FROM --platform=linux/amd64 swift:5.5.1

RUN apt-get update
RUN apt-get install -y --fix-missing libssl-dev
RUN apt-get install -y postgresql libpq-dev cmake

WORKDIR /app

COPY assets ./assets
COPY Package.swift LinuxMain.swift ./
# RUN swift package update

COPY Sources ./Sources
COPY Tests ./Tests

RUN swift test
RUN swift build --configuration release -Xswiftc -g

EXPOSE 8765
CMD [".build/release/swifttalk-server"]
