# 🧺☀️ Wöschplan SO 16

Waschraum-Buchungsplan für unser Haus SO 16 (6 Wohnungen, max. 12 Personen).
Reines HTML/JS ohne Build-Pipeline, Backend = Supabase (Postgres + RPC-Funktionen).

## Setup (einmalig)

1. **Supabase:** Im bestehenden Projekt (`tjrybgrdjvntdbjdlyio`, dasselbe wie beim
   WM-Tippspiel) im SQL Editor das komplette Skript [`supabase-setup.sql`](supabase-setup.sql)
   ausführen. Das legt die Tabellen, RLS-Regeln, RPC-Funktionen und das Admin-Konto
   `Ale` (PIN `8134`) an.
2. **Hosting:** `index.html` per GitHub Pages ausliefern (Repo **privat**, Pages-Branch
   aktivieren unter Settings → Pages).
3. Fertig — der QR-Code auf der Login-Seite verlinkt automatisch auf die aktuelle URL.

## Login

- Name eingeben → falls neu: 4-stelligen PIN wählen (Konto wird erstellt).
- Bestehender Name → PIN eingeben.
- Admin-Konto: Name `Ale`, PIN `8134` → sieht Nutzerliste inkl. PINs, kann
  Chat moderieren, PINs zurücksetzen, Nutzer löschen, Buchungen stornieren.

## Wunschboard (Wochenplan)

Zusätzlich zur festen 5h-Buchung gibt es ein unverbindliches **Wunschboard** für die
kommenden 7 Tage: jede:r trägt frei ein, wann sie/er sich den Waschraum wünscht
(Tag + Tageszeit morgens/mittags/nachmittags/abends + optionale Notiz). Es ist
**keine Reservation** — mehrere Wünsche am selben Slot sind möglich, man spricht
sich einfach respektvoll im Chat ab. Setup: zusätzlich
[`supabase-setup-wochenplan.sql`](supabase-setup-wochenplan.sql) im SQL Editor ausführen.

## Regeln

- Buchungen sind **maximal 5 Stunden im Voraus** möglich (fair für alle 12 Personen,
  keine Wochen-Blockaden).
- Zeitraster: 2-Stunden-Slots von 07:00–22:00 Uhr, 2 Maschinen (Waschmaschine + Tumbler).
- Auslastung wird pro Tag als Bruchzahl + Ring-Diagramm angezeigt (z.B. `3/16 belegt`).

## Sicherheit

Anders als beim Tippspiel läuft **jede Schreib-Operation über geprüfte
Postgres-RPC-Funktionen** (`wp_login`, `wp_register`, `wp_create_booking`, `wp_send_chat`,
`wp_admin_action`, …), nicht über direktes Tabellen-CRUD mit dem öffentlichen Anon-Key.
PINs sind für alle außer den geprüften Admin-Aufruf nicht auslesbar.

Details zum Bau/Verlauf: [`SESSION-LOG.md`](SESSION-LOG.md),
Status-Übersicht: [`session-dashboard.html`](session-dashboard.html).
