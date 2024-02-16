Development
---

    make


    micromamba activate eeprom-writer

    python ../eeprom-writer/zwrite.py rom.bin

For debugging, set PYMON=1 in rom.asm, rebuild

    py65mon -m 65c02 -l rom.bin -a 8000 -b rom.sym

    g .hello


    sudo dd bs=512 count=1 if=/dev/disk2 | hexdump -C
TODO
---

- kbd flaky?
- print kbd layout, add wozmon keys (0-9A-F : . R bksp esc cr); default to straight wozmon pad vs hex input?
- too many blank lines in wozmon?
- if lcd wrap to top, cls?

- try beethoven notes

Notes
---

fill c47f/2 ea
fill c02d/1 00

g c000  ; check breaks

ab c536
ab c545

g c000
registers x=0
