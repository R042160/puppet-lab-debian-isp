# puppet-lab-debian-isp

> Persönliches Lab zum Erlernen von **Puppet** in einem ISP-typischen Debian-Stack.
> Aktiver Aufbau, parallel zur Bewerbung als System Engineer.
> Ehrlich kein Produktiv-Setup – das hier ist *learning in public*.

[![Debian 12](https://img.shields.io/badge/Debian-12_Bookworm-A81D33?logo=debian&logoColor=white)](https://www.debian.org/)
[![Puppet](https://img.shields.io/badge/Puppet-8.x-FFAE1A?logo=puppet&logoColor=black)](https://puppet.com/)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)](https://docs.docker.com/compose/)
[![CI](https://github.com/R042160/puppet-lab-debian-isp/actions/workflows/ci.yml/badge.svg)](https://github.com/R042160/puppet-lab-debian-isp/actions/workflows/ci.yml)

## Ziel

Selbständig durcharbeiten, was die Stellenausschreibung *„System Engineer mit Puppet/Salt"* erwartet – an einem echten, reproduzierbaren Setup statt nur in einem Buch. ISP-Kerndienste in Puppet-Manifesten, auf Debian-12-Containern:

- **BIND9** – authoritative DNS, IPv4/IPv6
- **ISC-DHCP-Server** – LAN-Lease-Pool
- **Kea DHCPv4** – moderner DHCPv4-Server mit Lab-Konfiguration
- **Postfix + Dovecot** – Submission 587, SMTP AUTH, SASL-Socket, Maildir/IMAP
- **OpenDKIM** – DKIM-Signing mit lokal generierter Lab-Key
- **Restic** – lokales Config-Backup mit Restore-Check und Retention
- **Prometheus Node Exporter** – Host-Metriken + Lab-Health-Metriken
- **Nginx** – Default-Vhost + TLS-Vorbereitung

## Lab-Aufbau

```
                 ┌───────────────────────────────────┐
                 │ puppet-lab (Primary DNS + Dienste)│
                 │                                   │
   docker-compose│  ┌────────┐ ┌────────┐ ┌────────┐│
   ───────────▶  │  │ bind9  │ │ dhcp4  │ │postfix ││
                 │  └────────┘ └────────┘ └────────┘│
                 │  ┌────────┐ ┌────────┐ ┌────────┐│
                 │  │dovecot │ │opendkim│ │ nginx  ││
                 │  └────────┘ └────────┘ └────────┘│
                 │           ┌────────┐              │
                 │           │restic  │ config backup│
                 │           └────────┘ + restore    │
                 │           ┌────────┐              │
                 │           │metrics │ :9100        │
                 │           └────────┘ textfile     │
                 │                                   │
                 │  puppet apply manifests/site.pp   │
                 └───────────────────────────────────┘
                                │
                                │ Notify + AXFR
                                ▼
                 ┌───────────────────────────────────┐
                 │ puppet-lab-secondary (DNS only)   │
                 │                                   │
                 │  ┌────────┐                       │
                 │  │ bind9  │  secondary zone       │
                 │  └────────┘  /var/cache/bind/...  │
                 └───────────────────────────────────┘

                 ┌───────────────────────────────────┐
                 │ puppet-lab-client                 │
                 │                                   │
                 │  unauthorized AXFR must fail      │
                 └───────────────────────────────────┘
```

## Quickstart

```bash
git clone https://github.com/R042160/puppet-lab-debian-isp.git
cd puppet-lab-debian-isp
docker compose up -d
./scripts/apply.sh        # läuft puppet apply auf Primary + Secondary
./scripts/smoke.sh        # prüft Dienste, SMTP AUTH, DKIM/SPF/DMARC, Backup/Retention/Restore, Kea, Monitoring, DNS und AXFR
```

## Unit-Tests

```bash
bundle install
./scripts/spec.sh         # rspec-puppet: Catalog compiles + Resources existieren
./scripts/lint.sh         # YAML, Puppet parser, EPP, puppet-lint, metadata lint
```

## Struktur

```
.
├── Gemfile
├── Gemfile.lock
├── docker-compose.yml
├── Dockerfile
├── .github/
│   └── workflows/
│       └── ci.yml          # GitHub Actions: spec + static lint
├── data/
│   ├── common.yaml         # Hiera-Daten fuer Lab-Defaults
│   └── nodes/              # per-node Overrides, z. B. Secondary-DNS
├── hiera.yaml              # Hiera-v5-Hierarchie
├── manifests/
│   └── site.pp            # entrypoint, klassifiziert den Node
├── modules/
│   ├── isp_bind/          # BIND9 authoritative
│   ├── isp_backup/        # Restic repository + backup/restore-check scripts
│   ├── isp_dhcp/          # ISC-DHCP-Server
│   ├── isp_kea/           # Kea DHCPv4
│   ├── isp_dovecot/       # Dovecot IMAP + SASL auth socket
│   ├── isp_monitoring/    # Prometheus Node Exporter + textfile metrics
│   ├── isp_opendkim/      # OpenDKIM signing + local key generation
│   ├── isp_postfix/       # Postfix MTA
│   └── isp_nginx/         # Nginx default vhost
├── spec/
│   ├── spec_helper.rb
│   └── classes/           # rspec-puppet Smoke-Tests
├── scripts/
│   ├── apply.sh
│   ├── lint.sh
│   ├── spec.sh
│   └── smoke.sh
└── docs/
    └── learnings.md       # ehrliche Notizen aus dem Lernprozess
```

## Was ich bewusst (noch) nicht mache

- **Kein puppet master/agent** – `puppet apply` reicht für ein 1-Node-Lab und macht den Loop schnell. Master/Agent kommt im nächsten Schritt.
- **Kein voller PDK-Workflow** – die Module haben `metadata.json`, `Gemfile.lock` und rspec-puppet Tests, aber `pdk validate`/`pdk test unit` ist der nächste Schritt.
- **Kein echter Multi-Host-Cluster** – Primary/Secondary laufen als Docker-Container in einem Lab-Netz. Für Produktion wäre das auf getrennten Hosts/VMs.
- **Kein Offsite-Backup** – Restic läuft lokal im Lab, mit Restore-Check und Retention. Produktion braucht zusätzlich Remote-Repository.
- **Kein komplettes Monitoring-System** – Node Exporter liefert Metriken; Prometheus/Icinga/Checkmk als externer Collector ist der nächste Schritt.
- **Kein produktionsreifes Mail-TLS** – SMTP AUTH läuft im Lab ohne TLS, damit zuerst Postfix/Dovecot-SASL verstanden und getestet wird.
- **Keine DKIM-Private-Key im Repo** – OpenDKIM generiert die Lab-Key lokal im Container; BIND bindet nur den öffentlichen `.txt`-Record ein.
- **Kein Forge-Module-Reuse** – Ziel ist *Verstehen, wie es funktioniert*, nicht möglichst wenig Code.

## Was hier bewusst stimmen muss

- **Idempotenz**: jedes `puppet apply` führt zu *„0 events"* nach dem ersten Lauf.
- **Resource relationships**: `require`, `notify`, `subscribe` korrekt gesetzt.
- **Konvergenz statt Imperativ**: keine `exec`-Workarounds für Dinge, die als `package`/`service`/`file` ausgedrückt werden können.

## Lernpfad

*Aktuelle Version: **v1.2** – Kea DHCPv4 + Restic Retention eingeführt.*

- [x] Repo-Struktur + docker-compose
- [x] `isp_bind` Modul (Package + Service + named.conf.options)
- [x] `isp_backup` Modul (Restic Repo + Backup/Restore-Check)
- [x] `isp_dhcp` Modul (Package + Service + dhcpd.conf)
- [x] `isp_kea` Modul (Kea DHCPv4 Package + kea-dhcp4.conf + Syntax-Check)
- [x] `isp_postfix` Modul (Package + Service + main.cf)
- [x] `isp_dovecot` Modul (Package + Service + Maildir/SASL)
- [x] `isp_monitoring` Modul (Node Exporter + Textfile Collector)
- [x] `isp_opendkim` Modul (Signing-Key, KeyTable, SigningTable, TrustedHosts)
- [x] `isp_nginx` Modul (Package + Service + default-site)
- [x] `scripts/apply.sh` + `scripts/smoke.sh`
- [x] **Hiera-Refactor** (Daten aus Manifesten ausgelagert) → `hiera.yaml` + `data/common.yaml`
- [x] PDK-kompatible Modul-Metadaten (`metadata.json`)
- [x] rspec-puppet Smoke-Test
- [x] **BIND9 authoritative Zone** (`lab.local` mit SOA, NS, A, AAAA, MX)
- [x] **BIND9 Secondary-DNS** mit Notify + AXFR
- [x] **GitHub Actions CI** (`bundle exec rake spec`, `scripts/lint.sh`, `docker compose config`)
- [x] **AXFR-Policy-Test**: Secondary darf transferieren, Client wird abgewiesen
- [x] **Mail Submission**: Postfix 587 + Dovecot SASL-Socket + Maildir
- [x] **SMTP AUTH Smoke-Test**: Lab-User authentifiziert via Postfix Submission
- [x] **Mail Signing**: OpenDKIM-Milter + DKIM/SPF/DMARC Records in `lab.local`
- [x] **Backup/Restore**: Restic Snapshot + Restore-Check im Smoke-Test
- [x] **Backup-Retention**: `restic forget --keep-* --prune` im Smoke-Test
- [x] **Monitoring**: Node Exporter + eigene Lab-Health-Metriken
- [x] **Kea DHCPv4**: moderner DHCPv4-Server mit gerenderter Lab-Subnet-Konfiguration
- [ ] Voller PDK-Workflow (`pdk validate`, `pdk test unit`)
- [ ] Master/Agent statt apply
- [ ] Salt-Variante zum Vergleich

## Warum öffentlich

Weil ein Lebenslauf mit *„Puppet/Salt – in Vorbereitung"* schwächer ist als ein öffentliches Repo, in dem man den Lernprozess nachvollziehen kann. Wer das hier liest, sieht genau, wo ich aktuell stehe – und sieht auch, dass ich dranbleibe.

## Kontakt

- GitHub: [@R042160](https://github.com/R042160)
- E-Mail: ronesto@hotmail.com
