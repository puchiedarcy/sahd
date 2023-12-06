PPU_CTRL_ADDR   = $2000
PPU_MASK_ADDR   = $2001
PPU_STATUS_ADDR = $2002
PPU_OAM_ADDR    = $2003
PPU_SCROLL_ADDR = $2005
PPU_ADDR        = $2006
PPU_DATA        = $2007
PPU_OAM_DMA     = $4014

PPU_CTRL_ENABLE_NMI   = %10000000
PPU_CTRL_SP_PATTERN_1 = %00001000
PPU_CTRL_INC_32       = %00000100

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

NUM_16KB_PRG = 2
NUM_8KB_CHR = 1
MAPPER = 0

.segment "HEADER"

.byte "NES", $1A
.byte NUM_16KB_PRG
.byte NUM_8KB_CHR
.byte MAPPER ; lo mapper / mirror / battery
.byte MAPPER ; hi mapper / alt platforms
.byte "PUCHIE_D"

.segment "OAM"
oam: .res 256

.segment "TILES"
.incbin "sahd.chr"

.segment "VECTORS"
vectors:
.word nmi
.word reset
.word irq

.ZEROPAGE
frameCount: .res 1

.CODE
irq:
    rti

reset:
    sei
    cld

    ldx #$40
    stx APU_FRAME_ADDR ; disable APU IRQ

    ldx #$FF
    txs       ; initialize stack
    
    inx
    stx PPU_CTRL_ADDR   ; disable NMI
    stx PPU_MASK_ADDR   ; disable rendering
    stx APU_STATUS_ADDR ; disable APU sound
    stx APU_DMC_ADDR    ; disable DMC IRQ
    
    bit PPU_STATUS_ADDR ; clear latch to ensure first vblank

    :
        bit PPU_STATUS_ADDR
        bpl :-

    ; clear all RAM to 0
    txa
    :
        sta $0000, x
        sta $0100, x
        sta $0200, x
        sta $0300, x
        sta $0400, x
        sta $0500, x
        sta $0600, x
        sta $0700, x
        inx
        bne :-
        
    ; place all sprites offscreen at Y=255
    lda #255
    ldx #0
    :
        sta oam, x
        inx
        inx
        inx
        inx
        bne :-

    :
        bit PPU_STATUS_ADDR
        bpl :-

    ; NES is initialized, ready to begin!
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
    jmp main
nmi:
    pha
    txa
    pha
    tya
    pha

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