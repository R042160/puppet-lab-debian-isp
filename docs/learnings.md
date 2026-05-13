# Lernnotizen – puppet-lab-debian-isp

Ehrliche Notizen aus dem Lernprozess. Wird laufend erweitert.

## v0 – Setup (Mai 2026)

### Was gut funktioniert hat

- **`puppet apply` reicht für den Anfang.** Ein Master/Agent-Setup hätte zwei Container und mehr Netzwerk-Komplexität erfordert. Mit `--modulepath` läuft alles aus dem gemounteten `modules/`-Verzeichnis.
- **Idempotenz prüfen ist trivial:** den zweiten Lauf in `apply.sh` mit erwartetem „0 events"-Output. Wenn beim zweiten Lauf Events auftauchen, ist eine Resource nicht idempotent (häufig: `exec` ohne `unless`/`onlyif`). Ab v0.3 nutzt `apply.sh` `--detailed-exitcodes`, damit Puppet-Fehler nicht still durchrutschen.
- **Resource relationships** mit `require`/`notify`/`subscribe` machen die Manifeste lesbar wie ein DAG.

### Wo es geknackt hat

- **Postfix interaktiv:** ohne `debconf-set-selections` blockiert `apt install postfix` mit einer Auswahl-Maske. Lösung: ein `exec` mit `unless`-Guard, der `mailer_type` und `mailname` vorab seedet.
- **DHCP ohne Interface:** `isc-dhcp-server` startet im Lab-Container nicht sauber, weil keine echte Schnittstelle gebunden ist. Ab v0.3 wird der Service im Docker-Lab deshalb per Hiera nicht gemanagt; ein echter Node kann `manage_service: true` setzen.
- **systemd in Docker:** ohne `privileged: true` und `tmpfs:/run` funktioniert `systemctl` nicht innerhalb des Containers. Für ein Lab akzeptabel; Produktion → Vagrant + echte VM.

### Nächste Schritte

1. **Hiera einführen** – Daten (Subnet, Range, Hostname) aus den `.pp`-Files raus, in `data/common.yaml`.
2. **PDK** – jedes Modul mit `pdk new module` neu anlegen, damit `metadata.json` + Standardstruktur stimmen.
3. **rspec-puppet** – minimaler Test pro Modul: „beim Compile darf nichts crashen, die Klasse muss vorhanden sein".
4. **Master/Agent** – zweiten Container hochziehen, signing flow durchspielen.
5. **Salt-Variante** – dieselben vier Dienste in Salt-States, um beide Paradigmen direkt vergleichen zu können.

## Vergleich Puppet vs eigene Tools (`claude-mesh`)

Mein eigener Tooling-Stack arbeitet bereits konvergent / idempotent (z. B. rsync mit `--delete`, Reconciliation-Skripte mit Guard-Checks). Was Puppet *zusätzlich* bringt:

- **Deklarative DSL** – ein Resource-Typ beschreibt *was*, nicht *wie*.
- **Type system** + Validation – ein falscher Parametertyp scheitert beim Compile, nicht beim ersten Lauf.
- **Reporting / Catalog Compilation** – nachvollziehbar, was wann auf welchem Node geändert wurde.

Das macht Puppet/Salt zum nächsten logischen Schritt nach „Bash-Skripte mit Konvention".

## v0.1 – Hiera-Refactor (Mai 2026)

### Was geändert wurde

- Neues `hiera.yaml` (v5-Format) im Repo-Root mit einer einzelnen `common.yaml`-Ebene.
- Neues `data/common.yaml` mit allen environment-spezifischen Werten (Subnet, Range, Hostnames).
- In den vier `modules/*/manifests/init.pp`:
  - `isp_bind::listen_v6` behält Manifest-Default (`true`) als Fallback – Hiera überschreibt nur, falls vorhanden.
  - `isp_dhcp::*`, `isp_postfix::*`, `isp_nginx::server_name` sind jetzt **mandatory** (kein Manifest-Default). Fehlt der Wert in Hiera, scheitert der `puppet apply` beim Compile – *fail fast* statt späteres Mystery-Debugging.
- `scripts/apply.sh` ruft `puppet apply` jetzt mit `--hiera_config=/lab/hiera.yaml`.
- `Dockerfile` und `docker-compose.yml` mounten `hiera.yaml` + `data/` ins Container-Image.

### Was ich dabei gelernt habe

