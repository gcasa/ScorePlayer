GNUSTEP_MAKEFILES ?= $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)

ifeq ($(GNUSTEP_MAKEFILES),)
$(error GNUSTEP_MAKEFILES is not set. Source GNUstep.sh or install gnustep-make)
endif

include $(GNUSTEP_MAKEFILES)/common.make

TOOL_NAME = scoreplayer

scoreplayer_OBJC_FILES = \
	src/main.m \
	src/SPExpression.m \
	src/SPScoreParser.m \
	src/SPMIDIWriter.m

scoreplayer_HEADER_FILES = \
	src/SPExpression.h \
	src/SPScoreParser.h \
	src/SPMIDIWriter.h

scoreplayer_TOOL_LIBS += -lm

ADDITIONAL_OBJCFLAGS += -Wall -Wextra

include $(GNUSTEP_MAKEFILES)/tool.make
