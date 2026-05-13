# puppet-lab-debian-isp

> Persönliches Lab zum Erlernen von **Puppet** in einem ISP-typischen Debian-Stack.
> Aktiver Aufbau, parallel zur Bewerbung als System Engineer.
> Ehrlich kein Produktiv-Setup – das hier ist *learning in public*.

[![Debian 12](https://img.shields.io/badge/Debian-12_Bookworm-A81D33?logo=debian&logoColor=white)](https://www.debian.org/)
[![Puppet](https://img.shields.io/badge/Puppet-8.x-FFAE1A?logo=puppet&logoColor=black)](https://puppet.com/)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)](https://docs.docker.com/compose/)
[![CI](https://github.com/R042160/puppet-lab-debian-isp/actions/workflows/ci.yml/badge.svg)](https://github.com/R042160/puppet-lab-debian-isp/actions/workflows/ci.yml)

## Ziel

Selbständig durcharbeiten, was die Stellenausschreibung *„System Engineer mit Puppet/Salt"* erwartet – an einem echten, reproduzierbaren Setup statt nur in einem Buch. Vier ISP-Kerndienste in Puppet-Manifesten, auf einem Debian-12-Container:

- **BIND9** – authoritative DNS, IPv4/IPv6
- **ISC-DHCP-Server** – LAN-Lease-Pool
- **Postfix** – minimaler MTA mit Local-Delivery
- **Nginx** – Default-Vhost + TLS-Vorbereitung

## Lab-Aufbau

```
                 ┌───────────────────────────────────┐
                 │ puppet-lab (Primary DNS + Dienste)│
                 │                                   │
   docker-compose│  ┌────────┐ ┌────────┐ ┌────────┐│
   ───────────▶  │  │ bind9  │ │  dhcp  │ │postfix ││
                 │  └────────┘ └────────┘ └────────┘│
                 │           ┌────────┐             │
                 │           │ nginx  │             │
                 │           └────────┘             │
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
```

## Quickstart

```bash
git clone https://github.com/R042160/puppet-lab-debian-isp.git
cd puppet-lab-debian-isp
docker compose up -d
./scripts/apply.sh        # läuft puppet apply auf Primary + Secondary
./scripts/smoke.sh        # prüft Dienste, DNS-Antworten und AXFR
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
│   ├── isp_dhcp/          # ISC-DHCP-Server
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
- **Kein Forge-Module-Reuse** – Ziel ist *Verstehen, wie es funktioniert*, nicht möglichst wenig Code.

## Was hier bewusst stimmen muss

- **Idempotenz**: jedes `puppet apply` führt zu *„0 events"* nach dem ersten Lauf.
- **Resource relationships**: `require`, `notify`, `subscribe` korrekt gesetzt.
- **Konvergenz statt Imperativ**: keine `exec`-Workarounds für Dinge, die als `package`/`service`/`file` ausgedrückt werden können.

## Lernpfad

*Aktuelle Version: **v0.5** – GitHub-Actions-CI + statischer Lint eingeführt.*

- [x] Repo-Struktur + docker-compose
- [x] `isp_bind` Modul (Package + Service + named.conf.options)
- [x] `isp_dhcp` Modul (Package + Service + dhcpd.conf)
- [x] `isp_postfix` Modul (Package + Service + main.cf)
- [x] `isp_nginx` Modul (Package + Service + default-site)
- [x] `scripts/apply.sh` + `scripts/smoke.sh`
- [x] **Hiera-Refactor** (Daten aus Manifesten ausgelagert) → `hiera.yaml` + `data/common.yaml`
- [x] PDK-kompatible Modul-Metadaten (`metadata.json`)
- [x] rspec-puppet Smoke-Test
- [x] **BIND9 authoritative Zone** (`lab.local` mit SOA, NS, A, AAAA, MX)
- [x] **BIND9 Secondary-DNS** mit Notify + AXFR
- [x] **GitHub Actions CI** (`bundle exec rake spec`, `scripts/lint.sh`, `docker compose config`)
- [ ] Voller PDK-Workflow (`pdk validate`, `pdk test unit`)
- [ ] Master/Agent statt apply
- [ ] Salt-Variante zum Vergleich

## Warum öffentlich

Weil ein Lebenslauf mit *„Puppet/Salt – in Vorbereitung"* schwächer ist als ein öffentliches Repo, in dem man den Lernprozess nachvollziehen kann. Wer das hier liest, sieht genau, wo ich aktuell stehe – und sieht auch, dass ich dranbleibe.

## Kontakt

- GitHub: [@R042160](https://github.com/R042160)
- E-Mail: ronesto@hotmail.com
