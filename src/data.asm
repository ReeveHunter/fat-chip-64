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
	.byte 3,2,K_A,N_,K_Z,K_S,4,K_LSHIFT
	; col 2: 5 R D 6 C F T X
	.byte 6,5,K_D,8,N_,K_F,7,K_X
	; col 3: 7 Y G 8 B H U V
	.byte 10,9,K_G,N_,K_B,K_H,11,K_V
	; col 4: 9 I J 0 M K O N
	.byte 13,12,K_J,15,K_M,K_K,14,K_N
	; col 5: + P L - . : @ ,
	.byte N_,16,K_L,18,N_,N_,17,N_
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

txtHeader:  .byte " FAT CHIP 64                      V0.06 ",0
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
txtOctave:  .byte "F1-F7 OCTAVE       = LATCH",0
txtNNew:    .byte "N NEW ",0
txtNNext:   .byte "N NEXT",0
txtLatchLo: .byte <txtLOff,<txtLSmart,<txtLHold,<txtLAdd
txtLatchHi: .byte >txtLOff,>txtLSmart,>txtLHold,>txtLAdd
txtLSmart:  .byte "SMART",0
txtLAdd:    .byte "ADD  ",0
txtArp:     .byte "A ARP         S        D        F",0
txtMs:      .byte "MS  ",0
arpModeLo:  .byte <tAOff,<tAUni,<tASpk
arpModeHi:  .byte >tAOff,>tAUni,>tASpk
tAOff:      .byte "OFF    ",0
tAUni:      .byte "UNISON ",0
tASpk:      .byte "SPARKLE",0
patTxtLo:   .byte <tPUp,<tPDn,<tPUd,<tPRn,<tPPl
patTxtHi:   .byte >tPUp,>tPDn,>tPUd,>tPRn,>tPPl
tPUp:       .byte "UP    ",0
tPDn:       .byte "DOWN  ",0
tPUd:       .byte "UPDOWN",0
tPRn:       .byte "RANDOM",0
tPPl:       .byte "PLAYED",0
lenTxtLo:   .byte <tL4,<tL8,<tL8t,<tL16,<tL32
lenTxtHi:   .byte >tL4,>tL8,>tL8t,>tL16,>tL32
tL4:        .byte "1/4   ",0
tL8:        .byte "1/8   ",0
tL8t:       .byte "1/8T  ",0
tL16:       .byte "1/16  ",0
tL32:       .byte "1/32  ",0
lenDiv:     .byte 1,2,3,4,8
patLo:      .byte <PatUp,<PatDown,<PatUpDown,<PatRandom,<PatUp
patHi:      .byte >PatUp,>PatDown,>PatUpDown,>PatRandom,>PatUp
; FREE speeds (ms per step), H slower / J faster
freeLo:     .byte <30,<40,<50,<60,<75,<90,<110,<135,<160,<200,<250,<300,<400,<500,<700,<1000
freeHi:     .byte >30,>40,>50,>60,>75,>90,>110,>135,>160,>200,>250,>300,>400,>500,>700,>1000
txtGhost:   .byte "G PHANTOM KEYS",0
txtGAllow:  .byte "PLAY    ",0
txtGFilter: .byte "FILTERED",0
txtLOff:    .byte "OFF  ",0
txtLHold:   .byte "HOLD ",0
txtTempo:   .byte "B     BPM   M MUTE       SPACE FLIPS IT",0
txtModeLn:  .byte "Z            K KEY          V",0
modeTxtLo:  .byte <tMPoly,<tMChord,<tMEx7,<tMEx9,<tMEx11,<tMEx13
modeTxtHi:  .byte >tMPoly,>tMChord,>tMEx7,>tMEx9,>tMEx11,>tMEx13
tMPoly:     .byte "POLY      ",0
tMChord:    .byte "SMART CHRD",0
tMEx7:      .byte "EXT 7TH   ",0
tMEx9:      .byte "EXT 9TH   ",0
tMEx11:     .byte "EXT 11TH  ",0
tMEx13:     .byte "EXT 13TH  ",0
txtMajor:   .byte "MAJOR",0
txtMinor:   .byte "MINOR",0
txtFat:     .byte "FAT ",0
txtPads:    .byte "PADS",0
octTxtLo:   .byte <tO0,<tO1,<tO2
octTxtHi:   .byte >tO0,>tO1,>tO2
tO0:        .byte "+0 OCT",0
tO1:        .byte "+1 OCT",0
tO2:        .byte "+2 OCT",0
txtSent:    .byte "MIDI OUT:       MESSAGES",0

; scale steps, three octaves (Expand)
scaleMajor: .byte 0,2,4,5,7,9,11,12,14,16,17,19,21,23,24,26,28,29,31,33,35
scaleMinor: .byte 0,2,3,5,7,8,10,12,14,15,17,19,20,22,24,26,27,29,31,32,34
; a note outside the key: major triad, b7, 9, 11, 13
chromTones: .byte 0,4,7,10,14,17,21
