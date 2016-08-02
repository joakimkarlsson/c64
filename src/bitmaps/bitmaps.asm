#import "macros.asm"

.var vic_bank=1
.var vic_base=$4000*vic_bank    // A VIC-II bank indicates a 16K region
.var screen_memory=$0000 + vic_base
.var bitmap_address=$2000 + vic_base

BasicUpstart2(start)
start:
    SwitchVICBank(vic_bank)
    SetHiresBitmapMode()
    SetScreenMemory(screen_memory - vic_base)
    SetBitmapAddress(bitmap_address - vic_base)

    FillBitmap(bitmap_address, $0f)

    // Set colors
    FillScreenMemory(screen_memory, $32)


    rts

.print "vic_bank: " + toHexString(vic_bank)
.print "vic_base: " + toHexString(vic_base)
.print "screen_memory: " + toHexString(screen_memory)
.print "bitmap_address: " + toHexString(bitmap_address)
