; Fat Chip 64 - tables and text

; keyboard: column select values (CIA1 port A, one bit low)
colSelect:  .byte $FE,$FD,$FB,$F7,$EF,$DF,$BF,$7F
rowBit:     .byte $01,$02,$04,$08,$10,$20,$40,$80

; key code for each matrix position, index = column*8 + row.
; 0-22 = Incredible Musical Keyboard overlay notes (C..A# two octaves; the
; top B is RESTORE, which isn't in the matrix: see notes/keyboard-overlay.md)
N_ equ K_NONE
keymap:
	; col 0: INST/DEL RETURN CRSR-R F7 F1 F3 F5 CRSR-D
	.byte K_INSTDEL,K_RETURN,K_CRSR_RIGHT,K_F7,K_F1,K_F3,K_F5,K_CRSR_DOWN
	; col 1: 3 W A 4 Z S E LSHIFT
	.byte 3,2,N_,N_,N_,N_,4,K_LSHIFT
	; col 2: 5 R D 6 C F T X
	.byte 6,5,N_,8,N_,N_,7,N_
	; col 3: 7 Y G 8 B H U V
	.byte 10,9,N_,N_,N_,N_,11,N_
	; col 4: 9 I J 0 M K O N
	.byte 13,12,N_,15,K_M,N_,14,N_
	; col 5: + P L - . : @ ,
	.byte N_,16,N_,18,N_,N_,17,N_
	; col 6: pound * ; CLR/HOME RSHIFT = up-arrow /
	.byte 20,19,N_,22,K_RSHIFT,K_EQUALS,21,N_
	; col 7: 1 <- CTRL 2 SPACE C= Q RUN/STOP
	.byte N_,N_,K_CTRL,1,K_SPACE,N_,0,N_

; SID voice register offsets
sidOfs:     .byte 0,7,14

; voice pool (see voices.asm)
vDev:       .byte DEV_SID,DEV_GB,DEV_NES, DEV_SID,DEV_GB,DEV_NES, DEV_SID,DEV_GB,DEV_NES
vIdx:       .byte 0,0,0, 1,1,1, 2,2,2      ; SID voice / channel offset from the base
vBass:      .byte 0,0,0, 0,0,0, 0,1,1      ; GB wave and NES triangle: bass, octave down
vNameLo:    .byte <vn0,<vn1,<vn2,<vn3,<vn4,<vn5,<vn6,<vn7,<vn8
vNameHi:    .byte >vn0,>vn1,>vn2,>vn3,>vn4,>vn5,>vn6,>vn7,>vn8
vn0:        .byte "SID 1",0
vn1:        .byte "GB PULSE 1",0
vn2:        .byte "NES PULSE 1",0
vn3:        .byte "SID 2",0
vn4:        .byte "GB PULSE 2",0
vn5:        .byte "NES PULSE 2",0
vn6:        .byte "SID 3",0
vn7:        .byte "GB WAVE (BASS)",0
vn8:        .byte "NES TRI (BASS)",0

noteNames:  .byte "C C#D D#E F F#G G#A A#B "

txtHeader:  .byte " FAT CHIP 64                      V0.02 ",0
txtDevices: .byte "DEVICES       SHIFT+F1/F3/F5: ON/OFF",0
txtSid:     .byte "SID",0
txtGb:      .byte "GAME BOY",0
txtNes:     .byte "MIDINES",0
txtOn:      .byte "ON ",0
txtOff:     .byte "OFF",0
txtMuted:   .byte "MUTED (M)",0
txtBlank9:  .byte "         ",0
txtPanic:   .byte "SHIFT+F7 PANIC   CTRL+F3/F5 CHANNELS",0
txtOverlap: .byte "!! GAME BOY AND NES CHANNELS OVERLAP !!",0
txtBlank:   .byte "                                       ",0
txtVoices:  .byte "VOICES",0
txtHeld:    .byte "HELD                                   ",0
txtOctave:  .byte "F1-F7 OCTAVE        = LATCH",0
txtRestore: .byte "RESTORE  1 TAP        2 TAPS",0
txtSent:    .byte "MIDI OUT:       MESSAGES",0
txtMode:    .byte "MODE: POLY SYNTH (SMART STACKING)",0
