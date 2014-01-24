CFLAGS ?= -std=gnu99 -Wall -Wextra -pedantic -O2 -g
LDFLAGS ?= -lrt
cscppc: cscppc.o
clean:
	rm -f cscppc cscppc.o