- **Automatic Parameter Lookup (APL)** ist der eigentliche Punkt von Hiera: Puppet sucht selbständig nach `<class>::<param>` in der Hierarchie, *bevor* der Manifest-Default greift. Kein zusätzlicher `lookup()`-Call nötig.
- **Mandatory vs. Default-mit-Hiera-Override:** beides ist legitim. Mandatory zwingt zur expliziten Konfiguration (gut für Daten, die zwingend zur Umgebung gehören). Default-mit-Override ist resilient (gut für Konfig-Flags mit sensibler Vorgabe). Mischen ist normal.
- **Hierarchie ist der Wert von Hiera:** auch wenn aktuell nur `common.yaml` existiert, ist die Struktur (`hiera.yaml`) der eigentliche Investment. Neue Ebenen (`%{trusted.certname}.yaml`, `%{facts.os.family}.yaml`) lassen sich später ergänzen, ohne die Manifeste anzufassen.

### Was als Nächstes kommt (v0.2)

1. **PDK init** für jedes Modul → saubere `metadata.json`, Standard-Struktur, Spec-Helper.
2. **rspec-puppet** Smoke-Test pro Modul ("class compiles", "Package present").
3. **`puppet-lint` + `metadata-json-lint`** in einer GitHub-Actions-CI.
4. **Per-OS-Hiera-Ebene** (`%{facts.os.distro.codename}.yaml`) zur Vorbereitung auf Multi-Distro-Support (Bookworm vs. Trixie).

## v0.2 – rspec-puppet Smoke-Tests + Modul-Metadaten (Mai 2026)

### Was geändert wurde

- Neues Ruby-Test-Scaffolding im Repo-Root:
  - `Gemfile` + `Gemfile.lock` mit Puppet 8, rspec-puppet, puppet-lint und metadata-json-lint.
  - `.rspec`, `Rakefile`, `spec/spec_helper.rb`.
  - `spec/classes/*_spec.rb` mit einem Smoke-Test pro Modul.
- Jedes Modul hat jetzt ein eigenes `metadata.json` mit Puppet-8-Requirement und Debian-12-Support.
- `scripts/spec.sh` startet die Unit-Tests über Bundler.

### Was ich dabei gelernt habe

- **rspec-puppet testet den Catalog, nicht den laufenden Server.** Das ist wie ein Bauplan-Check: Puppet kompiliert, ob die erwarteten Resources existieren, bevor irgendein Paket wirklich installiert wird.
- **Compile-Test ist der erste Sicherheitsgurt.** Wenn Hiera-Daten fehlen, EPP-Templates kaputt sind oder Resource-Abhängigkeiten unauflösbar werden, schlägt der Test früh fehl.
- **Content-Matcher prüfen Hiera indirekt.** Wenn der Nginx-Test `puppet-lab.local` im generierten File erwartet, beweist er, dass Hiera → Class Parameter → EPP Template zusammenarbeitet.

### Was als Nächstes kommt (v0.3)

1. BIND9 von "installiert" zu "authoritative" erweitern: `named.conf.local` + echte Zone.
2. DNS-Smoke-Checks mit `dig @127.0.0.1` ergänzen.
3. Danach Secondary-DNS mit Notify + AXFR vorbereiten.

## v0.3 – BIND9 authoritative Zone (Mai 2026)

### Was geändert wurde

- `isp_bind::zones` in Hiera eingeführt.
- `modules/isp_bind/templates/named.conf.local.epp` generiert echte BIND-Zone-Blöcke.
- `modules/isp_bind/templates/db.zone.epp` generiert eine authoritative Zone-Datei.
- Lab-Zone `lab.local` mit SOA, NS, A, AAAA und MX Records angelegt.
- `scripts/smoke.sh` prüft DNS jetzt mit `dig @127.0.0.1`.
- rspec-puppet Tests prüfen `named.conf.local`, `/etc/bind/zones/` und `db.lab.local`.
- `scripts/apply.sh` nutzt `--detailed-exitcodes`, damit Fehler im Puppet-Run den Script-Exit wirklich rot machen.
- Dockerfile behält die apt package lists im Image, damit `puppet apply` im Lab Pakete installieren kann.
- DHCP-Service wird im Docker-Lab per Hiera nicht gemanagt, weil keine echte LAN-Schnittstelle gebunden ist.

### Was ich dabei gelernt habe

