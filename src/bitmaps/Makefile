.PHONY: clean run

PROGNAME = bitmaps

run: out/$(PROGNAME).prg
	x64sc out/$(PROGNAME).prg

out/$(PROGNAME).prg: $(PROGNAME).asm
	mkdir -p out
	kickass -libdir ../macros -o out/$(PROGNAME).prg $(PROGNAME).asm

clean:
	rm -rf out
