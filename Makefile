CFLAGS ?= -std=gnu99 -Wall -Wextra -pedantic -O2 -g
LDFLAGS ?= -pthread
cscppc: cscppc.o
clean:
	rm -f cscppc cscppc.o
