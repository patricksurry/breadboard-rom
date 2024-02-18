Development
---

    make


    micromamba activate eeprom-writer

    python ../eeprom-writer/zwrite.py rom.bin

For debugging, set PYMON=1 in rom.asm, rebuild

    py65mon -m 65c02 -l rom.bin -a 8000 -b rom.sym

    g .hello


    sudo dd bs=512 count=1 if=/dev/disk2 | hexdump -C

Creating an SD image

    # create a 32Mb image file

    % prodos bigvol.po create --name DEMOVOL
    % prodos bigvol.po import hhg.txt README
    % prodos bigvol.po ls

    # find the device name, e.g. /dev/disk2 (external, physical)
    diskutil list
    diskutil unmountDisk /dev/disk2s1       ; unmount the volume (disk2s1)
    # ... Unmount of all volumes on disk2 was successful ...

    # copy to the raw device (prefix 'r'): BE CAREFUL to target the right volume
    sudo dd if=bigvol.po of=/dev/rdisk2 bs=1m
    # ... 31+1 records in
    # ... 31+1 records out
    # ... 33553920 bytes transferred in 1.680861 secs (19962341 bytes/sec)

    # check the device (README file data starts in block 23)
    sudo dd if=/dev/disk2 count=4 | hexdump -C

00000000  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
00000400  00 00 03 00 f7 44 45 4d  4f 56 4f 4c 00 00 00 00  |.....DEMOVOL....|
00000410  00 00 00 00 00 00 00 00  00 00 00 00 51 30 0e 0f  |............Q0..|
00000420  00 00 e3 27 0d 01 00 06  00 ff ff 26 52 45 41 44  |...'.......&READ|
00000430  4d 45 00 00 00 00 00 00  00 00 00 ff 16 00 03 00  |ME..............|
00000440  7d 03 00 51 30 0e 0f 00  00 e3 00 00 51 30 0e 0f  |}..Q0.......Q0..|
00000450  02 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
00000460  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
00000600  02 00 04 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
00000610  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
00000800


TODO
---

- kbd flaky? -pulldowns
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
