# 🧺☀️ Wöschplan SO 16

Waschraum-Buchungsplan für unser Haus SO 16 (6 Parteien, max. 12 Personen).
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
  die Hausordnung pflegen/löschen, PINs zurücksetzen, Nutzer löschen, Buchungen stornieren.

## Die vier Ansichten

- **🏠 Übersicht:** Landing-Seite nach dem Login. Sonnenberg-Willkommensbanner,
  tageszeit-abhängige Begrüßung und auf einen Blick, *was heute läuft* — freie Slots,
  Auslastung, eigene Termine, die heutigen Buchungen, der **Waschraum-Füllstand**
  (siehe unten) und der letzte Hausordnungs-Eintrag.
- **📅 Kalender:** feste, verbindliche Buchung eines Zeitfensters — aber nur für
  **heute + die folgenden 3 Tage**, damit niemand den Waschraum wochenlang blockiert.
  Wünsche aus der Wochenvorschau erscheinen hier als unverbindliche Vorschau.
- **🗓️ Wochenvorschau:** Vorausplanung fürs **ganze Jahr**, nach Monat gruppiert. Jede
  Kalenderwoche ist eine Karte; man trägt pro Woche einen Waschwunsch mit kurzer Notiz
  ein. Die aktuelle Woche ist hervorgehoben, vergangene sind ausgegraut.
- **📋 Hausordnung:** vom Admin gepflegte Infotafel (siehe unten).

**Wunsch → echte Buchung:** Nur der Admin kann pro Woche einen Wunsch **fixieren**
(📌 — fragt die Startstunde ab und legt Mo–Sa feste Buchungen für WM+TU an) oder eine
Woche **sperren** (🔒 — dann kann der Nutzer sie nicht mehr bearbeiten). So sammeln alle
ihre Wünsche fürs Jahr, und der Admin teilt verbindlich zu.

Setup: zusätzlich [`supabase-setup-wochenplan.sql`](supabase-setup-wochenplan.sql) **und**
[`supabase-migration-wishes-to-bookings.sql`](supabase-migration-wishes-to-bookings.sql)
im SQL Editor ausführen.

## Waschraum-Füllstand (virtueller Waschraum)

Damit man vorher weiß, ob im Trockenraum überhaupt noch Platz zum Aufhängen ist, gehört zu
jeder Buchung eine **kleine Aufgabe**: nach dem Buchen öffnet sich ein Dialog „Wie voll ist
der Waschraum gerade?" mit fünf Stufen — ✨ leer · 🧦 ¼ · 👕 ½ · 🧺 ¾ · 🚫 voll (überspringbar
mit „Später"). Melden kann man jederzeit auch ohne Buchung.

Angezeigt wird das Ganze als **virtueller Waschraum**: eine SVG-Szene mit WM, Tumbler,
Wäschekorb und einem Wäscheständer, an dem je nach Füllstand 0 bis 12 Wäschestücke hängen —
plus Prozentzahl, Farbbalken (grün → orange → rot) und „gemeldet von *wem*, vor *wie lange*".
Meldungen älter als 12 Stunden werden als *vielleicht veraltet* markiert. Groß auf der
Übersicht, kompakt neben dem Belegungsring im Kalender.

Setup: zusätzlich [`supabase-migration-raumstatus.sql`](supabase-migration-raumstatus.sql)
im SQL Editor ausführen. Solange das fehlt, blendet die App die Anzeige einfach aus.

## Regeln

- Buchungen sind für **heute und die folgenden 3 Tage** möglich (rollierendes 96h-Fenster,
  serverseitig geprüft) — fair für alle 6 Parteien, keine Wochen-Blockaden. Spätere Tage
  sind als **Vorschau** sichtbar (🔒), aber noch nicht buchbar.
- Zeitraster: 2-Stunden-Slots von 07:00–22:00 Uhr. **Waschmaschine und Tumbler werden immer
  gemeinsam** für das gewählte Zeitfenster gebucht — ein Klick, eine Buchung, statt zwei
  separate Buttons pro Maschine.
- Intuitiv: freie Plätze sind grün („frei — tippen zum Buchen"), belegte zeigen **wer** gebucht
  hat; die eigene Buchung ist blau markiert und mit ✕ stornierbar (Admin kann alle stornieren).
- Auslastung wird pro Tag als Bruchzahl + Ring-Diagramm angezeigt (z.B. `3/8 belegt`).
- Tage sind durchgehend mit Wochentag beschriftet ("Heute Sa", "Mo", "Di", …) statt eines
  Sonderfalls "Morgen".

## Hausordnung (Blackboard)

Der frühere Haus-Chat ist jetzt eine **vom Admin gepflegte Infotafel** im Blackboard-Look:
nur der Admin kann neue Einträge anschlagen (serverseitig in `wp_send_chat` erzwungen, nicht
nur im Frontend versteckt), alle Bewohner können mitlesen. Admin kann Einträge jederzeit
wieder löschen. Setup: zusätzlich [`supabase-migration-combined-booking.sql`](supabase-migration-combined-booking.sql)
im SQL Editor ausführen.

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
`wp_set_room_status`, `wp_admin_action`, …), nicht über direktes Tabellen-CRUD mit dem
öffentlichen Anon-Key.
PINs sind für alle außer den geprüften Admin-Aufruf nicht auslesbar.

Details zum Bau/Verlauf: [`SESSION-LOG.md`](SESSION-LOG.md),
Status-Übersicht: [`session-dashboard.html`](session-dashboard.html).
