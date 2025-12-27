BUILD_MODE?=Debug

CXX:=clang++
CXX_WARNINGS:=-Wall -pedantic -Werror
CXX_CORE_ARGS:=-std=c++20 -Iinclude -Iexternal/include
CXX_DEBUG_ARGS:=-g -Og -fsanitize=address,undefined -DDEBUG
CXX_RELEASE_ARGS:=-O3 -flto -DRELEASE

LD_ARGS+=-lglut -lOpenGL

CXX_ARGS+=$(CXX_CORE_ARGS) $(CXX_WARNINGS)
ifeq ($(BUILD_MODE), Debug)
CXX_ARGS+=$(CXX_DEBUG_ARGS)
LD_ARGS+=$(CXX_DEBUG_ARGS)
else
CXX_ARGS+=$(CXX_RELEASE_ARGS)
LD_ARGS+=$(CXX_RELEASE_ARGS)
endif

SDK_LIB:=external/lib/libsl_lidar_sdk.a
SDK_INCLUDE:=-Iexternal/rplidar_sdk/sdk/include

SOURCES:=$(wildcard src/*.cpp)
OBJECTS:=$(patsubst src/%.cpp, lib/%.o, $(SOURCES))
TESTS:=$(wildcard tests/*.cpp)
TEST_OBJECTS:=$(patsubst tests/%.cpp, lib/%.o, $(TESTS))
TEST_BUILDS:=$(patsubst tests/%.cpp, bin/tests/%, $(TESTS))
MAIN:=main.cpp
MAIN_OBJECT:=lib/main.o
MAIN_BUILD:=bin/scanapp
ALL_OBJECTS:=$(OBJECTS) $(TEST_OBJECTS) $(MAIN_OBJECT) $(STATIC_LIBS)
COMP_COMMANDS:=$(patsubst lib/%.o, cc/%.json, $(ALL_OBJECTS))

default: all

all: cc tests main

cc: compile_commands.json

tests: $(TEST_BUILDS)
	./runtests.sh $^

main: $(MAIN_BUILD)
	true

clean:
	rm -rf lib bin cc $(INSTR)
	bash external/clean.sh

$(SDK_LIB):
	export CXX="$(CXX)"; \
	export CXX_ARGS="$(CXX_ARGS)"; \
	bash external/buildsdk.sh

compile_commands.json: $(ALL_OBJECTS)
	sed -e '1s/^/[\'$$'\n''/' -e '$$s/,$$/\'$$'\n'']/' $(COMP_COMMANDS) > $@

lib/%.o: src/%.cpp $(SDK_LIB)
	mkdir -p lib cc; \
	$(CXX) $(CXX_ARGS) $(SDK_INCLUDE) -MJ $(patsubst lib/%.o, cc/%.json, $@) -c $< -o $@

lib/%.o: tests/%.c
	mkdir -p lib cc; \
	$(CXX) $(CXX_ARGS) $(SDK_INCLUDE) -MJ $(patsubst lib/%.o, cc/%.json, $@) -c $< -o $@

$(MAIN_OBJECT): $(MAIN) $(SDK_LIB)
	mkdir -p lib cc; \
	$(CXX) $(CXX_ARGS) $(SDK_INCLUDE) -MJ cc/main.json -c $< -o $@

$(MAIN_BUILD): $(OBJECTS) $(MAIN_OBJECT) $(SDK_LIB)
	mkdir -p bin; \
	$(CXX) $(LD_ARGS) $^ -o $@

bin/tests/%: lib/%.o $(SDK_LIB) $(OBJECTS)
	mkdir -p bin/tests; \
	$(CXX) $(LD_ARGS) $^ -o $@

