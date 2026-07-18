# Session-Log — Wöschplan SO 16

## 2026-07-18 — Erstaufbau

**Anfrage:** HTML-Online-Dashboard für Waschraum-Buchung im Haus SO 16
(6 Wohnungen, max. 12 Personen), nutzerbasierter Login via QR-Code,
Supabase-Backend, Admin-Rechte für "Ale", Sonnenberg-Sonnendesign,
Chat mit Moderation, max. 5h Vorausbuchung, private GitHub-Repo.

**Vorbild:** WM-Tippspiel-Projekt (`~/Documents/Claude/Projects/WM Tippspiel`) —
gleiche Grundarchitektur (reines HTML/JS, Supabase, 2-Schritt Name+PIN-Login,
Chat mit Admin-Moderation), aber neu für Wäscheplan-Domäne.

**Rückfragen an Nutzer (beantwortet):**
- GitHub-Push: lokal vorbereiten, Nutzer fügt es selbst über GitHub Desktop hinzu
  (kein `gh` CLI und keine Git-Zugangsdaten auf diesem Rechner gefunden).
- Supabase: bestehendes Tippspiel-Projekt (`tjrybgrdjvntdbjdlyio`) wiederverwenden,
  neue eigene Tabellen (`wp_*` Präfix) statt neuem Projekt.
- Adress-Anzeige: nur "SO 16" als Kürzel (keine ausgeschriebene Strasse).
- Admin-PIN für "Ale": `8134`.

**Entscheidungen / Architektur:**
- **Sicherheits-Verbesserung gegenüber Tippspiel:** Das Tippspiel schreibt direkt per
  Anon-Key auf die Tabellen (RLS `using(true)`) — im Tippspiel-NOTES.md selbst als
  offene Schwachstelle vermerkt ("Anon-Key kann fremde Tipps/Results ändern").
  Für den Wöschplan läuft **jede Schreib-Operation über SECURITY DEFINER
  RPC-Funktionen** in Postgres (`wp_login`, `wp_register`, `wp_create_booking`,
  `wp_cancel_booking`, `wp_send_chat`, `wp_admin_action`). Der Anon-Key selbst hat nur
  SELECT auf Buchungen/Chat und **kein** Zugriff auf die `wp_users`-Tabelle (PINs).
  PINs sind nur über die admin-geprüfte RPC `wp_admin_action(action='list_users')`
  sichtbar, korrekt authentifiziert per Admin-Name+PIN.
- **5h-Vorausbuchungsregel:** in der RPC `wp_create_booking` serverseitig geprüft
  (`p_start <= now() + interval '5 hours'`), nicht nur im Frontend — verhindert, dass
  jemand über die Browser-Konsole die Regel umgeht.
- **Maschinen/Zeitraster:** 2 Maschinen (Waschmaschine + Tumbler), 2h-Slots von 07–22 Uhr,
  ergibt 16 buchbare Slots/Tag → Belegungsanzeige als Bruch (z.B. "5/16 belegt") plus
  Ring-Diagramm, passt zur Nutzer-Vorgabe "1/2 oder 1/5 oder andere".
  Nicht als feste Ballenkonstanten hart einprogrammiert im Sinne einer Illusion von
  Präzision — reale Maschinenanzahl im Haus war nicht bekannt, ggf. in `MACHINES`-Array
  in `index.html` anpassen falls abweichend.
- **Max. 12 Personen:** in `wp_register` serverseitig durchgesetzt (`raise exception`
  ab dem 13. Konto).
- **QR-Code:** kein fest hinterlegter Link, sondern dynamisch via
  `api.qrserver.com` auf `location.href` — funktioniert unabhängig davon, unter
  welcher finalen GitHub-Pages-URL die Seite landet.
- **Design:** eigenes "Sonnenberg"-Sonnendesign (warme Gelb-/Orangetöne, Sonnen-Verlauf
  oben rechts, Baloo-2-Rundschrift), abgeleitet von der Tippspiel-CSS-Struktur aber
  komplett neu eingefärbt/gestaltet.

**Erstellte Dateien:**
- `index.html` — komplette App (Login, Kalender/Buchung, Chat, Admin)
- `supabase-setup.sql` — einmalig im Supabase SQL Editor auszuführen
- `README.md` — Setup-Anleitung
- `SESSION-LOG.md` — dieses Log
- `session-dashboard.html` — visuelle Status-/Projektübersicht

**Offene Schritte (Nutzer):**
1. `supabase-setup.sql` im Supabase SQL Editor ausführen.
2. Lokalen Ordner in GitHub Desktop hinzufügen → **privates** Repo erstellen → Push.
3. GitHub Pages für das Repo aktivieren (Settings → Pages).
4. Falls die tatsächliche Maschinenzahl/-namen im Waschraum abweicht: `MACHINES`-Array
   oben in `index.html` anpassen.
