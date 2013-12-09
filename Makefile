CFLAGS ?= -std=gnu99 -Wall -Wextra -pedantic -O2 -g
LDFLAGS ?= -lrt
cppcheck-gcc: cppcheck-gcc.o
clean:
	rm -f cppcheck-gcc cppcheck-gcc.o
