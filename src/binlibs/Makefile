include ../config

all: libraries install
$(PLATFORM): all

SRC  = pluto.c rings.c bit.c

LIBS = pluto.$(LIBEXT) rings.$(LIBEXT) bit.$(LIBEXT)

ifeq ($(USE_READLINE), yes)
LIBS += editline.$(LIBEXT)
endif

libraries: $(LIBS)

install:   libraries
	mkdir -p $(TARGET_LUA_CPATH)
	cp $(LIBS) $(TARGET_LUA_CPATH)

clean:
	-rm *.o *.$(LIBEXT)

ifeq ($(USE_READLINE), yes)
editline.$(LIBEXT): editline.$(OBJEXT)
	$(MKLIB) -o $@ $+ $(LDFLAGS) -lhistory -lreadline
endif


pluto.$(LIBEXT): pluto/pluto.c pluto/pdep.c pluto/lzio.c
	$(MKLIB) -o $@ $(LDFLAGS) -I ../$(LUA_VM_DIR) -I pluto $+

%.$(LIBEXT): %.$(OBJEXT)
	$(MKLIB) -o $@ $+ $(LDFLAGS)

.PHONY: libraries install clean

