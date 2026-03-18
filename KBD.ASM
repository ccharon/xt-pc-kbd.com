; -----------------------------------------------------------------------------
; KBD.ASM
; Rekonstruktion von Kbd.com (MS-DOS TSR Tastaturtreiber)
; sha256sum: e380ed1ffed363f871ca0dde49a89cc4c372f68805af2ebb0e0e0967708eea7e
;
; Build (in DOS):
;   TASM /ZI KBD.ASM,KBD.OBJ,KBD.LST
;   TLINK /T KBD.OBJ,KBD.COM
; -----------------------------------------------------------------------------

KBD_CODE SEGMENT PARA PUBLIC 'CODE'
ASSUME CS:KBD_CODE, DS:KBD_CODE
ORG 100h

start:
    jmp install_tsr
    nop

; -----------------------------------------------------------------------------
; Uebersetzungstabellen
;
; Wichtig fuer die Interpretation:
; - In den Haupttabellen ist das Wortformat:
;     High-Byte = Roh-Scancode, auf den gematcht wird
;     Low-Byte  = Zeichenbyte, das in den BIOS-Tastaturpuffer geschrieben wird
;
; - Die Sondertabelle 'special_scan_map_prefix' arbeitet anders:
;     High-Byte = Roh-Scancode
;     Low-Byte  = ersetzender BIOS-Scan-Code fuer Prefix-/Extended-Faelle
;
; - Die Zeichen in den Kommentaren unten sind in CP850 notiert.
; -----------------------------------------------------------------------------

scan_map_state_no_modifier LABEL WORD
    ; Bei aktivem Caps Lock und ohne Ctrl/Alt wird der Tabellenstart spaeter
    ; um 5 Worte verschoben; die ersten 5 Eintraege sind also der "caps-empfindliche"
    ; Bereich fuer Umlaute und Y/Z.

    dw 2884h ; match 28h 'ä'  -> emit 84h 'ä'
    dw 2794h ; match 27h 'ö'  -> emit 94h 'ö'
    dw 1A81h ; match 1Ah 'ü'  -> emit 81h 'ü'
    dw 2C79h ; match 2Ch 'y'  -> emit 79h 'y'
    dw 157Ah ; match 15h 'z'  -> emit 7Ah 'z'
    dw 295Eh ; match 29h '^'  -> emit 5Eh '^'
    dw 0CE1h ; match 0Ch 'ß'  -> emit E1h 'ß'
    dw 0D27h ; match 0Dh '´'  -> emit 27h '''
    dw 2B23h ; match 2Bh '#'  -> emit 23h '#'
    dw 1B2Bh ; match 1Bh '+'  -> emit 2Bh '+'
    dw 352Dh ; match 35h '-'  -> emit 2Dh '-'
    dw 563Ch ; match 56h '<'  -> emit 3Ch '<'

scan_map_state_shift LABEL WORD
    ; Die letzten 5 Eintraege sind absichtlich die Kleinbuchstaben-/Umlautwerte
    ; aus state 0. Zusammen mit dem Caps-Lock-Offset ergibt das die Umkehrlogik
    ; fuer Shift+Caps bei Y/Z/Umlauten.

    dw 288Eh ; match 28h 'Ä'  -> emit 8Eh 'Ä'
    dw 2799h ; match 27h 'Ö'  -> emit 99h 'Ö'
    dw 1A9Ah ; match 1Ah 'Ü'  -> emit 9Ah 'Ü'
    dw 2C59h ; match 2Ch 'Y'  -> emit 59h 'Y'
    dw 155Ah ; match 15h 'Z'  -> emit 5Ah 'Z'
    dw 29F8h ; match 29h '^'  -> emit F8h '°'
    dw 0322h ; match 03h '2'  -> emit 22h '"'
    dw 0415h ; match 04h '3'  -> emit 15h '§'
    dw 0726h ; match 07h '6'  -> emit 26h '&'
    dw 082Fh ; match 08h '7'  -> emit 2Fh '/'
    dw 0928h ; match 09h '8'  -> emit 28h '('
    dw 0A29h ; match 0Ah '9'  -> emit 29h ')'
    dw 0B3Dh ; match 0Bh '0'  -> emit 3Dh '='
    dw 0C3Fh ; match 0Ch 'ß'  -> emit 3Fh '?'
    dw 0D60h ; match 0Dh '´'  -> emit 60h '`'
    dw 2B27h ; match 2Bh '#'  -> emit 27h '''
    dw 1B2Ah ; match 1Bh '+'  -> emit 2Ah '*'
    dw 333Bh ; match 33h ','  -> emit 3Bh ';'
    dw 343Ah ; match 34h '.'  -> emit 3Ah ':'
    dw 355Fh ; match 35h '-'  -> emit 5Fh '_'
    dw 563Eh ; match 56h '<'  -> emit 3Eh '>'
    dw 2884h ; match 28h 'Ä'  -> emit 84h 'ä'  ; Caps+Shift-Rueckfall
    dw 2794h ; match 27h 'Ö'  -> emit 94h 'ö'  ; Caps+Shift-Rueckfall
    dw 1A81h ; match 1Ah 'Ü'  -> emit 81h 'ü'  ; Caps+Shift-Rueckfall
    dw 2C79h ; match 2Ch 'Y'  -> emit 79h 'y'  ; Caps+Shift-Rueckfall
    dw 157Ah ; match 15h 'Z'  -> emit 7Ah 'z'  ; Caps+Shift-Rueckfall

