# Cards Market

Virtueller Sammelkarten-Marktplatz von Samira Tesan. Benutzer ziehen Karten aus
Packs, verwalten ihre Sammlung, verbessern Ranks und handeln mit virtuellen Coins.

Die vollständige [Projektdokumentation](docs/projektstand.md) beschreibt
Funktionen, Spielregeln, Rollen, Datenmodell, Transaktionen, Sicherheit und den
belegten Performance-Stand. Diese README enthält die technische Einstiegshilfe.

## Implementierte Funktionen

- Registrierung, Login, Logout und serverseitige Sitzungen.
- 1.000 Start-Coins, einmaliges kostenloses Starter-Pack mit drei Karten und weitere konfigurierbare Packs.
- Kartentypen mit fünf Seltenheitsstufen und optionalem HTTPS-Bildlink; einzelne Karten mit Rank E bis SS.
- Inventar mit auf- und absteigender Sortierung nach Ziehdatum, Name, Seltenheit, Rank oder Kartenwert; eigene Kartendetails mit Rank-Pulls und den letzten zehn eigenen Pulls je Karte.
- Eigene Verkaufspreise, Kaufbestätigung mit Karten- und Guthabendetails, Kauf-Fehleransicht und Zurückziehen; Filter nach Name, Seltenheit und Rank.
- Live-Verkaufsnachrichten und Entfernung verkaufter oder zurückgezogener Angebote über Action Cable.
- Admin-Panel mit Policy-Klassen für Katalog, Rollen, Kontosperren, Coins-Gutschriften, Angebotsmoderation und Änderungsprotokoll.
- Direkte Aktivierung/Deaktivierung von Kartentypen; Löschen nur ohne vorhandene Karten dieses Typs.

Ein deaktivierter Kartentyp wird nicht mehr neu aus Packs gezogen. Bereits
vorhandene Karten bleiben handelbar. Ein Angebot darf einmal gekauft werden;
der neue Besitzer kann die Karte anschließend erneut anbieten.

## Technischer Stand

| Bestandteil | Im Repository |
| --- | --- |
| Ruby | 4.0.6 laut `.ruby-version` |
| Rails | 8.1.3.1 laut `Gemfile.lock` |
| Datenbank | PostgreSQL |
| Webserver | Puma |
| Oberfläche | ERB, CSS, Turbo und Stimulus, JavaScript über Importmap |
| Live-Verbindungen | Action Cable; lokal async, Produktion Solid Cable |
| Passwörter | BCrypt über `has_secure_password` |
| Produktions-Cache / Jobs | Solid Cache / Solid Queue |

JSON ist in der Gemfile auf die 2.21-Reihe mit mindestens 2.21.2 begrenzt; die
Lockdatei enthält 2.21.2. Der Code dokumentiert dies als Kompatibilitätsanpassung
für die JSON-Aufrufe der verwendeten Rails-Version.

## Lokal starten

Die folgenden Befehle werden im Projektordner unter Ubuntu/WSL ausgeführt.
Benötigt werden Ruby in der angegebenen Version, Bundler und laufendes PostgreSQL
mit den Voraussetzungen für das `pg`-Gem.

`config/database.yml` verwendet lokal standardmäßig die PostgreSQL-Rolle des
Betriebssystembenutzers über einen Unix-Socket. Diese Rolle muss auf die
Datenbanken zugreifen und sie für das initiale Setup erstellen dürfen.
Entwicklung und Tests verwenden getrennte Datenbanken:
`brainrot_market_development` und `brainrot_market_test`.

```sh
bundle install
bin/rails db:prepare
bin/rails db:seed
bin/rails server
```

