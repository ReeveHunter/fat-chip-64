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
	.byte 6,5,K_D,8,K_C,K_F,7,K_X
	; col 3: 7 Y G 8 B H U V
	.byte 10,9,K_G,N_,K_B,K_H,11,K_V
	; col 4: 9 I J 0 M K O N
	.byte 13,12,K_J,15,K_M,K_K,14,N_
	; col 5: + P L - . : @ ,
	.byte N_,16,K_L,18,K_PERIOD,K_COLON,17,K_COMMA
	; col 6: pound * ; CLR/HOME RSHIFT = up-arrow /
	.byte 20,19,K_SEMI,22,K_RSHIFT,K_EQUALS,21,K_SLASH
	; col 7: 1 <- CTRL 2 SPACE C= Q RUN/STOP
	.byte N_,N_,K_CTRL,1,K_SPACE,K_CBM,0,K_STOP

; SID voice register offsets
sidOfs:     .byte 0,7,14

; voice pool (see voices.asm)
vDev:       .byte DEV_SID,DEV_GB,DEV_NES, DEV_SID,DEV_GB,DEV_NES, DEV_SID,DEV_GB,DEV_NES
vIdx:       .byte 0,0,0, 1,1,1, 2,2,2      ; SID voice / channel offset from the base
vBass:      .byte 0,0,0, 0,0,0, 0,1,1      ; GB wave and NES triangle: bass, octave down
noteNames:  .byte "C C#D D#E F F#G G#A A#B "

txtHeader:  .byte " FAT CHIP 64  V0.26        RETURN: MENU ",0
txtBlank6:  .byte "       ",0
txtSid:     .byte "SID",0
txtGb:      .byte "GAME BOY",0
txtNes:     .byte "MIDINES",0
txtOn:      .byte "ON   ",0
txtOff:     .byte "OFF  ",0
txtOverlap: .byte "!! GAME BOY AND NES CHANNELS OVERLAP !!",0
txtBlank:   .byte "                                       ",0
txtKeyLn:   .byte "KEY                         LATCH",0
txtHeld:    .byte "HELD                                    ",0
txtTempo:   .byte "TEMPO     BPM  BEAT",0
txtSpaceLn: .byte "SPACE           OCTAVE",0
txtMute:    .byte "MUTE",0
txtNoMute:  .byte "    ",0
txtHelp:    .byte "F1/F3 OCTAVE  F5 ARP  F7 VIZ  STOP BEAT",0
txtLatchLo: .byte <txtLOff,<txtLSmart,<txtLHold,<txtLAdd,<txtLNext
txtLatchHi: .byte >txtLOff,>txtLSmart,>txtLHold,>txtLAdd,>txtLNext
txtLNext:   .byte "NEXT ",0
txtLSmart:  .byte "SMART",0
txtLAdd:    .byte "ADD  ",0
txtArp:     .byte "ARP",0
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
; FREE speeds (ms per step), ; slower / : faster
freeLo:     .byte <10,<15,<20,<25,<30,<40,<50,<60,<75,<90,<110,<135,<160,<200,<250,<300,<400,<500,<700,<1000
freeHi:     .byte >10,>15,>20,>25,>30,>40,>50,>60,>75,>90,>110,>135,>160,>200,>250,>300,>400,>500,>700,>1000
txtMidiIn:  .byte "MIDI IN  OCT         LAST",0
txtLOff:    .byte "OFF  ",0
txtLHold:   .byte "HOLD ",0
; SPACE's action (7 characters), in A_ order
spcTxtLo:   .byte <tS0,<tS1,<tS2,<tS3,<tS4,<tS5,<tS6,<tS7,<tS8,<tS9,<tS10,<tS11,<tS12,<tS13,<tS14,<tS15,<tS16,<tS17,<tS18,<tS19
spcTxtHi:   .byte >tS0,>tS1,>tS2,>tS3,>tS4,>tS5,>tS6,>tS7,>tS8,>tS9,>tS10,>tS11,>tS12,>tS13,>tS14,>tS15,>tS16,>tS17,>tS18,>tS19
tS0:        .byte "MUTE   ",0
tS1:        .byte "BEND DN",0
tS2:        .byte "BEND UP",0
tS3:        .byte "VIBRATO",0
tS4:        .byte "TREMOLO",0
tS5:        .byte "ARP    ",0
tS6:        .byte "STUTTER",0
tS7:        .byte "VINYL  ",0
tS8:        .byte "GLIDE  ",0
tS9:        .byte "SUSTAIN",0
tS10:       .byte "OCT UP ",0
tS11:       .byte "REPEAT ",0
tS12:       .byte "SWEEP  ",0
tS13:       .byte "FILL   ",0
tS14:       .byte "WOBBLE ",0
tS15:       .byte "WIDE   ",0
tS16:       .byte "TAP    ",0
tS17:       .byte "BEAT   ",0
tS18:       .byte "SOUND  ",0
tS19:       .byte "NOTHING",0
modeTxtLo:  .byte <tMPoly,<tMChord,<tMEx7,<tMEx9,<tMEx11,<tMEx13
modeTxtHi:  .byte >tMPoly,>tMChord,>tMEx7,>tMEx9,>tMEx11,>tMEx13
tMPoly:     .byte "POLY      ",0
tMChord:    .byte "SMART CHRD",0
tMEx7:      .byte "EXT 7TH   ",0
tMEx9:      .byte "EXT 9TH   ",0
tMEx11:     .byte "EXT 11TH  ",0
tMEx13:     .byte "EXT 13TH  ",0
txtPoly:    .byte "POLY",0
txtMono:    .byte "MONO",0
txtFatBass: .byte "FAT BASS",0
txtNoBass:  .byte "        ",0
txtPlay:    .byte "PLAY",0
txtStop:    .byte "STOP",0
octTxtLo:   .byte <tO0,<tO1,<tO2
octTxtHi:   .byte >tO0,>tO1,>tO2
tO0:        .byte "+0 OCT",0
tO1:        .byte "+1 OCT",0
tO2:        .byte "+2 OCT",0
txtNoIn:    .byte "         ",0