- **Authoritative DNS** bedeutet: der Server beantwortet eine Zone, fuer die er selbst die Quelle der Wahrheit ist. Das ist etwas anderes als rekursive Namensauflösung.
- **SOA ist der Personalausweis einer Zone.** Primary NS, Kontakt, Serial und Timer sagen anderen DNS-Servern, wie diese Zone gepflegt und gecached werden soll.
- **Trailing dots sind wichtig.** `ns1.lab.local.` ist ein vollständiger DNS-Name. Ohne Punkt wuerde BIND ihn relativ zur Zone interpretieren.
- **Serial ist Deployment-State.** Wenn sich Zone-Daten ändern, muss die Serial steigen, sonst erkennen Secondaries die Änderung nicht zuverlässig.
- **AXFR bewusst begrenzen.** `allow-transfer` darf nie pauschal offen sein. Im Lab ist `192.0.2.11` als vorbereiteter Secondary eingetragen.
- **Validierung darf nicht lügen.** Ohne `--detailed-exitcodes` kann ein Demo-Script grüner aussehen, als der Puppet-Run wirklich war. Der Script-Exit ist Teil der technischen Wahrheit.

### Was als Nächstes kommt (v0.4)

1. Zweiten BIND-Container als Secondary-DNS anlegen.
2. `also-notify` + `allow-transfer` praktisch testen.
3. `dig @secondary lab.local SOA` und Serial-Sync validieren.

## v0.4 – Secondary-DNS mit Notify + AXFR (Mai 2026)

### Was geändert wurde

- `docker-compose.yml` hat jetzt zwei DNS-Nodes im statischen Lab-Netz `172.28.53.0/24`:
  - `puppet-lab` als Primary auf `172.28.53.10`
  - `puppet-lab-secondary` als Secondary auf `172.28.53.11`
- Hiera nutzt jetzt eine Node-Ebene: `data/nodes/%{trusted.certname}.yaml`.
- `profile::classes` klassifiziert Nodes:
  - Primary bekommt BIND, DHCP, Postfix und Nginx.
  - Secondary bekommt nur BIND.
- `isp_bind::zones` unterstützt jetzt zwei Rollen:
  - `role: primary` schreibt eine Zone-Datei unter `/etc/bind/zones/`.
  - `role: secondary` schreibt keine Zone-Datei, sondern konfiguriert `type slave` mit `masters`.
- Primary erlaubt AXFR nur zur Secondary-IP und sendet Notify dorthin.
- `scripts/apply.sh` läuft jetzt über beide Container und setzt `--certname`, damit Hiera pro Node greift.
- `scripts/smoke.sh` prüft:
  - Primary DNS-Antworten.
  - Secondary DNS-Antworten nach Transfer.
  - AXFR vom Secondary-Container gegen den Primary.

### Was ich dabei gelernt habe

- **Node Classification** ist die Entscheidung, welche Klassen ein Node bekommt. In diesem Lab macht Hiera das über `profile::classes`.
- **Primary vs Secondary** ist nicht einfach zweimal derselbe DNS-Server. Primary hält die Zone-Datei. Secondary holt sie per AXFR und speichert sie unter `/var/cache/bind/`.
- **Notify ist Beschleunigung, AXFR ist die eigentliche Übertragung.** Notify sagt: "Zone hat sich geändert." AXFR holt dann die Zonendaten.
- **`trusted.certname` ist der Schalter für per-node Hiera.** `apply.sh` setzt ihn explizit mit `--certname`, damit Docker-Hostnames nicht zufällig entscheiden.
- **Test auf Transfer braucht Geduld.** `smoke.sh` retryt Secondary-Abfragen, weil BIND den Transfer asynchron startet.

### Was als Nächstes kommt (v0.5)

1. GitHub Actions mit `bundle exec rake spec`.
2. Ein Script fuer `puppet-lint` + `metadata-json-lint`.
3. Optional: negative AXFR-Test von einem nicht erlaubten Container/IP.

## v0.5 – GitHub Actions CI + statischer Lint (Mai 2026)

### Was geändert wurde

- Neues `scripts/lint.sh` als lokaler und CI-kompatibler Static-Check:
  - Bash-Syntax für Scripts.
  - YAML-Syntax für Hiera-Daten.
  - `puppet parser validate` für Manifests.
  - `puppet epp validate` für Templates.
  - `puppet-lint` für Puppet-Stil.
  - `metadata-json-lint` für Modul-Metadaten.
- Neuer GitHub-Actions-Workflow `.github/workflows/ci.yml`.
- CI läuft auf Pushes nach `main`, Pull Requests und manuell via `workflow_dispatch`.
- CI führt aus:
  - `bundle exec rake spec`
  - `./scripts/lint.sh`
  - `docker compose config`

### Was ich dabei gelernt habe

- **CI ist ein Reviewer, der nie vergisst.** Jeder Push prüft dieselben Regeln, statt auf Erinnerung oder manuelle Disziplin zu vertrauen.
- **Static CI und Integration Smoke sind getrennt.** GitHub Actions prüft schnell den Catalog und die Syntax. Das lokale Docker-Lab prüft systemd/BIND/AXFR live.
- **Ein Script ist besser als YAML-Duplikat.** `scripts/lint.sh` ist lokal und im CI gleich. Wenn der Check wächst, muss man ihn nur an einer Stelle ändern.
- **`docker compose config` ist ein billiger Strukturtest.** Es startet keine Container, aber prüft, ob Compose die Datei interpretieren kann.

