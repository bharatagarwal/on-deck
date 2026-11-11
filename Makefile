SWIFT_DIRS = Iterate IterateUITests
XCODEBUILD = xcodebuild -project Iterate.xcodeproj -scheme Iterate \
	-destination 'platform=macOS,arch=$(shell uname -m)' -derivedDataPath build.noindex

.PHONY: verify lint format test build

verify: lint test
	$(MAKE) build

lint:
	xcrun swift-format lint --strict --recursive $(SWIFT_DIRS)
	swiftlint lint --strict

format:
	xcrun swift-format format --in-place --recursive $(SWIFT_DIRS)

test:
	$(XCODEBUILD) -parallel-testing-enabled NO test

build:
	$(XCODEBUILD) -configuration Release build
