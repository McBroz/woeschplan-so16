# 🧺☀️ Wöschplan SO 16

Waschraum-Buchungsplan für unser Haus SO 16 (6 Wohnungen, max. 12 Personen).
Reines HTML/JS ohne Build-Pipeline, Backend = Supabase (Postgres + RPC-Funktionen).

## Setup (einmalig)

1. **Supabase:** Im bestehenden Projekt (`tjrybgrdjvntdbjdlyio`, dasselbe wie beim
   WM-Tippspiel) im SQL Editor das komplette Skript [`supabase-setup.sql`](supabase-setup.sql)
   ausführen. Das legt die Tabellen, RLS-Regeln, RPC-Funktionen und das Admin-Konto
   `Ale` (PIN `8134`) an.
2. **Hosting:** `index.html` per GitHub Pages ausliefern. GitHub Pages funktioniert auf dem
   kostenlosen Plan nur bei **öffentlichen** Repos (private Repos brauchen GitHub Pro) — das
   Repo ist deshalb public. Der Code ist damit sichtbar, die App selbst bleibt aber
   PIN-geschützt (siehe Sicherheit unten).
3. Fertig — der QR-Code auf der Login-Seite verlinkt automatisch auf die aktuelle URL.

## Login

- Name eingeben → falls neu: 4-stelligen PIN wählen (Konto wird erstellt).
- Bestehender Name → PIN eingeben.
- Admin-Konto: Name `Ale`, PIN `8134` → sieht Nutzerliste inkl. PINs, kann
  Chat moderieren, PINs zurücksetzen, Nutzer löschen, Buchungen stornieren.

## Kalender vs. Wochenwünsche — der Unterschied

Zwei bewusst getrennte Ansichten, weil sie unterschiedliche Probleme lösen:

- **📅 Kalender:** feste, verbindliche Buchung eines Maschinen-Slots — aber nur für
  **heute + die folgenden 2 Tage**, damit niemand die Maschine wochenlang blockiert.
- **💭 Wochenwünsche:** weil man 3 Tage im Voraus oft noch nicht buchen kann, aber schon
  weiß "ich muss Freitag waschen", gibt's hier ein unverbindliches Wunschboard für die
  **ganze kommende Woche** (Tag + Tageszeit + Notiz). Keine Reservation, keine
  Kollisionsprüfung — mehrere Wünsche am selben Slot sind okay, man spricht sich im Chat ab.
  Sobald der Tag ins 3-Tage-Fenster rutscht, macht man daraus im Kalender eine echte Buchung.

Setup: zusätzlich [`supabase-setup-wochenplan.sql`](supabase-setup-wochenplan.sql) im
SQL Editor ausführen.

## Regeln

- Buchungen sind für **heute und die folgenden 2 Tage** möglich (rollierendes 72h-Fenster,
  serverseitig geprüft) — fair für alle 12 Personen, keine Wochen-Blockaden. Spätere Tage
  sind als **Vorschau** sichtbar (🔒), aber noch nicht buchbar.
- Zeitraster: 2-Stunden-Slots von 07:00–22:00 Uhr, 2 Maschinen (🌀 Waschmaschine + 🔥 Tumbler).
- Intuitiv: freie Plätze sind grün („frei — tippen zum Buchen"), belegte zeigen **wer** gebucht
  hat; die eigene Buchung ist blau markiert und mit ✕ stornierbar (Admin kann alle stornieren).
- Auslastung wird pro Tag als Bruchzahl + Ring-Diagramm angezeigt (z.B. `3/16 belegt`).

## QR-Code-Poster zum Ausdrucken

Drei druckfertige Poster (A4, JPG) liegen im Ordner und verlinken auf die App-URL:
[`qr-poster-sonnig.jpg`](qr-poster-sonnig.jpg) · [`qr-poster-himmel.jpg`](qr-poster-himmel.jpg) ·
[`qr-poster-frisch.jpg`](qr-poster-frisch.jpg). Alle QR-Codes sind decodier-geprüft.
Neu erzeugen (z.B. nach URL-Änderung): `python make_qr_posters.py` (braucht `qrcode` + `pillow`).
Die URL steht oben im Skript.

## Admin-Statistik

Im Admin-Bereich zeigt eine Tabelle pro Nutzer: Anzahl Buchungen, Gesamtstunden
(mit Balken-Vergleich), Anzahl Wochenwünsche und letzte Aktivität — damit sich die
Nutzung im Haus fair beobachten und bei Bedarf ansprechen lässt. Setup: zusätzlich
[`supabase-migration-stats.sql`](supabase-migration-stats.sql) im SQL Editor ausführen.

## Sicherheit

Anders als beim Tippspiel läuft **jede Schreib-Operation über geprüfte
Postgres-RPC-Funktionen** (`wp_login`, `wp_register`, `wp_create_booking`, `wp_send_chat`,
`wp_admin_action`, …), nicht über direktes Tabellen-CRUD mit dem öffentlichen Anon-Key.
PINs sind für alle außer den geprüften Admin-Aufruf nicht auslesbar.

Details zum Bau/Verlauf: [`SESSION-LOG.md`](SESSION-LOG.md),
Status-Übersicht: [`session-dashboard.html`](session-dashboard.html).