### Was als Nächstes kommt (v0.6)

1. Optional: GitHub Actions Badge rot/grün nach erstem Run prüfen.
2. Optional: negativer AXFR-Test von einer nicht erlaubten IP.
3. Danach: Postfix + Dovecot + DKIM als nächster ISP-Gap.

## v0.6 – AXFR-Policy mit negativem Test (Mai 2026)

### Was geändert wurde

- `docker-compose.yml` enthält jetzt einen dritten Container:
  - `puppet-lab-client` auf `172.28.53.12`
  - kein Puppet-Node, kein Secondary, nur ein DNS-Client im Lab-Netz
- `scripts/smoke.sh` prüft jetzt beide Seiten der Transfer-Policy:
  - Secondary `172.28.53.11` darf `AXFR` vom Primary ausführen.
  - Client `172.28.53.12` darf die Zone nicht per `AXFR` ziehen.

### Was ich dabei gelernt habe

- **Ein positiver Test reicht nicht.** Wenn nur geprüft wird, dass der Secondary transferieren darf, weiss man noch nicht, ob andere Clients versehentlich auch dürfen.
- **Security-Tests brauchen einen Gegenspieler.** Der dritte Container ist kein Feature, sondern ein Test-Actor: er beweist, dass die Policy greift.
- **AXFR ist sensibel.** Ein offener Zonentransfer verrät die komplette Zone. In einem ISP-Kontext ist das kein Schönheitsfehler, sondern ein echter Betriebsfehler.
- **Smoke-Tests können Policies prüfen.** Nicht jeder Test muss ein Unit-Test sein. Manche Risiken sieht man besser live im Netzwerk.

### Was als Nächstes kommt (v0.7)

1. Postfix Submission auf Port 587.
2. Dovecot SASL/Auth für Mail-Login.
3. Danach DKIM-Signing mit OpenDKIM.

## v0.7 – Postfix Submission + Dovecot SASL/Maildir (Mai 2026)

### Was geändert wurde

- `isp_postfix` verwaltet jetzt zusätzlich `/etc/postfix/master.cf`.
- Postfix hört im Lab auf Submission-Port `587`.
- `main.cf` nutzt Maildir (`home_mailbox = Maildir/`) statt nur lokaler Default-Delivery.
- Postfix ist für Dovecot-SASL vorbereitet:
  - `smtpd_sasl_type = dovecot`
  - `smtpd_sasl_path = private/auth`
- Neues Modul `isp_dovecot`:
  - installiert `dovecot-core` und `dovecot-imapd`
  - setzt `mail_location = maildir:~/Maildir`
  - aktiviert Lab-Auth-Mechanismen `plain login`
  - erzeugt den Auth-Socket `/var/spool/postfix/private/auth` für Postfix
- `scripts/smoke.sh` prüft jetzt:
  - Dovecot läuft.
  - Port `587` ist lokal erreichbar.
  - Der Test-Client erreicht Port `587` über das Lab-Netz.
  - Der Dovecot-Auth-Socket für Postfix existiert.
  - Dovecot zeigt die aktive Maildir-Konfiguration.

### Was ich dabei gelernt habe

- **Port 25 und Port 587 sind verschiedene Rollen.** Port 25 ist MTA-zu-MTA. Port 587 ist Submission: ein Mail-Client gibt authentifiziert Mail ab.
- **Postfix macht SMTP, Dovecot macht Auth/IMAP.** In diesem Setup fragt Postfix Dovecot über einen Unix-Socket, ob ein Login gültig ist.
- **Maildir ist dateibasiert und robust für IMAP.** Jede Mail wird als eigene Datei gespeichert, statt alles in eine einzelne Mbox-Datei zu schreiben.
- **Lab-Auth ohne TLS ist nur didaktisch.** In Produktion muss Submission Auth über TLS laufen. Dieses Lab trennt zuerst SASL-Wiring von Zertifikatsmanagement.
- **Socket-Existenz ist ein guter Smoke-Test.** Wenn `/var/spool/postfix/private/auth` fehlt, ist die Postfix-Dovecot-Verkabelung kaputt.

### Was als Nächstes kommt (v0.8)

1. Lab-User für einen echten SMTP-AUTH-Test sauber modellieren.
2. Danach OpenDKIM einführen.
3. SPF/DMARC als DNS-Records in `lab.local` ergänzen.

