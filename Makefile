DERIVED_DATA := $(shell mktemp -d)
CURRENT_DIRECTORY := $(shell pwd)
BUILD_LOG := $(CURRENT_DIRECTORY)/build.log

.PHONY: build test integrate_cocoapods

build:
	@echo "Building sample app..."
	set -o pipefail && time xcodebuild clean build \
		-project LayoutKit.xcodeproj \
		-scheme LayoutKitSampleApp \
		-sdk iphonesimulator14.0 \
		-derivedDataPath $(DERIVED_DATA) \
		-destination 'platform=iOS Simulator,name=iPhone 6,OS=12.4' \
		OTHER_SWIFT_FLAGS='-Xfrontend -debug-time-function-bodies' \
		| tee $(BUILD_LOG) | bundle exec xcpretty
	cat $(BUILD_LOG) | sh debug-time-function-bodies.sh

test:
	@echo "Run tests on iOS..."
	set -o pipefail && time xcodebuild clean test \
		-project LayoutKit.xcodeproj \
		-scheme LayoutKit-iOS \
		-sdk iphonesimulator14.0 \
		-derivedDataPath $(DERIVED_DATA) \
		-destination 'platform=iOS Simulator,name=iPhone 6,OS=12.4' \
		OTHER_SWIFT_FLAGS='-Xfrontend -debug-time-function-bodies' \
		| tee $(BUILD_LOG) | bundle exec xcpretty
	cat $(BUILD_LOG) | sh debug-time-function-bodies.sh

integrate_cocoapods:
	@echo "Building an iOS empty project with cocoapods..."
	bundle exec pod install --project-directory=Tests/cocoapods/ios
	set -o pipefail && time xcodebuild clean build \
		-workspace Tests/cocoapods/ios/LayoutKit-iOS.xcworkspace \
		-scheme LayoutKit-iOS \
		-sdk iphonesimulator14.0 \
		-derivedDataPath $(DERIVED_DATA) \
		-destination 'platform=iOS Simulator,name=iPhone 6,OS=12.4' \
		OTHER_SWIFT_FLAGS='-Xfrontend -debug-time-function-bodies' \
		| tee $(BUILD_LOG) | bundle exec xcpretty
	cat $(BUILD_LOG) | sh debug-time-function-bodies.sh