; scale steps, three octaves (Expand)
; v0.22: the scales K picks (K, then a note or a shape: keys.asm). Each
; table: 21 steps up from the root (the scale repeated an octave higher).
scale0:     .byte 0,2,4,5,7,9,11,12,14,16,17,19,21,23,24,26,28,29,31,33,35   ; MAJOR
scale1:     .byte 0,2,3,5,7,8,10,12,14,15,17,19,20,22,24,26,27,29,31,32,34   ; MINOR
scale2:     .byte 0,2,3,5,7,9,10,12,14,15,17,19,21,22,24,26,27,29,31,33,34   ; DORIAN
scale3:     .byte 0,1,3,5,7,8,10,12,13,15,17,19,20,22,24,25,27,29,31,32,34   ; PHRYGIAN
scale4:     .byte 0,2,4,6,7,9,11,12,14,16,18,19,21,23,24,26,28,30,31,33,35   ; LYDIAN
scale5:     .byte 0,2,4,5,7,9,10,12,14,16,17,19,21,22,24,26,28,29,31,33,34   ; MIXOLYDIAN
scale6:     .byte 0,2,3,5,7,8,11,12,14,15,17,19,20,23,24,26,27,29,31,32,35   ; HARM MINOR
scale7:     .byte 0,2,4,7,9,12,14,16,19,21,24,26,28,31,33,36,38,40,43,45,48   ; PENTATONIC
scale8:     .byte 0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,32,34,36,38,40   ; WHOLE TONE
scale9:     .byte 0,1,3,4,6,7,9,10,12,13,15,16,18,19,21,22,24,25,27,28,30   ; DIMINISHED
scaleLo:    .byte <scale0,<scale1,<scale2,<scale3,<scale4,<scale5,<scale6,<scale7,<scale8,<scale9
scaleHi:    .byte >scale0,>scale1,>scale2,>scale3,>scale4,>scale5,>scale6,>scale7,>scale8,>scale9
scaleLen:   .byte 7,7,7,7,7,7,7,5,6,8
scaleName:  .byte "MAJOR     ",0, "MINOR     ",0, "DORIAN    ",0, "PHRYGIAN  ",0, "LYDIAN    ",0, "MIXOLYDIAN",0, "HARM MINOR",0, "PENTATONIC",0, "WHOLE TONE",0, "DIMINISHED",0
; K shapes: the intervals above the lowest note (bit n = n semitones) and their scale
shapeLo:    .byte $01,$11,$91,$81,$09,$89,$89,$09,$03,$41,$51,$01,$11,$91,$09,$89,$A1,$85,$11,$49,$49
shapeHi:    .byte $00,$00,$00,$00,$00,$00,$02,$02,$00,$00,$00,$04,$04,$04,$08,$08,$00,$00,$01,$00,$02
shapeScale: .byte 0,0,0,0,1,1,2,2,3,4,4,5,5,5,6,6,7,7,8,9,9
NUM_SHAPES  equ 21
pcBit:      .byte $01,$02,$04,$08,$10,$20,$40,$80
; a note outside the key: major triad, b7, 9, 11, 13
chromTones: .byte 0,4,7,10,14,17,21
