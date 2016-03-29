CGO_ENABLED=0
GOOS=linux
GOARCH=amd64
TAG=${TAG:-latest}

all: build

clean:
	@rm -rf test

build:
	godep go build