## v0.8 – SMTP AUTH mit Dovecot passwd-file (Mai 2026)

### Was geändert wurde

- `isp_dovecot` verwaltet jetzt einen virtuellen Mail-User-Store:
  - System-User/Group `vmail`
  - Mail-Root `/var/mail/vhosts`
  - User-Datei `/etc/dovecot/users`
- Hiera enthält einen Dummy-Lab-User:
  - User: `labuser@lab.local`
  - Password: `labpass`
  - Wichtig: nur Lab-Credential, kein echtes Secret
- Dovecot nutzt zusätzlich `passwd-file` für Auth:
  - `passdb passwd-file`
  - `userdb passwd-file`
- `scripts/smoke.sh` prüft jetzt zwei Auth-Wege:
  - `doveadm auth test labuser@lab.local labpass`
  - echter SMTP-Dialog gegen Postfix Submission `587` mit `AUTH PLAIN`

### Was ich dabei gelernt habe

- **SASL-Socket vorhanden ist nicht gleich Login funktioniert.** Der Socket zeigt nur, dass Postfix Dovecot erreichen kann. Ein Auth-Test beweist, dass User, Passwort und Dovecot-Backend zusammenpassen.
- **`passwd-file` ist ideal für ein Lab.** Es vermeidet echte System-Accounts und zeigt trotzdem sauber, wie Dovecot User validiert.
- **SMTP AUTH ist ein Dialog.** Client verbindet sich, sendet `EHLO`, sieht `AUTH`, sendet einen Base64-Login und erwartet `235 Authentication successful`.
- **Dummy-Passwörter sind keine Secrets.** Trotzdem werden sie klar markiert, damit niemand sie mit Produktions-Credentials verwechselt.

### Was als Nächstes kommt (v0.9)

1. OpenDKIM installieren und Signing-Socket an Postfix anbinden.
2. DKIM-Public-Key als DNS-Record in `lab.local` modellieren.
3. SPF + DMARC Records ergänzen.

## v0.9 – OpenDKIM + DKIM/SPF/DMARC Records (Mai 2026)

### Was geändert wurde

- Neues Modul `isp_opendkim`:
  - installiert `opendkim` und `opendkim-tools`
  - generiert lokal eine DKIM-Key mit `opendkim-genkey`
  - verwaltet `opendkim.conf`
  - verwaltet `key.table`, `signing.table` und `trusted.hosts`
  - startet den OpenDKIM-Milter auf `inet:8891@127.0.0.1`
- Postfix nutzt OpenDKIM jetzt als Milter:
  - `smtpd_milters = inet:127.0.0.1:8891`
  - `non_smtpd_milters = inet:127.0.0.1:8891`
- BIND `lab.local` bekommt Mail-Policy-Records:
  - SPF: `v=spf1 mx -all`
  - DMARC: `v=DMARC1; p=none; ...`
  - DKIM via `$INCLUDE /etc/opendkim/keys/lab.local/default.txt`
- `scripts/smoke.sh` prüft jetzt:
  - OpenDKIM läuft.
  - Der Milter-Port `8891` ist erreichbar.
  - Postfix zeigt den OpenDKIM-Milter in `postconf`.
  - BIND serviert DKIM, SPF und DMARC per `dig`.

### Was ich dabei gelernt habe

- **DKIM hat eine private und eine öffentliche Seite.** OpenDKIM signiert mit der privaten Key. DNS veröffentlicht nur den Public-Key.
- **Private Keys gehören nicht ins GitHub-Repo.** Deshalb generiert Puppet die Lab-Key lokal auf dem Node und BIND inkludiert nur die öffentliche `.txt`-Datei.
- **Milter ist die Brücke zwischen Postfix und OpenDKIM.** Postfix übergibt Mail an OpenDKIM über `inet:127.0.0.1:8891`, bevor die Mail weiterverarbeitet wird.
- **SPF, DKIM und DMARC sind drei verschiedene Kontrollen.** SPF sagt, welche Sender erlaubt sind. DKIM beweist Signatur. DMARC sagt, wie Empfänger mit SPF/DKIM-Ergebnissen umgehen sollen.
- **Puppet-Reihenfolge ist hier kritisch.** OpenDKIM muss die Public-Key-Datei erzeugen, bevor BIND die Zone mit `$INCLUDE` validiert.

### Was als Nächstes kommt (v1.0)

1. Echte signierte Testmail erzeugen und `DKIM-Signature` im lokalen Maildir prüfen.
2. Danach Kea DHCP als nächster ISP-Gap.
3. Optional: PDK-Workflow vollständig nachziehen.
