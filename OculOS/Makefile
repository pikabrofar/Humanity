.PHONY: app run test clean cnn-model

# Swift Testing lives outside the default search path when only the Command
# Line Tools are installed; these flags are harmless with full Xcode.
CLT_DEV := /Library/Developer/CommandLineTools/Library/Developer
TEST_FLAGS := $(if $(wildcard $(CLT_DEV)/Frameworks/Testing.framework),\
	-Xswiftc -F -Xswiftc $(CLT_DEV)/Frameworks \
	-Xlinker -F -Xlinker $(CLT_DEV)/Frameworks \
	-Xlinker -rpath -Xlinker $(CLT_DEV)/Frameworks \
	-Xlinker -rpath -Xlinker $(CLT_DEV)/usr/lib)

app:
	./scripts/build-app.sh release

run: app
	open build/OculOS.app

test:
	swift test $(TEST_FLAGS)

cnn-model:
	./scripts/make-cnn-model.sh

clean:
	rm -rf .build build
