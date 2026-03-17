KBD.COM
ist ein kleiner deutscher Tastaturtreiber für DOS,
der auch unter Windows geladen werden kann und ohne 
Einschränkungen funktioniert. Im Gegensatz zu dem
in DOS bereits vorhandenen Treiber KEYB.COM benötigt
KBD.COM nur ca. 1 kb im Speicher.

Installation:
Kopieren Sie KBD.COM nach dem Entpacken in das
Verzeichnis WINDOWS\COMMAND bzw. in das Verzeichnis,
in dem sich KEYB.COM befindet (nein, es wird nicht
gelöscht). Ändern Sie in Ihrer AUTOEXEC.BAT den
Aufruf
KEYB GR...
in 
KBD (ohne jeden Zusatz)

Wenn Sie den Treiber nicht in der AUTOEXEC.BAT
laden wollen (für Windows nicht erforderlich),
können Sie ihn in einem DOS-Fenster von Windows
dennoch benutzen, wenn Sie die Verknüpfung für
die "MSDOS-Eingabeaufforderung" mit der rechten
Maustaste anklicken, "Eigenschaften" wählen und 
auf der Registerkarte "Programm" in das Feld
"Stapelverarbeitungsdatei:" KBD.COM eintragen.

Dies gilt analog für andere Verknüpfungen zu
MSDOS-Programmen.
