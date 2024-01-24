Development
---

    py65mon -m 65c02 -l rom.bin -a 8000

    micromamba activate eeprom-writer

    python ../eeprom-writer/zwrite.py rom.bin

TODO
---

- kbd flaky?
- print kbd layout, add wozmon keys; default to straight wozmon pad vs hex input?
- can't share PB7, move lcd to port-a or use 4-bit mode
- too many blank lines in wozmon
- if wrap to top, cls?

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
