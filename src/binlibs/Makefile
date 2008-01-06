include ../common.mk

all: libraries install
$(PLATFORM): all

SRC  = pluto.c rings.c bit.c
LIBS = $(SRC:.c=.$(LIBEXT)) 

libraries: $(LIBS)

install:   libraries
	cp $(LIBS) $(TARGET_LUA_CPATH)

clean:
	-rm *.o *.$(LIBEXT)

.PHONY: libraries install clean

%.$(LIBEXT): %.$(OBJEXT)
	$(MKLIB) -o $@ $+

