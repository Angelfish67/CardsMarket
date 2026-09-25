# Cards Market

Virtueller Sammelkarten-Marktplatz von Samira Tesan. Benutzer ziehen Karten aus
Packs, verwalten und sortieren ihr Inventar, verbessern Ranks und handeln mit
virtuellen Coins. Admins verwalten den Katalog, Konten, Angebote und Gutschriften.
Verkäufe werden über WebSockets gemeldet; verkaufte Angebote verschwinden live.

Diese README beschreibt die Einrichtung und das Ausführen einer lokalen Kopie.
Ergänzende Nachweise stehen unter [docs/](docs/):
[Bildquellen und Katalog](docs/card-image-sources.md) und
[Performance-Messbericht](docs/marketplace-load-test.json).
Eine separate fachliche Projektdokumentation mit KN-/MVP-Abgleich, ERM und
Wireframes ist in dieser Kopie nicht enthalten und muss für eine entsprechende
Abgabe separat unter `docs/` ergänzt werden.

## Technologie-Stack

| Bestandteil | Version / Konfiguration |
| --- | --- |
| Ruby | 4.0.6 gemäß `.ruby-version` |
| Bundler | 4.0.21 gemäß `Gemfile.lock` |
| Ruby on Rails | 8.1.3.1 |
| PostgreSQL | Lokal geprüft mit 18.6; Serverversion nicht im Projekt festgeschrieben |
| PostgreSQL-Gem `pg` | 1.6.3 |
| Puma | 8.0.2 |
| Oberfläche | ERB, CSS, Turbo und Stimulus |
| Hotwire-Gems | `turbo-rails` 2.0.23, `stimulus-rails` 1.3.4 |
| Assets / JavaScript | Propshaft 1.3.2, Importmap Rails 2.2.3 |
| Authentifizierung | BCrypt 3.1.22, serverseitige Sitzungen |
| WebSockets / Uploads | Action Cable / Active Storage aus Rails 8.1.3.1 |
| Tests | Minitest 6.0.6 |

Die verbindlichen Gem-Versionen stehen in [Gemfile.lock](Gemfile.lock).
JSON ist auf die kompatible 2.21-Reihe begrenzt; installiert wird 2.21.2.
Die Anwendungsklasse heißt `CardsMarket::Application`. Interne Modellnamen und
Datenbanknamen verwenden weiterhin `brainrot` beziehungsweise `brainrot_market`.

## Voraussetzungen

Die folgende Anleitung verwendet **Ubuntu 24.04**, unter Windows über **WSL 2**.
Die Systempakete liefern die PostgreSQL-Version der verwendeten Ubuntu-Version.
Ruby wird separat in der oben angegebenen Version installiert.

Benötigt werden ein aktueller Browser, Internet für die Installation und externe
Kartenbilder sowie Berechtigungen zum Installieren der Systempakete.
Node.js, npm, Yarn, Redis, Docker und ein Mailserver sind für den lokalen Start
nicht erforderlich. Die Anwendung verwendet lokal einen Rails-Prozess und
PostgreSQL; Uploads liegen auf dem Dateisystem.

## Installation mit einer frischen Kopie

### 1. Ubuntu öffnen oder unter Windows installieren

Wer bereits Ubuntu verwendet, beginnt mit Schritt 2. Andernfalls in
**PowerShell als Administrator** ausführen:

```powershell
wsl --install -d Ubuntu-24.04
```

Falls verlangt, Windows neu starten. Danach **Ubuntu 24.04** im Startmenü öffnen
und einen Linux-Benutzernamen mit Passwort festlegen. Bei `sudo` wird dieses
Passwort benötigt; während der Eingabe erscheinen keine Zeichen.