Anschließend im Browser [localhost:3000](http://localhost:3000) öffnen und ein
Konto registrieren. Wer noch nicht angemeldet ist, wird zum Login weitergeleitet.
Das Starter-Pack wird auf der Pack-Seite per Button geöffnet.

Falls Ruby über mise installiert ist und die Shell es noch nicht aktiviert hat:

```sh
~/.local/bin/mise exec -- bundle install
~/.local/bin/mise exec -- bin/rails db:prepare
~/.local/bin/mise exec -- bin/rails db:seed
~/.local/bin/mise exec -- bin/rails server
```

Für eine bestehende Installation nach neuen Migrationen:

```sh
bin/rails db:migrate
bin/rails db:seed
```

Die Seeds ergänzen nach Namen fehlende Einträge und leere Bildfelder. Sie überschreiben keine vorhandenen
Einstellungen. Sie erstellen die sechs Ranks, 18 Kartentypen mit Online-Bildlinks, das
Starter-Pack und ein Anfänger-Pack mit 100 Coins Preis und drei Karten.
Sie erstellen keine Benutzer. Alle Seed-Spielwerte und Ziehregeln stehen in der
[Projektdokumentation](docs/projektstand.md).

## Ersten Admin einrichten

Zuerst das gewünschte Konto regulär registrieren. Dann dessen Benutzernamen
einsetzen:

```sh
ADMIN_USERNAME=vorhandener_benutzername bin/rails admin:bootstrap
```

Der Befehl funktioniert nur, solange kein aktiver Admin existiert, und lehnt
gesperrte Zielkonten ab. Danach erneut anmelden und `/admin` öffnen.
Weitere Admins werden im Benutzerbereich des Panels vergeben.

Unter **Admin → Kartentypen** lassen sich Typen direkt deaktivieren und wieder
aktivieren. **Bearbeiten** öffnet die Felder für Name, Beschreibung, Seltenheit,
Grundwert, Bildlink und Aktivstatus. Unbenutzte Typen können mit Bestätigung
gelöscht werden. Mindestens ein aktiver Admin muss erhalten bleiben.

## Coins im Admin-Panel vergeben

Unter **Admin → Benutzer → Coins vergeben** das gewünschte Konto auswählen und
einen positiven Betrag in ganzen Coins eintragen. Eine Begründung mit maximal
250 Zeichen ist optional. **Coins gutschreiben** addiert den Betrag zum
bestehenden Guthaben. Dabei entstehen neue virtuelle Coins; das Konto des
ausführenden Admins wird nicht belastet. Auch das eigene Konto kann Coins erhalten.

Nur aktive Admins dürfen Gutschriften ausführen. Betrag, Guthaben vorher/nachher,
Zielkonto, ausführender Admin und Begründung werden im Änderungsprotokoll erfasst.
Gutschrift und Protokolleintrag werden gemeinsam gespeichert oder gemeinsam
zurückgerollt. Gleichzeitige Gutschriften werden über Datenbanksperren abgesichert.
Das Guthaben darf höchstens 2.147.483.647 Coins betragen.
Empfänger sehen ihr neues Guthaben beim nächsten Laden der Seite.

## Wichtige Seiten und Routen

| Methode und Pfad | Funktion |
| --- | --- |
| `GET /registration/new`, `POST /registration` | Registrierung |
| `GET /session/new`, `POST /session` | Login |
| `DELETE /session` | Logout |
| `GET /` | Geschütztes Dashboard |
| `GET /packs/index` | Aktive Packs und Seltenheitschancen |
| `POST /packs/:id/open` | Pack öffnen |
| `GET /pack_openings/:id` | Eigenes Pack-Ergebnis |
| `GET /inventory/index` | Eigenes Inventar |
| `GET /brainrot_cards/:id` | Eigene Kartendetails |
| `POST /brainrot_cards/:brainrot_card_id/rank_pulls` | Rank-Pull |
| `GET /marketplace/index` | Marktplatz; Filter `q`, `rarity`, `rank`, Seite `page` |
| `GET /brainrot_cards/:brainrot_card_id/market_offers/new`, `POST /brainrot_cards/:brainrot_card_id/market_offers` | Angebot erstellen |
| `POST /market_offers/:id/purchase` | Angebot kaufen |
| `DELETE /market_offers/:id` | Eigenes Angebot zurückziehen |
| `GET /admin` | Admin-Übersicht |
| `POST /admin/users/:id/credit_coins` | Coins gutschreiben (nur Admins) |
| `/cable` | WebSocket-Endpunkt |
| `GET /up` | Rails-Healthcheck |

Die vollständige Routenliste einschließlich der Admin-Unterseiten:

```sh
bin/rails routes
```

## Code und Datenmodell

| Verzeichnis / Datei | Aufgabe |
| --- | --- |
| `app/models` | Active-Record-Modelle, Beziehungen und Validierungen |
| `db/migrate`, `db/schema.rb` | Schema, Fremdschlüssel, Indizes und Check-Constraints |
| `db/seeds.rb` | Start-Katalog und anfängliche Spielwerte |
| `app/services` | Transaktionale Spielaktionen, gewichtete Ziehungen und Broadcasts |
| `app/policies` | Eigene Policy-Klassen für Admin-, Benutzer- und Kartenzugriff |
| `app/controllers` | HTTP-Aktionen, Anmeldung und auf Benutzer eingeschränkte Abfragen |
| `app/channels` | Authentifizierte WebSocket-Verbindungen und Kanäle |
| `app/views`, `app/javascript/controllers` | Seiten und Stimulus-Interaktionen |
| `test` | Modell-, Service-, Controller-, Policy- und Kanaltests |
| `script/marketplace_load_test.rb` | Lokaler HTTP-Lasttest |

Die zehn fachlichen Modelle sind `User`, `Session`, `BrainrotType`, `Rank`,
`BrainrotCard`, `Pack`, `PackOpening`, `MarketOffer`, `RankPull` und
`AdminActivity`. `Current` hält den Kontext der aktuellen Anfrage und ist keine
Datenbanktabelle. Das ERM und die Beziehungen stehen in der
[Projektdokumentation](docs/projektstand.md).

## Live-Handel ausprobieren

1. Zwei Konten in getrennten Browser-Profilen oder in einem normalen und einem privaten Fenster anmelden.
2. Mit Konto A ein Pack öffnen und eine Karte zu einem für Konto B bezahlbaren Preis anbieten.
3. Mit beiden Konten die Marktplatz-Seite geöffnet halten.
4. Mit Konto B das Angebot kaufen.
5. Bei Konto A erscheinen die Verkaufsnachricht und das aktualisierte Guthaben. Das Angebot verschwindet aus beiden geöffneten Marktplatz-Listen.
6. Nach Aufrufen des Inventars liegt die Karte bei Konto B.

Lokal müssen HTTP-Kauf und WebSocket-Verbindung denselben Rails-Prozess verwenden,
weil der async-Adapter keine Ereignisse zwischen separaten Prozessen verteilt.
Nach einem Verbindungsabbruch gleicht der Marktplatz die sichtbaren Angebote
beim Wiederverbinden ab. Nachrichten während der Abwesenheit haben keinen
gespeicherten Posteingang. Neu eingestellte Angebote erscheinen nach Neuladen.

## Prüfen

Die Tests laufen in der getrennten Testdatenbank.

```sh
PARALLEL_WORKERS=2 bin/rails test
bin/rubocop
bin/brakeman --no-pager
bin/bundler-audit
bin/rails zeitwerk:check
```

**In diesem Dokumentationsabgleich am 24. September 2026 ausgeführt:**
`PARALLEL_WORKERS=2 bin/rails test` mit **168 Tests, 1.116 Assertions,
0 Fehlern, 0 fehlgeschlagenen Tests und 0 übersprungenen Tests**.
Die weiteren Befehle sind Prüfanleitungen; sie wurden bei diesem
Dokumentationsabgleich nicht erneut ausgeführt.

Der separate Lasttest:

```sh
RAILS_ENV=test bundle exec ruby script/marketplace_load_test.rb
```

Nicht gleichzeitig mit der Testsuite ausführen. Das Skript startet einen
temporären Server, erzeugt und entfernt seine Testdaten und überschreibt
`docs/marketplace-load-test.json`. Es scheitert, wenn eine gemessene Anfrage
nicht erfolgreich ist oder mindestens zwei Sekunden dauert.

Der vorhandene Bericht vom 24. September 2026 misst 300 HTTP-Anfragen von zehn
gleichzeitig anfragenden Konten bei insgesamt 1.001 aktiven Angeboten. Die
langsamste Antwort dauerte 0,475 Sekunden. Dieser Lasttest wurde für die
Dokumentationsänderung nicht erneut ausgeführt. Bedingungen und Grenzen:
[Performance-Nachweis](docs/projektstand.md) und
[Rohdaten](docs/marketplace-load-test.json).

## Produktionskonfiguration und Grenzen

Die Anwendung erzwingt in Produktion HTTPS. Für eine Veröffentlichung müssen
Deployment-Ziel, Datenbankzugänge, Secrets, Proxy und WebSocket-Upgrades passend
eingerichtet werden. `config/deploy.yml` enthält noch Beispielwerte und belegt
keine einsatzbereite Bereitstellung.

Die Produktionskonfiguration sieht Datenbanken für primary, cache, queue und
cable vor. Diese müssen vorbereitet und erreichbar sein. Für Hintergrundjobs
muss ein Solid-Queue-Worker laufen.

Eine Passwort-vergessen-Funktion ist nicht vorhanden. Reset-Routen, Mailvorlagen
und die Generierung von Passwort-Reset-Tokens sind entfernt beziehungsweise deaktiviert.

Kartenbilder können hochgeladen oder als externe HTTPS-Links eingebunden werden.
Es gibt keine Echtgeldzahlung und keinen Coin-Kauf gegen Geld. Die
lokalen Tests und HTTP-Messwerte sind kein Nachweis einer vollständigen
Produktionsprüfung.

## Kartenbilder und Katalog

Der Standardkatalog enthält 18 Kartentypen. Bilder füllen die komplette Bildfläche mit zentriertem Zuschnitt; Rank und Seltenheit bleiben darüber sichtbar. Eigene Bildlinks und bestehende Deaktivierungen bleiben beim Seeden erhalten. Leere Bildfelder von Standardtypen werden ergänzt. [Bildquellen und Details](docs/card-image-sources.md).

## Eigene Kartenbilder hochladen

Unter **Admin → Kartentypen → Neuer Eintrag / Bearbeiten** können PNG-, JPG- und
WebP-Dateien vom eigenen Rechner ausgewählt werden (maximal 5 MB). Die Vorschau
erscheint vor dem Speichern. Gespeicherte Uploads haben Vorrang vor dem optionalen
HTTPS-Bildlink. Eine neue Datei ersetzt den bisherigen Upload. Über
**Hochgeladenes Bild entfernen** wird wieder der Bildlink verwendet; ohne Link
erscheint die Ersatzgrafik. Nach einem Formularfehler muss eine neue Datei erneut
ausgewählt werden.

Dateityp und Größe werden serverseitig geprüft. Uploads, Ersetzungen und
Entfernungen sind nur im Admin-Bereich möglich und werden protokolliert.
Die Bilder werden über Rails Active Storage gespeichert: lokal unter
`storage/`, in Tests unter `tmp/storage/`. Zusätzlich bestehen die Tabellen
`active_storage_blobs`, `active_storage_attachments` und
`active_storage_variant_records`; Bildvarianten werden derzeit nicht verwendet.

Für bestehende Installationen ist `bin/rails db:migrate` notwendig. Bei einem
Deployment müssen sowohl Datenbank als auch der konfigurierte Dateispeicher
dauerhaft erhalten und gesichert werden. Die aktuelle Konfiguration verwendet
auch in Produktion lokalen Disk-Speicher.

## Projektname

Die Anwendung heißt **Cards Market**, die Rails-Anwendungsklasse ist
`CardsMarket::Application`. Vorhandene Datenbanknamen, Datenbank-Zugangsdaten,
das Storage-Volume und die internen Modelle behalten ihre bisherigen technischen
Bezeichnungen, damit vorhandene Konten, Karten und Uploads weiterhin verfügbar
sind. Der lokale Projektordner kann weiterhin `brainrot_market` heißen.
