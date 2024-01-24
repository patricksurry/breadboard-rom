import re

# generate a simple binary coding for morse letters
# each letter gets a 2 bit length (1-4) and a 4 bit representation (. is 0, - is 1) starting from msb

# 2 1bit + 4 2bit + 8 3bit + 12 4bit (missing ..-- .-.- ---. ----)
# nice dichotomic search table picture at https://en.wikipedia.org/wiki/Morse_code
# where all chars at most 6 chars (can elide any digraph with two three symbol letters)
raw = """
A .-
B -...
C -.-.
D -..
E .
F ..-.
G --.
H ....
I ..
J .---
K -.-
L .-..
M --
N -.
O ---
P .--.
Q --.-
R .-.
S ...
T -
U ..-
V ...-
W .--
X -..-
Y -.--
Z --..
0 -----
1 .----
2 ..---
3 ...--
4 ....-
5 .....
6 -....
7 --...
8 ---..
9 ----.
. .-.-.-
, --..--
: ---...
? ..--..
' .----.
- -....-
"""

def morsebits(s, n=4):
    bit = 1 << n
    v = 0
    for c in s:
        bit >>= 1
        if c == '-':
            v += bit
    return v

def morseprefix(s):
    n = len(s)
    v = morsebits(s, 8)
    bits = f"{v:08b}"
    bits = '%' + '000000'[:7-n] + '1_' + bits[:n]
    return bits

def bytedata(xs):
    return ', '.join(f"%{x>>4:04b}_{x&0xf:04b}" for x in xs)

codes = dict(
    line.split()
    for line in raw.strip().splitlines()
)
vs = list(map(morsebits, codes.values()))
ns = list(map(len, codes.values()))

print(vs)
print(ns)

vbs = [vs[i] << 4 | vs[i+1] for i in range(0, 26, 2)]
n1s = [n-1 for n in ns] + [0, 0]
nbs = [n1s[i] << 6 | n1s[i+1] << 4 | n1s[i+2] << 2 | n1s[i+3] for i in range(0, 26, 4)]
print(bytedata(vbs))
print(bytedata(nbs))

print('\n'.join(sorted([f'{codes[k]:>6s} {k}' for (i, k) in enumerate(codes)])))

for k, code in codes.items():
    print(f"    .byte {morseprefix(code)}    ; {k} {code} ")



"""
/*
    a different compact storage for morse letters which are at most four symbols.
    this means we can store one letter per nibble (two letters per byte)
    plus a separate lookup with two bits per character of length data storing length-1,
    which we can pack four per byte

    this gives 13+6.5 = 20 bytes for the letters, and numbers can be constructed
    but it's not worth the additional compute space/time...

    ; morse A-Z encoded in 20 bytes
morse_az_sym:
    ; each letter encoded in four bits starting with msb, 0=dit(.), 1=dah(-)
    ; all 1, 2 and 3 bit patterns appear (2+4+8) plus 12 4 bit patterns (missing ..-- .-.- ---. ----)
    ;     A .- B -...    C -.-. D -..   E . F ..-.     G --. H ....   I .. J .---    K -.- L .-..   M -- N -.
    .byte %0100_1000,    %1010_1000,    %0000_0010,    %1100_0000,    %0000_0111,    %1010_0100,    %1100_1000
    ;     O --- P .--.   Q --.- R .-.   S ... T -      U ..- V ...-   W .-- X -..-   Y -.-- Z --..
    .byte %1110_0110,    %1101_0100,    %0000_1000,    %0010_0001,    %0110_1001,    %1011_1100
morse_az_len:
    ; number of symbols per letter minus 1 encoded in two bits (00=1, 01=2, 10=3, 11=4)
    ;      A  B  C  D    E  F  G  H    I  J  K  L    M  N  O  P    Q  R  S  T    U  V  W  X    Y  Z
    .byte %01_11_11_10, %00_11_10_11, %01_11_10_11, %01_01_10_11, %11_10_10_00, %10_11_10_11, %11_11_0000

    code to compute 5-bit number patterns, but uses more storage than a lookup...

        tay
        ldx #1          ; flag to flip bits for digit >=5
        sec
        sbc #5          ; 0-9 is ----- .---- ..--- ...-- ....- / ..... -.... --... ---.. ----.
        bpl ge5
        tya             ; already 0-4
        dex             ; X=0
ge5:    tay             ; Y is 0-4, X=0 for 0-4, 1 for 5-9
        lda #%1111_1000
        clc
roll:   dey             ; clear Y msb bits in A
        bmi mask
        ror             ; -----... => .-----.. C=. etc  incoming bit is 0 for up to 4 shifts
        bra roll

mask:   txy
        beq lt5
        eor #$ff        ; flip symbols for 5-9

lt5:    ldy #4          ; all digit chrs have 5 symbols

*/
"""