APP=scoreplayer
SRC=src/main.m src/SPExpression.m src/SPScoreParser.m src/SPMIDIWriter.m
OBJ=$(SRC:.m=.o)

GNUSTEP_CONFIG := $(shell command -v gnustep-config 2>/dev/null)

ifdef GNUSTEP_CONFIG
OBJCFLAGS += $(shell gnustep-config --objc-flags) -Wall -Wextra
LIBS += $(shell gnustep-config --base-libs) -lm
else
OBJCFLAGS += -Wall -Wextra
LIBS += -framework Foundation
endif

all: $(APP)

$(APP): $(OBJ)
	$(CC) $(OBJCFLAGS) -o $@ $(OBJ) $(LIBS)

.m.o:
	$(CC) $(OBJCFLAGS) -c $< -o $@

clean:
	rm -f $(APP) $(OBJ)

.PHONY: all clean
