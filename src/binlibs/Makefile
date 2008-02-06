include ../config

all: libraries install
$(PLATFORM): all

SRC  = pluto.c rings.c bit.c
LIBS = $(SRC:.c=.$(LIBEXT)) 

libraries: $(LIBS)

install:   libraries
	mkdir -p $(TARGET_LUA_CPATH)
	cp $(LIBS) $(TARGET_LUA_CPATH)

clean:
	-rm *.o *.$(LIBEXT)

.PHONY: libraries install clean

%.$(LIBEXT): %.$(OBJEXT)
	$(MKLIB) -o $@ $+ $(LDFLAGS)

