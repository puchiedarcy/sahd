PPU_CTRL_ADDR   = $2000
PPU_MASK_ADDR   = $2001
PPU_STATUS_ADDR = $2002
PPU_OAM_ADDR    = $2003
PPU_SCROLL_ADDR = $2005
PPU_ADDR        = $2006
PPU_DATA        = $2007
PPU_OAM_DMA     = $4014

PPU_CTRL_ENABLE_NMI         = %10000000
PPU_CTRL_SPRITE_8x16        = %00100000
PPU_CTRL_BG_PATTERN_1       = %00010000
PPU_CTRL_SP_PATTERN_1       = %00001000
PPU_CTRL_INC_32             = %00000100
PPU_CTRL_BASE_NAMETABLE_1   = %00000001
PPU_CTRL_BASE_NAMETABLE_2   = %00000010
PPU_CTRL_BASE_NAMETABLE_3   = %00000011

PPU_MASK_EMP_BLUE           = %10000000
PPU_MASK_EMP_GREEN          = %01000000
PPU_MASK_EMP_RED            = %00100000
PPU_MASK_SHOW_SPRITES       = %00010000
PPU_MASK_SHOW_BACKGROUND    = %00001000
PPU_MASK_SHOW_LEFT8_SP      = %00000100
PPU_MASK_SHOW_LEFT8_BG      = %00000010
PPU_MASK_GRAYSCALE          = %00000001

APU_DMC_ADDR    = $4010
APU_STATUS_ADDR = $4015
APU_FRAME_ADDR  = $4017

NUM_16KB_PRG    = 2 ; Represents CPU memory $8000-$BFFF and $C000-$FFFF.
NUM_8KB_CHR     = 1 ; Represents PPU memory $0000-$1FFF.
MAPPER = 0

.ZEROPAGE
frameCount: .res 1
mainLock: .res 1
decimalNumber: .res 3
binaryNumber: .res 1

.segment "OAM"
oam: .res 256 ; Dedicated space for sprites.

.BSS

.CODE
irq:
    rti

reset:
    sei ; Disable interrupts.
    cld ; Disable decimal mode.

    ldx #%01000000
    stx APU_FRAME_ADDR ; Disable APU IRQ.

    ldx #$FF
    txs ; Initialize stack pointer to grow down from $01FF.
    
    inx ; Sets X to 0.
    stx PPU_CTRL_ADDR   ; Disable NMI.
    stx PPU_MASK_ADDR   ; Disable rendering.
    stx APU_STATUS_ADDR ; Disable APU sound.
    stx APU_DMC_ADDR    ; Disable DMC IRQ.
    
    bit PPU_STATUS_ADDR ; Clear VBlank across reset.

    : ; Wait for VBLank 1 as PPU initializes.
        bit PPU_STATUS_ADDR ; Bit 7 copied to N.
        bpl :- ; Branch on N=0. Thus, loop until N=1 meaning VBlank happened.

    ; In the meantime...
    ; Clear all RAM to 0.
    txa
    : ; X=0. Loop until X overflows back to 0.
        sta $0000, x
        sta $0100, x
        sta $0200, x
        sta $0300, x
        sta $0400, x
        sta $0500, x
        sta $0600, x
        sta $0700, x
        inx
        bne :- ; Branch while X!=0.
        
    ; Place all sprites offscreen at Y=255.
    lda #255
    ldx #0
    :
        sta oam, x ; Byte 0 of OAM is Y coordinate.
        inx ; Skip byte 1, tile number.
        inx ; Skip byte 2, attributes.
        inx ; Skip byte 3, X coordinate.
        inx ; Aligned to Byte 0 of next sprite.
        bne :- ; Branch while X!=0.

    : ; Wait for VBLank 2 as PPU initialization finalizes.
        bit PPU_STATUS_ADDR
        bpl :-

    lda #(PPU_CTRL_ENABLE_NMI)
    sta PPU_CTRL_ADDR

    lda #(PPU_MASK_SHOW_BACKGROUND | PPU_MASK_SHOW_LEFT8_BG | PPU_MASK_SHOW_SPRITES | PPU_MASK_SHOW_LEFT8_SP)
    sta PPU_MASK_ADDR

    lda #$44
    sta oam
    sta oam + 3
    lda #4
    sta oam + 1
    sta oam + 2

    lda #$4C
    sta oam + 4
    sta oam + 7
    lda #5
    sta oam + 5
    sta oam + 6

main:
    lda #1
    cmp mainLock
    beq main
    sta mainLock

    lda frameCount
    sta binaryNumber

    lda #0
    sta decimalNumber
    sta decimalNumber+1
    sta decimalNumber+2

startDoubleDabble:
.repeat 8
    clc
    rol binaryNumber
    rol decimalNumber+2
    rol decimalNumber+1
    rol decimalNumber

    lda decimalNumber+2
    cmp #10
    bcc :+
        sbc #10
        sta decimalNumber+2
        lda decimalNumber+1
        clc
        adc #1
        sta decimalNumber+1
    :

    lda decimalNumber+1
    cmp #10
    bcc :+
        sbc #10
        sta decimalNumber+1
        lda decimalNumber
        clc
        adc #1
        sta decimalNumber
    :
.endrepeat

    jmp main
nmi:
    pha
    txa
    pha
    tya
    pha

    lda #0
    sta mainLock

    lda #$23
    sta PPU_ADDR
    lda #$42
    sta PPU_ADDR

    .repeat 3, i
        lda decimalNumber+i
        sta PPU_DATA
    .endrepeat

    inc frameCount

    ldx #0
    stx PPU_OAM_ADDR
    lda #>oam
    sta PPU_OAM_DMA

    bit PPU_STATUS_ADDR
    lda #$3F
    sta PPU_ADDR
    lda #$00
    sta PPU_ADDR

    ldx #0
    :
        lda palette, X
        sta PPU_DATA
        inx
        cpx #32
        bcc :-

    bit PPU_STATUS_ADDR
    lda #0
    sta PPU_SCROLL_ADDR
    sta PPU_SCROLL_ADDR
    lda #(PPU_CTRL_ENABLE_NMI)
    sta PPU_CTRL_ADDR

    pla
    tay
    pla
    tax
    pla

    rti

.RODATA
palette:
    .incbin "sahd-bg.pal"
    .incbin "sahd-sp.pal"

.segment "HEADER"

.byte "NES", $1A
.byte NUM_16KB_PRG
.byte NUM_8KB_CHR
.byte MAPPER ; lo mapper / mirror / battery
.byte MAPPER ; hi mapper / alt platforms
.byte "PUCHIE_D"

.segment "VECTORS" 
vectors: ; CPU required interrupt vectors.
.word nmi
.word reset
.word irq

.segment "TILES"
.incbin "sahd.chr" ; Load pattern tables.