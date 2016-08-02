.PHONY: clean run

PROGNAME = chars

run: out/$(PROGNAME).prg
	x64sc out/$(PROGNAME).prg

out/$(PROGNAME).prg: $(PROGNAME).asm
	mkdir -p out
	kickass -o out/$(PROGNAME).prg $(PROGNAME).asm

clean:
	rm -rf out
