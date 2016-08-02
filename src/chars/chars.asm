//
// This demonstrates character graphics, how to load custom characters,
// and how to use the different color modes available.
//
.var characters = LoadBinary("airwolf_ii.64c", BF_C64FILE)
.var multicharacters = LoadBinary("lost_ninja_multi.64c", BF_C64FILE)

BasicUpstart2(start)

start:
    SwitchBank($02)                     // Switch to bank 1 (Base address: $4000)
    SetScreen($00)                      // Screen mem at BANK+0 ($4000)
    SetCharacterMem($02)                // Characters at BANK+$800 = $4800

    //
    // Standard character mode with custom characters.
    //
    ClearScreen($4000)                  // Clear screen
    SetAllCharactersColors(YELLOW)
    Print(message, ($4000 + 10 * 40))
    WaitForKey($ef)


    //
    // Mutli color mode with custom characters.
    //
    SetMultiColor(BLACK, BLUE, CYAN)
    SetAllCharactersColors(8 + WHITE)
    SetCharacterMem($04)                // Characters at BANK+$1000 = $5000
                                        // Use multi color font
    Print(message2, ($4000 + 10 * 40))

    WaitForKey($ef)

    ResetMultiColor()

    //
    // Extended background color mode
    //
    SetCharacterMem($02)
    SetExtendedBackgroundColorMode(BLACK, DARK_GRAY, GRAY, LIGHT_GRAY)
    SetAllCharactersColors(BLUE)
    PrintWithExtendedBackgroundColors(message3, message3colors, ($4000 + 10 * 40))

    WaitForKey($ef)

    ResetExtendedBackgroundColorMode()

    rts

message:
    .text "            custom characters           "
    .byte $00

message2:
    .text "          multicolor characters         "
    .byte $00

message3:
    .text "      extended background color mode    "
    .byte $00

//
// These values are or:ed with the caracters to print in 
// order to set alternatice background colors in extended
// background color mode.
//
message3colors:
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $40, $40
    .byte $40, $80, $80, $80, $80, $80, $80, $c0, $c0, $c0
    .byte $c0, $c0, $c0, $80, $80, $80, $80, $80, $80, $40
    .byte $40, $40, $00, $00, $00, $00, $00, $00, $00, $00

*=$4800;  .fill characters.getSize(), characters.get(i)
*=$5000;  .fill multicharacters.getSize(), multicharacters.get(i)
//
// Switch bank in VIC-II
//
// The VIC-II chip can only access 16K bytes at a time. In order to
// have it access all of the 64K available, we have to tell it to look
// at one of four banks.
//
// This is controller by bits 0 and 1 in $dd00 (PORT A of CIA #2).
//
//  +------+-------+----------+-------------------------------------+
//  | BITS |  BANK | STARTING |  VIC-II CHIP RANGE                  |
//  |      |       | LOCATION |                                     |
//  +------+-------+----------+-------------------------------------+
//  |  00  |   3   |   49152  | ($C000-$FFFF)*                      |
//  |  01  |   2   |   32768  | ($8000-$BFFF)                       |
//  |  10  |   1   |   16384  | ($4000-$7FFF)*                      |
//  |  11  |   0   |       0  | ($0000-$3FFF) (DEFAULT VALUE)       |
//  +------+-------+----------+-------------------------------------+

.macro SwitchBank(bank_bits) {
    //
    // Set Data Direction for CIA #2, Port A to output
    //
    lda $dd02
    and #%11111100  // Mask the bits we're interested in.
    ora #$03        // Set bits 0 and 1.
    sta $dd02

    lda $dd00
    and #%11111100
    ora #bank_bits
    sta $dd00
}

//
// Switch location of screen memory.
// 
// The most significant nibble of $D018 selects where the screen is
// located in the current VIC-II bank.
//
//  +------------+-----------------------------+
//  |            |         LOCATION*           |
//  |    BITS    +---------+-------------------+
//  |            | DECIMAL |        HEX        |
//  +------------+---------+-------------------+
//  |  0000XXXX  |      0  |  $0000            |
//  |  0001XXXX  |   1024  |  $0400 (DEFAULT)  |
//  |  0010XXXX  |   2048  |  $0800            |
//  |  0011XXXX  |   3072  |  $0C00            |
//  |  0100XXXX  |   4096  |  $1000            |
//  |  0101XXXX  |   5120  |  $1400            |
//  |  0110XXXX  |   6144  |  $1800            |
//  |  0111XXXX  |   7168  |  $1C00            |
//  |  1000XXXX  |   8192  |  $2000            |
//  |  1001XXXX  |   9216  |  $2400            |
//  |  1010XXXX  |  10240  |  $2800            |
//  |  1011XXXX  |  11264  |  $2C00            |
//  |  1100XXXX  |  12288  |  $3000            |
//  |  1101XXXX  |  13312  |  $3400            |
//  |  1110XXXX  |  14336  |  $3800            |
//  |  1111XXXX  |  15360  |  $3C00            |
//  +------------+---------+-------------------+
//
.macro SetScreen(screen_bits) {
    lda $d018
    and #%00001111
    ora #screen_bits
    sta $d018
}

