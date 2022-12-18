PHONY: build

CC := clang
AR := ar
CFLAGS := --std=c99 \
	-Wall -O3 -g0 \
	-Wl,-s \
	-I./vendor \
	-DSQLITE_MUTEX_NOOP=1 \
	-D__DARWIN__
LFLAGS := -lm

#####################################
STACK_SIZE := $$(( 8 * 1024 * 1024 ))
NO_BUILT_INS=-fno-builtin-sin -fno-builtin-cos \
	-fno-builtin-ceil -fno-builtin-floor \
	-fno-builtin-pow -fno-builtin-round  \
	-fno-builtin-abs -fno-builtin-malloc \
	-fno-builtin-rand -fno-builtin-srand
WASM_CC := emcc
WASM_CFLAGS := --target=wasm32 \
	-Wall -O0 -g \
	-I./vendor \
	-Wl,--export-dynamic \
	-Wl,--no-entry \
	-Wl,--lto-O3 \
	-Wl,-z,stack-size=$(STACK_SIZE) \
	-lm 

#####################################
SRC=src
OBJ=obj
ALL_SRCS=$(wildcard $(SRC)/*.c)
HDRS=$(wildcard $(SRC)/*.h)

# find all the test files
TEST_SRCS=$(sort $(wildcard $(SRC)/*_test.c) $(wildcard $(SRC)/*/*_test.c))
# and remove them from the normal build.
SRCS=$(filter-out $(TEST_SRCS), $(wildcard $(ALL_SRCS)))
OBJS=$(patsubst $(SRC)/%.c, $(OBJ)/%.o, $(SRCS))
# tests, including test files
TEST_OBJS=$(patsubst $(SRC)/%.c, $(OBJ)/%.o, $(ALL_SRCS))
# for tests build, remove main
TEST_OBJS_NO_MAIN=$(filter-out $(OBJ)/main.o, $(wildcard $(OBJS)))

VERSION=$(shell git rev-parse --short=4 HEAD)

BUILD=build
NAME=stitch
TESTS=$(BUILD)/tests
STATIC=$(BUILD)/lib$(NAME).a
BIN=$(NAME)
HTML=$(BUILD)/version.html

UNAME = uname
MACHINE ?= $(shell $(UNAME) -m)
SYSTEM ?= $(shell $(UNAME) -s)

#####################################

build: preflight $(BIN)

lib: preflight $(STATIC)

wasm: preflight
	docker run --rm \
		-v $(PWD):/src \
		-u $(shell id -u):$(shell id -g) \
		emscripten/emsdk \
		$(WASM_CC) -v $(WASM_CFLAGS) $(ALL_SRCS) -o lib$(NAME).wasm
	mv lib$(NAME).wasm ./$(BUILD)/

wasm_test:
	busboy --secure --root=./$(BUILD)

$(STATIC): $(OBJS)
	$(AR) rc $@ $(OBJS)

$(BIN): $(OBJS)
	mkdir -p $(BUILD)/$(SYSTEM)-$(MACHINE)
	$(CC) $(OBJS) $(CFLAGS) -o $(BUILD)/$(SYSTEM)-$(MACHINE)/$@ $(LFLAGS)

$(OBJ)/%.o: $(SRC)/%.c 
	$(CC) $(CFLAGS) -c $< -o $@ $(LFLAGS)

preflight: 
	mkdir -p build
	mkdir -p obj

clean:
	rm -rf build
	rm -rf obj