scan_map_state_ctrl LABEL WORD
    dw 2C19h ; match 2Ch 'y'  -> emit 19h ^Y
    dw 151Ah ; match 15h 'z'  -> emit 1Ah ^Z
    dw 351Fh ; match 35h '-'  -> emit 1Fh ^_

scan_map_state_alt LABEL WORD
    dw 082Bh ; match 08h '7'  -> emit 2Bh '+'

scan_map_state_ctrl_shift LABEL WORD
    ; Formal dieselbe Struktur wie alle anderen Haupttabellen.
    ; Inhaltlich faellt diese Ebene aus dem sonstigen Muster heraus und sollte
    ; deshalb neutral gelesen werden: das sind die tatsaechlich emittierten Bytes,
    ; nicht notwendigerweise "klassische" Ctrl+Shift-Ergebnisse.

    dw 2C19h ; match 2Ch 'Y'  -> emit 19h ^Y
    dw 151Ah ; match 15h 'Z'  -> emit 1Ah ^Z
    dw 1E61h ; match 1Eh 'A'  -> emit 61h 'a'
    dw 30E1h ; match 30h 'B'  -> emit E1h 'ß'
    dw 2E72h ; match 2Eh 'C'  -> emit 72h 'r'
    dw 2247h ; match 22h 'G'  -> emit 47h 'G'
    dw 20EBh ; match 20h 'D'  -> emit EBh 'ë'
    dw 19E3h ; match 19h 'P'  -> emit E3h 'ã'
    dw 1F73h ; match 1Fh 'S'  -> emit 73h 's'
    dw 32E6h ; match 32h 'M'  -> emit E6h 'µ'
    dw 18EAh ; match 18h 'O'  -> emit EAh 'ê'
    dw 21EDh ; match 21h 'F'  -> emit EDh 'Ý'
    dw 1245h ; match 12h 'E'  -> emit 45h 'E'
    dw 1430h ; match 14h 'T'  -> emit 30h '0'
    dw 10FBh ; match 10h 'Q'  -> emit FBh '¹'

scan_map_state_alt_ctrl LABEL WORD
    ; Auf XT entspricht das praktisch der AltGr-Ebene.

    dw 1EA0h ; match 1Eh 'a'  -> emit A0h 'á'
    dw 1282h ; match 12h 'e'  -> emit 82h 'é'
    dw 17A1h ; match 17h 'i'  -> emit A1h 'í'
    dw 18A2h ; match 18h 'o'  -> emit A2h 'ó'
    dw 16A3h ; match 16h 'u'  -> emit A3h 'ú'
    dw 03FDh ; match 03h '2'  -> emit FDh '²'
    dw 04FCh ; match 04h '3'  -> emit FCh '³'
    dw 1040h ; match 10h 'q'  -> emit 40h '@'
    dw 087Bh ; match 08h '7'  -> emit 7Bh '{'
    dw 095Bh ; match 09h '8'  -> emit 5Bh '['
    dw 0A5Dh ; match 0Ah '9'  -> emit 5Dh ']'
    dw 0B7Dh ; match 0Bh '0'  -> emit 7Dh '}'
    dw 0C5Ch ; match 0Ch 'ß'  -> emit 5Ch '\'
    dw 1B7Eh ; match 1Bh '+'  -> emit 7Eh '~'
    dw 567Ch ; match 56h '<'  -> emit 7Ch '|'
    dw 32E6h ; match 32h 'm'  -> emit E6h 'µ'

scan_map_state_alt_shift LABEL WORD
    dw 1E85h ; match 1Eh 'A'  -> emit 85h 'à'
    dw 128Ah ; match 12h 'E'  -> emit 8Ah 'è'
    dw 178Dh ; match 17h 'I'  -> emit 8Dh 'ì'
    dw 1895h ; match 18h 'O'  -> emit 95h 'ò'
    dw 1697h ; match 16h 'U'  -> emit 97h 'ù'
    dw 03F9h ; match 03h '2'  -> emit F9h '¨'
    dw 05F9h ; match 05h '4'  -> emit F9h '¨'

