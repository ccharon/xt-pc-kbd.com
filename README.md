# KBD.COM

Rekonstruktion von `KBD.COM`, einem kleinen deutschen Tastaturtreiber für MS-DOS.

Die Rekonstruktion basiert auf der ursprünglichen `Kbd.com` von **helmrohr.de**, einer heute nicht mehr verfügbaren Webseite. Ein archivierter Download ist weiterhin über Archive.org erreichbar:

https://web.archive.org/web/20141104155836/http://www.helmrohr.de/MsDos.htm

## Hintergrund

`KBD.COM` ist ein kompakter deutscher Tastaturtreiber für DOS, der laut originaler Dokumentation auch unter Windows in DOS-Fenstern eingesetzt werden kann. Gegenüber `KEYB.COM` benötigt er nur etwa 1 KB Speicher.

Der hier enthaltene Assemblercode ist eine Rekonstruktion der Originaldatei `Kbd.com`.
Wird der Quelltext mit **TASM 2.0** assembliert und mit **TLINK** als `.COM` gelinkt, entsteht eine Datei mit derselben Checksumme wie das Original.
(sha256sum: e380ed1ffed363f871ca0dde49a89cc4c372f68805af2ebb0e0e0967708eea7e)

## Voraussetzungen

Zum Bauen wird eine echte oder emulierte **MS-DOS Umgebung** benötigt (z. B. DOSBox).

### Auschecken

Achtung bitte mit einem ordentlichen GIT Client ausschecken, die Dateien im Repo sind UTF8 mit LF weil github sonst traurig ist. Per .gitattributes wird beim Auschecken KBD.ASM und MAKEFILE automatisch auf CP850 CRLF konvertiert.

### Benötigte Tools:

* Turbo Assembler **TASM 2.0**
* Turbo Linker (TLINK)
* Borland Make **3.0** (optional)

## Projektinhalt

* `KBD.ASM` – rekonstruierter Assembler-Quelltext (MSDOS CP850 CR/LF)
* `KBD.COM` - aus den Sourcen gebauter Tastaturtreiber
* `MAKEFILE` – Build-Anweisungen für TASM/TLINK (MSDOS CP850 CR/LF)
* `Readme.txt` – originale Begleitdatei der historischen COM-Datei (ISO-8859-1 LF)

## Build

### Mit Borland Make

```
make
```

### Direkter Build

```
TASM /ZI KBD.ASM,KBD.OBJ,KBD.LST
TLINK /T KBD.OBJ,KBD.COM
```

## Clean

```
make clean
```

Entfernt:

* `*.OBJ`
* `*.MAP`
* `*.COM`

## Funktion

`KBD.COM` ist ein TSR (Terminate and Stay Resident) Tastaturtreiber.

* hooked **INT 09h** (Keyboard-IRQ)
* verarbeitet Roh-Scancodes direkt vom Controller (Port 60h)
* übersetzt diese anhand von Mapping-Tabellen
* schreibt die modifizierten Werte in den BIOS-Tastaturpuffer

Unterstützte Zustände:

* ohne Modifier
* Shift
* Ctrl
* Alt
* Ctrl+Shift
* Alt+Ctrl (AltGr-ähnlich auf XT-Systemen)
* weitere Kombinationen

Zusätzlich werden:

* Caps-Lock-Sonderfälle (Umlaute, Y/Z)
* Prefix-/Extended-Scancodes (E0)
* BIOS-Ringpuffer-Handling

explizit berücksichtigt.

## Historische Verwendung

Die originale Dokumentation empfiehlt:

`KBD.COM` in das Verzeichnis von `KEYB.COM` zu kopieren und in der `AUTOEXEC.BAT` den bisherigen Aufruf

```
KEYB GR...
```

durch

```
KBD
```

zu ersetzen.

Alternativ konnte der Treiber auch direkt in Windows-DOS-Fenstern eingebunden werden.

## Zweck dieses Repositories

Dieses Repository dient der Rekonstruktion, Analyse und reproduzierbaren Archivierung historischer DOS-Software.
