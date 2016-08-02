BasicUpstart2(start)

start:
    sei

    //
    // Turn off interrupts from the two CIA chips.
    // Used by the kernal to flash cursor and scan 
    // keyboard.
    //
    lda #$7f
    sta $dc0d //Turn off CIA 1 interrupts
    sta $dd0d //Turn off CIA 2 interrupts

    //
    // Reading these registers we ack any pending CIA interrupts.
    // Otherwise, we might get a trailing interrupt after setup.
    //
    lda $dc0d
    lda $dd0d

    //
    // Tell VIC-II to start generating raster interrupts
    //
    lda #$01
    sta $d01a //Turn on raster interrupts

    //
    // Bank out BASIC and KERNAL.
    // This causes the CPU to see RAM instead of KERNAL and
    // BASIC ROM at $E000-$FFFF and $A000-$BFFF respectively.
    //
    // This causes the CPU to see RAM everywhere except for
    // $D000-$E000, where the VIC-II, SID, CIA's etc are located.
    //
    lda #$35
    sta $01

    //
    // Create a nop, irq handler for NMI that gets called whenever
    // RESTORE is pressed or similar.
    //
    // We're putting our irq handler directly in the vector that
    // usually points to the kernal's NMI handler since we have
    // kernal banked out.
    //
    lda #<nmi_nop
    sta $fffa
    lda #>nmi_nop
    sta $fffb

    //
    // Force an NMI by setting up a timer. This will cause an NMI, that won't
    // be acked. Any subsequent NMI's from RESTORE will be essentially
    // disabled.
    lda #$00
    sta $dd0e       // Stop timer A
    sta $dd04       // Set timer A to 0, NMI will occure immediately after start
    sta $dd0e

    lda #$81
    sta $dd0d       // Set timer A as source for NMI

    lda #$01
    sta $dd0e       // Start timer A -> NMI

    // TODO: Not sure if this triggers an immediate NMI that won't be acked,
    // or if an NMI will be triggered as soon as cli is called.

    //
    // Call mainirq when raster reaches line $35. If we're stabilizing using
    // double irq handlers, the actual code will be executed at line $36.
    //
    RasterInterrupt(mainirq, $35)
    cli

    jmp *

nmi_nop:
    //
    // This is the irq handler for the NMI. Just returns without acknowledge.
    // This prevents subsequent NMI's from interfering.
    //
    rti

mainirq:
    //
    // Since the kernal is switced off, we need to push the
    // values of the registers to the stack ourselves so
    // that they're restored when we're done.
    //
    // If we don't do anything advanced like calling cli to let another
    // irq occur, we don't need to use the stack.
    //
    // In that case it's faster to:
    //
    // sta restorea+1
    // stx restorex+1
    // sty restorey+1
    //
    // ... do stuff ...
    //
    // lda #$ff
    // sta $d019
    //
    // restorea: lda #$00
    // restorex: ldx #$00
    // restorey: ldy #$00
    // rti
    //
    pha
    txa
    pha
    tya
    pha

    //
    // Stabilize raster using double irq's.
    StabilizeRaster()

    inc $d020

    //
    // Reset the raster interrupt since the stabilizing registered another
    // function. 
    // We can also register another irq for something further down the screen
    // or at next frame.
    //
    RasterInterrupt(mainirq, $35)

    //
    // Restore the interrupt condition so that we can get
    // another one.
    //
    lda #$ff
    sta $d019   //ACK interrupt so it can be called again

    //
    // Restore the values of the registers and return.
    //
    pla
    tay
    pla
    tax
    pla
    rti

//
// Stabilize the IRQ so that the handler function is called exactly when the
// line scan begins.
//
// If an interrupt is registered when the raster reaches a line, an IRQ is
// triggered on the first cycle of that line scan. This means that the code we
// want to esecute at that line will not be called immediately. There's quite
// a lot of housekeeping that needs to be done before we get called.
//
// What's worse is that it isn't deterministic how many cycles will pass from
// when the raster starts at the current line untill we get the call.
//
// First, the CPU needs to finish its current operation. This can mean a delay
// of 0 to 7 cycles, depending on what operation is currently running.
//
// Then we spend 7+13 cycles invoking the interrupt handler and pushing stuff to
// the stack.
//
// So all in all we're being called between 20 and 27 cycles after the current line
// scan begins.
//
// This macro removes that uncertainty by registering a new irq on the next line,
// after that second interrupt is registered, it calls nop's until a line change
// should occur.
//
// Now we know that the cycle type of the current op is only one cycle, so the only
// uncertainty left is wether ran one extra cycle or not. We can determine that by
// loading and comparing the current raster line ($d012) with itself. If they're not
// equal, we switched raster line between the load and the compare -> we're ready to go.
//
// If they're equal, we haven't switched yet but we know we'll switch at the next cycle.
// So we just wait an extra cycle in this case.
//
.macro StabilizeRaster() {
    //
    // Register a new irq handler for the next line.
    //
    lda #<stabilizedirq
    sta $fffe
    lda #>stabilizedirq
    sta $ffff
    inc $d012

    //
    // ACK the current IRQ
    //
    lda #$ff
    sta $d019

    // Save the old stack pointer so we can just restore the stack as it was
    // before the stabilizing got in the way.
    tsx

    // Enable interrupts and call nop's until the end of the current line
    // should be reached
    cli

    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    // Add one more nop if NTSC

    // Here's or second irq handler
stabilizedirq:

    // Reset the SP so it looks like the extra irq stuff never happened
    txs

    //
    // Wait for line to finish.
    //

    // PAL-63  // NTSC-64    // NTSC-65
    //---------//------------//-----------
    ldx #$08   // ldx #$08   // ldx #$09
    dex        // dex        // dex
    bne *-1    // bne *-1    // bne *-1
    bit $00    // nop
               // nop

    //
    // Check at exactly what point we go to the next line
    //
    lda $d012
    cmp $d012
    beq *+2 // If we haven't changed line yet, wait an extra cycle.

    // Here our real logic can start running.
}

.macro RasterInterrupt(address, line) {
    //
    // Address to jump to when raster reaches line.
    // Since we have the kernal banked out, we set the address
    // of our interrupt routine directly in $fffe-$ffff instead
    // of in $0314-$0315.
    //
    // If the kernal isn't banked out, it will push registers on the stack,
    // check if the interrupt is caused by a brk instruction, and eventually
    // call the interrupt function stored in the $0134-$0315 vector.
    //
    lda #<address
    sta $fffe       // Instead of $0314 as we have no kernal rom
    lda #>address
    sta $ffff       // Instead of $0315 as we have no kernal rom

    //
    // Configure line to trigger interrupt at
    //
    /* .if(line > $ff) { */
        lda $d011
        ora #%10000000
        sta $d011

        lda #>line
        sta $d012
    /* } else { */
    /*     lda $d011 */
    /*     and #%01111111 */
    /*     sta $d011 */
    /*  */
    /*     lda #line */
    /*     sta $d012 */
    /* } */
}
