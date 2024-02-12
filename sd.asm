/*
exchange data with SD card by pairing a '595 shift register with the VIA one.

trigger an exchange by writing to VIA SR using shift-out under PHI2
this uses CB1 as clock (@ half the PHI2 rate) and CB2 as data.
The SD card wants SPI mode 0 where the clock has a rising edge after the data is ready.
We use a D-flip flop to invert and delay the CB1 clock by half a PHI2 cycle,
see http://forum.6502.org/viewtopic.php?t=1674

*/