**Alle folgenden Befehle im Ubuntu-Terminal ausführen, nicht in PowerShell.**
Siehe [offizielle WSL-Anleitung](https://ubuntu.com/wsl/docs/latest/howto/install-ubuntu-wsl2/).

### 2. Systempakete installieren

```bash
sudo apt update
sudo apt install -y curl git build-essential rustc pkg-config \
  libssl-dev libyaml-dev zlib1g-dev libgmp-dev libreadline-dev libffi-dev \
  postgresql postgresql-contrib libpq-dev
```

Die Compiler und Bibliotheken werden für Ruby und native Gems benötigt.
`libpq-dev` stellt die PostgreSQL-Entwicklungsdateien bereit.
Die Ruby-Voraussetzungen orientieren sich an der
[offiziellen Rails-Installationsanleitung](https://guides.rubyonrails.org/install_ruby_on_rails.html).

### 3. Ruby und Bundler einrichten

Wenn der Versionsmanager mise noch nicht installiert und in Bash aktiviert ist:

```bash
curl -fsSL https://mise.run | sh
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
source ~/.bashrc
```

Die Zeile für `~/.bashrc` nur einmal hinzufügen. Anschließend:

```bash
mise use --global ruby@4.0.6
gem install bundler -v 4.0.21
ruby --version
bundle --version
```

Die Ausgaben sollen Ruby **4.0.6** und Bundler **4.0.21** zeigen. Die Installation
kann einige Minuten dauern. Der mise-Befehl setzt die Standard-Ruby-Version des
Linux-Benutzers. Wer bereits einen anderen Versionsmanager verwendet, kann damit
dieselbe Version auswählen. Weitere Hinweise: [mise-Einrichtung](https://mise.jdx.dev/getting-started).

### 4. ZIP entpacken und Projektordner öffnen

Das ZIP vollständig entpacken, einschließlich versteckter Dateien wie
`.ruby-version`. Für diese Anleitung den eigentlichen Projektordner
`cards_market` nennen und unter `~/code/` ablegen:

```bash
mkdir -p ~/code
```

Unter Windows lässt sich der entpackte Ordner über den Explorer nach
`\\wsl.localhost\Ubuntu-24.04\home\DEIN_UBUNTU_NAME\code` kopieren.
`DEIN_UBUNTU_NAME` durch den Linux-Benutzernamen ersetzen. Anschließend:

```bash
cd ~/code/cards_market
ls -a
chmod u+x bin/*
```

Hier müssen `Gemfile`, `Gemfile.lock`, `.ruby-version` sowie `app/`, `config/` und
`db/` liegen. Bei einem zusätzlichen äußeren ZIP-Ordner entsprechend tiefer
wechseln. Der Ordner darf auch anders heißen; dann alle `cd`-Befehle anpassen.
`chmod` stellt gegebenenfalls beim Entpacken verlorene Ausführungsrechte wieder her.

### 5. PostgreSQL einrichten

```bash
sudo service postgresql start
sudo -u postgres createuser --createdb --no-superuser --no-createrole "$(whoami)"
psql -d postgres -c 'SELECT current_user;'
```

Die Rolle nur einmal erstellen. Wenn sie bereits existiert, `createuser`
überspringen; sie benötigt Login- und `CREATEDB`-Rechte.
Der letzte Befehl sollte den Linux-Benutzernamen als Datenbankbenutzer ausgeben.
Siehe [PostgreSQL: createuser](https://www.postgresql.org/docs/17/app-createuser.html).

[config/database.yml](config/database.yml) verbindet sich lokal über einen
Unix-Socket mit einer PostgreSQL-Rolle gleichen Namens wie der Linux-Benutzer.
Bei dieser Einrichtung braucht es weder Datenbankpasswort noch `.env`-Datei
oder Änderungen an der Datenbankkonfiguration. Rails ohne `sudo` ausführen.

### 6. Gems, Datenbank und Demo-Katalog vorbereiten

Im Projektordner:

```bash
bundle install
bin/rails db:prepare
bin/rails db:seed
```

`bundle install` installiert Rails und alle Gems gemäß Lockdatei. Eine zusätzliche
globale Rails-Installation ist nicht nötig. `db:prepare` erstellt fehlende
Datenbanken und Tabellen und führt ausstehende Migrationen aus. Die Struktur
steht in [db/schema.rb](db/schema.rb), Änderungen unter [db/migrate/](db/migrate/).

Die getrennten lokalen Datenbanken heißen:

- `brainrot_market_development` für die Anwendung.
- `brainrot_market_test` für automatisierte Tests.

Auf einer neuen Datenbank lädt `db:prepare` bereits Seeds. Der zusätzliche
Seed-Befehl ergänzt den Katalog auch in einer vorhandenen Datenbank.
[db/seeds.rb](db/seeds.rb) erstellt sechs Ranks, 18 Kartentypen mit externen
Bildlinks, das kostenlose Starter-Pack mit drei Karten und das Anfänger-Pack
mit drei Karten für 100 Coins. Fehlende Einträge und leere Bildlinks werden
ergänzt; bestehende Katalogeinstellungen bleiben erhalten.

**Die Seeds erstellen keine Benutzer.** Dafür entweder die optionalen
Demo-Konten im nächsten Abschnitt anlegen oder nach dem Start selbst registrieren.

### 7. Server starten

```bash
bin/rails server
```

Das Terminal geöffnet lassen und [localhost:3000](http://localhost:3000) im Browser
aufrufen. Mit einem Demo-Konto anmelden oder **Registrieren** wählen. Neue Konten
erhalten 1.000 Coins; das Starter-Pack kann auf der Pack-Seite einmal geöffnet
werden. Registrierungen benötigen einen eindeutigen Benutzernamen, eine gültige
E-Mail-Adresse und ein Passwort mit mindestens zwölf Zeichen und maximal 72 Bytes.

**Strg+C** beendet den Server. Konten, Karten, Coins und Uploads bleiben erhalten.
Für einen späteren Start genügen:

```bash
cd ~/code/cards_market
sudo service postgresql start
bin/rails server
```

Nach Projektupdates vor dem Serverstart erneut `bundle install`,
`bin/rails db:prepare` und `bin/rails db:seed` ausführen.

## Demo-Konten und Rollen

Die folgenden Konten sind **nicht vorinstalliert**. Auf einer frischen lokalen
Entwicklungsdatenbank können sie nach Schritt 6 einmalig angelegt werden.
In einem Ubuntu-Terminal im Projektordner den vollständigen Block ausführen:

```bash
bin/rails runner - <<'RUBY'
abort "Nur für die lokale Entwicklungsdatenbank." unless Rails.env.development?

User.transaction do
  User.create!(
    username: "demo_admin", email_address: "admin@example.test",
    password: "DemoAdmin-2026!", password_confirmation: "DemoAdmin-2026!",
    role: :admin
  )
  User.create!(
    username: "demo_trader", email_address: "trader@example.test",
    password: "DemoTrader-2026!", password_confirmation: "DemoTrader-2026!",
    role: :trader
  )
end
RUBY
```

| Benutzername | Login-E-Mail | Passwort | Rolle |
| --- | --- | --- | --- |
| `demo_admin` | `admin@example.test` | `DemoAdmin-2026!` | Admin: Sammlung und Handel sowie Verwaltung, Moderation und Coins-Gutschriften |
| `demo_trader` | `trader@example.test` | `DemoTrader-2026!` | Trader: eigenes Inventar, Packs, Handel und eigene Kontoverwaltung; kein Admin-Zugriff |

Beide starten mit 1.000 Coins und ungeöffnetem Starter-Pack. Die Zugangsdaten
sind öffentlich und ausschließlich für eine lokale Demo gedacht. Den Block
nicht wiederholt ausführen: Bereits vorhandene Namen oder E-Mail-Adressen
führen zu einem Validierungsfehler, ohne bestehende Konten zu überschreiben.

**Alternative ohne Demo-Konten:** Ein Konto im Browser registrieren und in einem
zweiten Ubuntu-Terminal im Projektordner dessen Benutzernamen einsetzen:

```bash
ADMIN_USERNAME=dein_benutzername bin/rails admin:bootstrap
```

Das funktioniert nur, solange kein aktiver Admin existiert. Danach erneut
anmelden. Weitere Rollen werden unter **Admin → Benutzer** vergeben.

### Kurzer Funktionstest im Browser

1. Die beiden Demo-Konten in getrennten Browser-Profilen oder einem normalen und einem privaten Fenster anmelden.
2. Mit beiden Konten ein Starter-Pack öffnen.
3. Mit dem Trader eine Karte aus dem Inventar zum Verkauf anbieten.
4. Mit dem Admin das Angebot auf dem Marktplatz kaufen.
5. Der Trader erhält die Verkaufsnachricht und Coins; das Angebot verschwindet in beiden Marktplatz-Ansichten. Die Karte liegt anschließend im Inventar des Käufers.
6. Mit dem Trader `/admin` öffnen: Der Zugriff muss verweigert werden. Mit dem Admin ist die Verwaltung zugänglich.

Einstiegspunkte: `/` (Dashboard), `/packs/index`, `/inventory/index`,
`/marketplace/index`, `/account/edit` und `/admin`.
Alle technischen Routen zeigt `bin/rails routes`.

## Automatisierte Tests und Qualitätsprüfungen

Im Ubuntu-Terminal im Projektordner bei laufendem PostgreSQL:

```bash
bin/rails db:test:prepare
PARALLEL_WORKERS=2 bin/rails test
bin/rubocop
bin/rails zeitwerk:check
```

Tests verwenden Fixtures und die separate Testdatenbank; die Demo-Konten werden
dafür nicht benötigt. Die Testdatenbank darf keine aufzubewahrenden Daten
enthalten. Die Standardkonfiguration aus dieser Anleitung verwendet keine
`DATABASE_URL`. Eine selbst gesetzte URL darf Tests niemals auf eine
Entwicklungs- oder Produktionsdatenbank umleiten.

Die Tests unter [test/](test/) prüfen unter anderem:

- Starter-Pack nur einmal, bezahlte Packs und Rank-Pulls mit korrekter Coin-Abrechnung.
- Kauf überträgt genau einmal Karte und Preis; fehlende Coins und gleichzeitige Käufe führen zu keinem doppelten Verkauf.
- Erlaubte und verweigerte Zugriffe für Gäste, Eigentümer, fremde Benutzer und Admins über Policy-Klassen und Controller.
- Validierungen, CSRF-Schutz, Passwortwechsel, Sitzungsentzug und Erhalt mindestens eines aktiven Admins.
- Fehlerfälle und Rollbacks, Formularausgaben, Uploads sowie WebSocket-Nachrichten.

**Geprüfter Stand vom 25. September 2026:**
`PARALLEL_WORKERS=2 bin/rails test` besteht mit **205 Tests, 1.587 Assertions,
0 fehlgeschlagenen Tests, 0 Fehlern und 0 übersprungenen Tests**.
`bin/rubocop` prüft **162 Dateien ohne Verstöße**.
Diese Ergebnisse gelten für die geprüfte lokale Umgebung; vor der Abgabe
die Befehle mit dem abzugebenden Stand erneut ausführen.

Weitere Sicherheitsprüfungen, hier als Befehle dokumentiert:

```bash
bin/brakeman --no-pager
bin/bundler-audit
bin/importmap audit
```

Die Audit-Befehle können Internetzugriff benötigen und wurden für diese
README-Änderung nicht erneut ausgeführt. Die CI-Konfiguration steht unter
[.github/workflows/ci.yml](.github/workflows/ci.yml). Aktuell enthält `test/` keine
ausführbaren Systemtests; die Controller- und Integrationstests laufen über
`bin/rails test`. Ein vorhandener CI-Schritt `test:system` ist daher allein
kein Nachweis automatisierter Browsertests.

### Code-Konventionen und Fehlerbehandlung

Die Anwendung verwendet die Rails-Verzeichnis- und Namenskonventionen.
Controller verarbeiten Anfragen, Modelle validieren Daten, Policy-Klassen prüfen
Berechtigungen, und Services kapseln Spielaktionen mit Transaktionen und
Datenbanksperren. Der Stil wird über
[.rubocop.yml](.rubocop.yml) mit `rubocop-rails-omakase` geprüft.

Erwartete Fehler wie ungültige Formulardaten, fehlende Coins oder ein inzwischen
verkauftes Angebot werden serverseitig behandelt. Formulare zeigen Fehler an;
normale Eingaben bleiben soweit möglich erhalten. Passwörter und neue
Upload-Dateien müssen nach einem Fehler erneut eingegeben beziehungsweise
ausgewählt werden. Fehlgeschlagene Käufe bieten eine Rückkehr zum Marktplatz,
erfolgreiche Änderungen eine Bestätigung. Fehlende Berechtigungen ergeben je
nach Bereich eine Anmeldung, eine Zugriffsverweigerung oder eine Nicht-gefunden-Antwort.

Diese Anleitung startet ausdrücklich den Entwicklungsmodus: Unerwartete
technische Fehler können dort Rails-Diagnoseseiten anzeigen. Die lokale
Entwicklungsinstanz ist nicht als öffentliches Produktionssystem gedacht.
Eine vollständige Erfüllung der KN- und MVP-Anforderungen muss zusätzlich anhand
der fachlichen Projektdokumentation und der Abnahmekriterien belegt werden.

### Optionaler Lasttest

```bash
RAILS_ENV=test bundle exec ruby script/marketplace_load_test.rb
```

Nicht gleichzeitig mit der Testsuite ausführen. Das Skript startet einen
temporären Server, erzeugt und entfernt Testdaten und schreibt den
[Messbericht](docs/marketplace-load-test.json) neu.
Der vorhandene Bericht vom 24. September 2026 erfasst 300 lokale HTTP-Anfragen
mit zehn gleichzeitig anfragenden Konten. Er wurde bei dieser README-Änderung
nicht neu erzeugt; Browserdarstellung und externe Bilder werden nicht gemessen.

## Bilder und vorhandene Daten übernehmen

Ein Quellcode-ZIP enthält **nicht automatisch die PostgreSQL-Datenbank** des
ursprünglichen Rechners. Konten, Inventare, Guthaben und nachträglich im Admin-Panel
angelegte Kartentypen werden durch die Seeds nicht wiederhergestellt.

Standardkarten verwenden externe HTTPS-Bilder und benötigen dafür Internet.
Uploads werden lokal unter `storage/` gespeichert. Dieser Inhalt ist in Git
ausgeschlossen und fehlt normalerweise in einem Repository-Download. Ein
manuell erstelltes ZIP kann ihn enthalten. Zur Übernahme bisheriger Uploads
braucht es **sowohl die Bilddateien als auch die passenden Datenbankeinträge**.
Dafür müssen eine Datenbanksicherung und der zugehörige `storage/`-Inhalt
separat mitgegeben und wiederhergestellt werden; der Bildordner allein genügt nicht.

Auf einer frischen Installation können Admins unter **Admin → Kartentypen**
eigene PNG-, JPG- oder WebP-Dateien bis 5 MB hochladen. Uploads haben Vorrang
vor einem hinterlegten Bildlink. Eine Bildbearbeitungs-Pipeline wird derzeit
nicht verwendet. Quellen des Standardkatalogs: [Bilddokumentation](docs/card-image-sources.md).

## Häufige Startprobleme

| Problem | Nächster Schritt |
| --- | --- |
| `ruby`, `bundle` oder `mise` fehlt / falsche Version | Ubuntu-Terminal verwenden, `source ~/.bashrc` ausführen und Schritt 3 prüfen. |
| PostgreSQL-Rolle fehlt | Rolle gemäß Schritt 5 anlegen; Rails ohne `sudo` starten. |
| Keine Berechtigung zum Erstellen der Datenbank | Der Datenbank-Administrator muss der Rolle `CREATEDB` gewähren. |
| PostgreSQL nicht erreichbar | `sudo service postgresql start` und den Verbindungstest aus Schritt 5 ausführen. |
| `pg_config` fehlt / `pg` lässt sich nicht installieren | `sudo apt install libpq-dev build-essential` und danach erneut `bundle install`. |
| `Permission denied` bei `bin/rails` | Im Projektordner `chmod u+x bin/*` ausführen. |
| Tabellen fehlen / Migrationen ausstehend | `bin/rails db:prepare` ausführen. |
| Keine Packs oder Kartentypen | `bin/rails db:seed` ausführen. |
| Port 3000 belegt | Vorherigen Server mit Strg+C stoppen oder `bin/rails server -p 3001` starten und `http://localhost:3001` öffnen. |
| Kein Admin-Zugriff | Demo-Admin anmelden oder den ersten Admin wie oben einrichten; nach Rollenänderungen neu anmelden. |
| Eigene Bilder fehlen | Passende Datenbanksicherung und `storage/`-Dateien übernehmen oder die Bilder neu hochladen. |

## Grenzen der lokalen Einrichtung

Ein kostenloses Starter-Pack ist nur einmal pro Konto möglich. Ein deaktiviertes
Konto kann nur ein Admin reaktivieren; es gibt keine Passwort-vergessen-Funktion.
Für WebSocket-Ereignisse verwendet die Entwicklung den `async`-Adapter im selben
Rails-Prozess. Neue Angebote erscheinen nach Neuladen; verkaufte oder
zurückgezogene Angebote werden live entfernt.

Die vorhandenen Docker-/Kamal-Dateien beschreiben eine separate
Produktionskonfiguration und enthalten noch anzupassende Werte. Ein öffentliches
Deployment benötigt unter anderem HTTPS, eigene Secrets, Datenbankzugänge,
dauerhaften Dateispeicher und die konfigurierten Solid-Dienste. Es ist nicht
Bestandteil dieser lokalen Startanleitung.
