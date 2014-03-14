CFLAGS ?= -std=gnu99 -Wall -Wextra -pedantic -O2 -g
LDFLAGS ?= -pthread

.PHONY: all clean

all: cscppc cscppc.1

cscppc: cscppc.o

cscppc.1: cscppc.txt
	a2x -f manpage -v $<

clean:
	rm -f cscppc cscppc.o cscppc.1 cscppc.xml
