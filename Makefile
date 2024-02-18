CL65 = ../cc65/bin/cl65
P8 = ../p8fs

.SUFFIXES:

all: clean rom

clean:
	rm -f *.bin *.lst *.map *.sym *.o *.mon

rom: rom.bin

rom.bin: rom.asm
	$(CL65) -g --verbose --asm-include-dir $(P8) --obj-path $(P8) --target none --config breadboard.cfg -l rom.lst -m rom.map -Ln rom.sym -o rom.bin p8fs.o rom.asm
	python lint65.py rom.lst
