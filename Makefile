CL65 = ../cc65/bin/cl65

all: clean rom

clean:
	rm -f *.bin *.lst *.map *.sym *.o *.mon

rom: rom.bin

rom.bin: rom.asm
	$(CL65) -g --verbose --target none --config breadboard.cfg -l rom.lst -m rom.map -Ln rom.sym -o rom.bin rom.asm