scan_map_state_alt_ctrl_shift LABEL WORD
    dw 1E83h ; match 1Eh 'A'  -> emit 83h 'â'
    dw 1288h ; match 12h 'E'  -> emit 88h 'ê'
    dw 178Ch ; match 17h 'I'  -> emit 8Ch 'î'
    dw 1893h ; match 18h 'O'  -> emit 93h 'ô'
    dw 1696h ; match 16h 'U'  -> emit 96h 'û'

special_scan_map_prefix LABEL WORD
    ; Sondertabelle fuer Prefix-/Extended-Faelle
    ; Hier wird bei Treffer nur der Scan-Code im finalen BIOS-Pufferwort ersetzt.

    dw 2C15h ; match sc 2Ch (E0 2C?) -> override BIOS scan to 15h
    dw 152Ch ; match sc 15h (E0 15?) -> override BIOS scan to 2Ch
    dw 7903h ; match sc 79h          -> override BIOS scan to 03h

state_table_ptr LABEL WORD
    ; Tabelle fuer Zustand -> Startoffset in den obigen Tabellen.
    dw scan_map_state_no_modifier
    dw scan_map_state_shift
    dw scan_map_state_ctrl
    dw scan_map_state_ctrl_shift
    dw scan_map_state_alt
    dw scan_map_state_alt_shift
    dw scan_map_state_alt_ctrl
    dw scan_map_state_alt_ctrl_shift

state_table_count LABEL BYTE
    db 0Ch ; scan_map_state_no_modifier
    db 15h ; scan_map_state_shift
    db 03h ; scan_map_state_ctrl
    db 0Fh ; scan_map_state_ctrl_shift
    db 01h ; scan_map_state_alt
    db 07h ; scan_map_state_alt_shift
    db 10h ; scan_map_state_alt_ctrl
    db 05h ; scan_map_state_alt_ctrl_shift

last_prefix db 00h

; -----------------------------------------------------------------------------
; Routine: int09_handler
; Zweck:
;   Keyboard-IRQ (INT 09h) hooken, Scancode/ASCII anpassen, alten Handler rufen.
; Eingaben:
;   HW-IRQ Kontext.
; Ausgaben:
;   modifizierter Eintrag im BIOS-KBD-Puffer (falls Mapping greift).
; Zerstoerte Register:
;   AX, BX, CX, DI, DS, ES (lokal gesichert/wiederhergestellt).
; Vorbedingungen:
;   old_int9_call_* ist waehrend Installation mit alter INT-09h-Vektoradresse
;   gepatcht worden.
; Nachbedingungen:
;   kehrt via IRET zurueck.
; -----------------------------------------------------------------------------
int09_handler:
    ; Handler-Kontext aufbauen
    cld
    push ds
    push bx
    push ax
    push cx
    push es
    push di
    push cs
    pop es

    ; Herleitung des State-Index aus BIOS-Flags (BDA 40:17h, low nibble):
    ;   raw = [40:17] oder 0Ch wenn [40:96].bit3 gesetzt
    ;   index = ((raw >> 1) OR (raw AND 1)) AND 7
    ; Zusatzlogik:
    ;   wenn (raw AND 06h)==0 und (raw AND 40h)!=0, wird der Tabellenstart
    ;   um 5 Worte (+0Ah Byte) verschoben (Caps-Lock-Sonderfall).

    ; Shift-/Statuszustand aus BDA lesen
    mov cx,40h
    mov ds,cx
    xor bx,bx
    test byte ptr ds:[0096h],08h ; BDA 40:96h Bit 3 erzwingt raw=0Ch (Alt+Ctrl/AltGr-Pfad)
    mov al,0Ch
    jnz short state_loaded ; wenn gesetzt: AL bleibt 0Ch
    mov al,byte ptr ds:[0017h]


state_loaded:
    ; Rohzustand auf State-Index 0..7 normalisieren
    mov di,ax
    shr al,1 ; CF = altes Bit0, AL um 1 nach rechts
    jnc short state_index_ready ; altes Bit0 war 0
    or al,01h ; altes Bit0 war 1 -> Shift-Bit im Index behalten

state_index_ready:
    ; Mappingtabelle und Suchlaenge zum Zustand waehlen
    and ax,0007h ; Index auf 0..7 begrenzen
    test al,06h ; Ctrl/Alt im normalisierten Index?
    xchg ax,di
    mov cl,byte ptr cs:[di+state_table_count]
    rol di,1
    mov di,word ptr cs:[di+state_table_ptr]
    jnz short read_scancode ; bei Ctrl oder Alt kein Caps-Lock-Offset
    test al,40h ; Caps Lock im Rohstatus?
    jz short read_scancode
    add di,000Ah ; 5 Worte ueberspringen (Caps-Sonderfall fuer Umlaute/Y/Z)

