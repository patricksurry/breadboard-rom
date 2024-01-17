py65mon -m 65c02 -l rom.bin -a 8000

micromamba activate eeprom-writer

python ../eeprom-writer/zwrite.py rom.bin
