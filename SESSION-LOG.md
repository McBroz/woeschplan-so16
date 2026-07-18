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

## 2026-07-18 — Nachtrag: Wunschboard (Wochenplan)

**Anfrage:** zusätzlich zum harten 5h-Buchungssystem ein unverbindliches Wunschboard
für die kommende Woche, wo jede:r einen Wunsch (Tag/Tageszeit/Notiz) eintragen kann —
keine Reservation, mehrere Wünsche am selben Slot okay, solange respektvoll abgesprochen.

**Umsetzung:**
- Neue Tabelle `wp_wishes` (in [`supabase-setup-wochenplan.sql`](supabase-setup-wochenplan.sql),
  additiv zum bestehenden Setup) — bewusst **ohne** Überlappungs-/Konflikt-Check in der
  RPC `wp_add_wish`, da es explizit kein Reservationssystem sein soll.
- Gleiches Sicherheitsmuster wie Buchungen/Chat: anon darf nur SELECT, Schreiben nur
  über `wp_add_wish` / `wp_remove_wish` (security definer, prüft Name+PIN).
- Zeitraum auf die kommenden 7 Tage begrenzt (serverseitig geprüft).
- Neuer Tab "💭 Wunschboard" in `index.html` mit 7-Tage-Kartenansicht, Tageszeiten
  morgens/mittags/nachmittags/abends, eigene Wünsche selbst entfernbar, Admin kann
  alle entfernen.
- Im Browser getestet (Login-Seite lädt ohne Konsolenfehler, Syntax der Ergänzung ok).

**Offen:** `supabase-setup-wochenplan.sql` muss noch im Supabase SQL Editor ausgeführt
werden (zusätzlich zum ursprünglichen `supabase-setup.sql`).

## 2026-07-18 (später) — Buchungsfenster 2 Tage, Design-Politur, QR-Poster

**Anfrage:** Buchung der Termine für die folgenden 2 Tage ermöglichen (intuitiv buchen /
sehen wer belegt hat), Design mit Bildern/Animationen aufwerten, druckbare QR-Code-JPGs
(schöne Bilder mit URL) erstellen, alles speichern & committen.

**Umgesetzt (alles live getestet):**
- **Buchungsfenster:** Von der ursprünglichen 5h-Regel auf **heute + die folgenden 2 Tage**
  umgestellt. Serverseitig in `wp_create_booking` als rollierendes 72h-Fenster
  (`p_start > now() + interval '3 days'` → Ablehnung), zeitzonensicher. Migration
  `supabase-migration-2tage.sql` **im Supabase SQL Editor ausgeführt** (Erfolg bestätigt).
  Live getestet: Buchung morgen = OK, Buchung Tag+4 = korrekt abgelehnt.
- **Intuitive Buchungs-UI:** Slot-Karten neu — pro Maschine eine Zeile mit Icon
  (🌀/🔥), Status und Aktion: grün „frei — tippen zum Buchen" (+), rot „belegt: {Name}",
  eigene Buchung blau „🙋 Du" mit ✕-Storno. Tag-Tabs zeigen 🟢 (buchbar) bzw. 🔒 (Vorschau).
- **Design/Animation:** animierte Waschmaschine (drehende Trommel) + aufsteigende Seifenblasen
  im Kalender-Header, sanfte Karten-Einblend-Animation, drehende Maschinen-Icons beim Hover,
  gepolisterte Badges/Banner.
- **Mobile-Header-Fix:** Der sticky Header hat auf schmalen Screens die Inhalte überlappt
  (Nav-Buttons fingen Klicks ab). Neu: sauber gestapeltes, scrollbares Nav — via Browser
  verifiziert (vorher/nachher).
- **QR-Poster:** `make_qr_posters.py` (qrcode + Pillow) erzeugt 3 druckfertige A4-JPGs
  (`qr-poster-sonnig/himmel/frisch.jpg`) im Sonnenberg-Stil: Sonne, Wäscheleine mit bunten
  Shirts, Seifenblasen, gerundeter QR, URL-Pille. **Alle 3 mit OpenCV decodier-geprüft** →
  lösen `https://mcbroz.github.io/woeschplan-so16/` auf. GitHub-Pages-URL abgeleitet aus dem
  Repo-Namen (Username kleingeschrieben).

**Hinweis Timing:** Beim Testen rollte die Systemuhr über Mitternacht auf den 19.07.;
Test-Buchungen wurden nach der Prüfung wieder gelöscht (DB sauber, 0 Buchungen).

## 2026-07-18 — Erstaufbau & erste Ergänzungen

**Offene Schritte (Nutzer):**
1. `supabase-setup.sql` im Supabase SQL Editor ausführen. ✅ (bereits erledigt in dieser Session)
2. Lokalen Ordner in GitHub Desktop hinzufügen → **privates** Repo erstellen → Push.
3. GitHub Pages für das Repo aktivieren (Settings → Pages).
4. Falls die tatsächliche Maschinenzahl/-namen im Waschraum abweicht: `MACHINES`-Array
   oben in `index.html` anpassen.