read_scancode:
    ; Scancode einlesen und Prefix-Status pflegen
    in al,60h ; Tastaturcontroller-Datenport -> AL
    mov ah,al
    cmp byte ptr cs:[last_prefix],0E0h ; war der vorherige Rohcode ein E0-Prefix?
    mov byte ptr cs:[last_prefix],al
    jz short apply_special_table ; dann direkt Prefix-Tabelle pruefen
    jcxz short apply_special_table ; leere Haupttabelle

scan_map_loop:
    ; primaere Mappingtabelle durchsuchen
    ; Im Speicher liegt ein Wort little-endian als [char][scan].
    ; Vor SCASW ist also AX = [aktueller Rohscan in AH][tabellen-char in AL].
    ; Ein Treffer liefert direkt das spaetere BIOS-Pufferwort in AX.
    mov al,es:[di]
    scasw
    loopne scan_map_loop ; weiter solange CX!=0 und kein Treffer (ZF=0)
    jnz short apply_special_table ; kein Treffer in Haupttabelle
    mov bx,ax ; BX = Kandidat fuer BIOS-Pufferwort [scan|char]

apply_special_table:
    ; Prefix-/Sondertabelle pruefen
    mov di,OFFSET special_scan_map_prefix
    mov cl,03h

special_loop:
    mov al,es:[di]
    scasw
    loopne special_loop ; weiter solange CX!=0 und kein Treffer (ZF=0)
    jnz short call_previous_handler ; kein Prefix-Treffer
    mov bh,al ; nur BIOS-Scan-Code ersetzen, Zeichenbyte BL bleibt erhalten

call_previous_handler:
    ; alten INT-09h aufrufen und BIOS-Puffer ggf. patchen
    mov ax,word ptr ds:[001Ch]
    pushf ; FAR CALL nutzt INT-aehnlichen Stackframe fuer den gehookten Handler
old_int9_call:
    db 09Ah
old_int9_call_off dw 0000h
old_int9_call_seg dw 0000h

    xchg ax,bx
    or ax,ax ; Nulltest auf Rueckgabewort des alten Handlers
    jz short int09_exit ; Rueckgabewort=0 -> nichts patchen

    mov [bx],ax ; gerade erzeugten BIOS-Puffereintrag am alten Head ueberschreiben
    lea ax,[bx+2]
    cmp al,3Eh ; Ende des BIOS-Ringpuffers?
    jnz short no_wrap
    mov al,1Eh ; Wrap auf Bufferanfang

no_wrap:
    ; BIOS-Head-Pointer nur bei Aenderung committen
    cmp ax,word ptr ds:[001Ah] ; neuer Head gleich Tail -> Puffer voll
    jz short int09_exit
    mov word ptr ds:[001Ch],ax

int09_exit:
    ; Kontext wiederherstellen und ISR verlassen
    pop di
    pop es
    pop cx
    pop ax
    pop bx
    pop ds
    iret ; 8088: IRET stellt IP/CS/FLAGS wieder her

; -----------------------------------------------------------------------------
; Routine: install_tsr
; Zweck:
;   Meldung ausgeben, alten INT-09h-Vektor sichern, neuen Handler setzen,
;   resident bleiben.
; Eingaben:
;   COM-Startkontext.
; Ausgaben:
;   Programm bleibt resident.
; Zerstoerte Register:
;   AX, BX, DX, ES.
; Vorbedingungen:
;   DS zeigt beim COM-Start auf den Programmsegmentbereich.
; Nachbedingungen:
;   INT 09h zeigt auf int09_handler, Aufrufer bekommt Kontrolle via DOS zurueck.
; -----------------------------------------------------------------------------
install_tsr:
    ; Statusmeldung ausgeben (DOS INT 21h / AH=09h)
    mov dx,OFFSET resident_message
    mov ah,09h
    int 21h ; DS:DX -> '$'-terminierter String

    ; alten INT-09h-Vektor sichern (DOS INT 21h / AH=35h)
    mov ax,3509h
    int 21h ; AL=09h, Rueckgabe ES:BX
    mov [old_int9_call_off],bx
    mov [old_int9_call_seg],es

    ; neuen INT-09h-Handler setzen (DOS INT 21h / AH=25h)
    mov ax,2509h
    mov dx,OFFSET int09_handler
    int 21h ; AL=09h, DS:DX -> neuer Vektor

    ; resident bleiben (INT 27h TSR)
    mov dx,0260h
    int 27h ; CS:DX -> erstes freies Byte hinter residentem Teil

resident_message:
    db 0Dh,0Ah
    db 'Tastaturtreiber v4.01 resident geladen.'
    db 0Ah,0Dh,0Ah,0Dh,0Ah,'$'

KBD_CODE ENDS
END start