//  +----------+------------------------------------------------------+
//  |          |            LOCATION OF CHARACTER MEMORY*             |
//  |   BITS   +-------+----------------------------------------------+
//  |          |DECIMAL|         HEX                                  |
//  +----------+-------+----------------------------------------------+
//  | XXXX000X |     0 | $0000-$07FF                                  |
//  | XXXX001X |  2048 | $0800-$0FFF                                  |
//  | XXXX010X |  4096 | $1000-$17FF ROM IMAGE in BANK 0 & 2 (default)|
//  | XXXX011X |  6144 | $1800-$1FFF ROM IMAGE in BANK 0 & 2          |
//  | XXXX100X |  8192 | $2000-$27FF                                  |
//  | XXXX101X | 10240 | $2800-$2FFF                                  |
//  | XXXX110X | 12288 | $3000-$37FF                                  |
//  | XXXX111X | 14336 | $3800-$3FFF                                  |
//  +----------+-------+----------------------------------------------+
.macro SetCharacterMem(location_bits) {
    lda $d018
    and #%11110000
    ora #location_bits
    sta $d018
}

.macro SetMultiColor(back_0, back_1, back_2) {
    lda $d016
    ora #%00010000
    sta $d016

    lda #back_0
    sta $d021
    lda #back_1
    sta $d022
    lda #back_2
    sta $d023
}

.macro ResetMultiColor() {
    lda $d016
    and #%11101111
    sta $d016
}

.macro SetExtendedBackgroundColorMode(back_0, back_1, back_2, back_3) {
    lda $d011
    ora #%01000000
    sta $d011

    lda #back_0
    sta $d021
    lda #back_1
    sta $d022
    lda #back_2
    sta $d023
    lda #back_3
    sta $d024
}

.macro ResetExtendedBackgroundColorMode() {
    lda $d011
    and #%10111111
    sta $d011
}


.macro SetAllCharactersColors(color) {
    ldx #$00
    lda #color    // A value from 8-15 indicates multicolor value

loop:
    sta $d800,x
    sta $d900,x
    sta $da00,x
    sta $d900,x
    dex
    bne loop
}

.macro Print(message, target) {
    ldx #$00

loop:
    lda message,x
    beq end

    sta target,x
    inx
    jmp loop
end:
    nop
}

//
// In extended background color mode, only the 64 first chars
// can be printed. Bits 7 and 6 are reserved to indicate an
// alternative background color according to the following table:
//
//  +------------------------+---------------------------+
//  |     CHARACTER CODE     | BACKGROUND COLOR REGISTER |
//  +------------------------+---------------------------+
//  |  RANGE   BIT 7   BIT 6 |  NUMBER       ADDRESS     |
//  +------------------------+---------------------------+
//  |   0- 63   0       0    |    0       53281 ($D021)  |
//  |  64-127   0       1    |    1       53282 ($D022)  |
//  | 128-191   1       0    |    2       53283 ($D023)  |
//  | 192-255   1       1    |    3       53284 ($D024)  |
//  +------------------------+---------------------------+
.macro PrintWithExtendedBackgroundColors(message, colors, target) {
    ldx #$00

loop:
    lda message,x
    beq end

    ora colors,x

    sta target,x
    inx
    jmp loop

end:
    nop  // Not necessary?
}

//
// Clear screen in character mode.
// Fills screen memory with spaces.
//
.macro ClearScreen(screen_addr) {
clear_screen:
    lda #$20
    ldx #$00

loop:
    sta screen_addr,x
    sta (screen_addr + $100),x
    sta (screen_addr + $200),x
    sta (screen_addr + $300),x
    dex
    bne loop
}

.macro WaitForKey(key) {
checkdown:
    lda $dc01
    cmp #key
    bne checkdown

checkup:
    lda $dc01
    cmp #key
    beq checkup
}
