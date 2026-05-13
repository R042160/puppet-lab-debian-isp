# puppet-lab-debian-isp

> Persönliches Lab zum Erlernen von **Puppet** in einem ISP-typischen Debian-Stack.
> Aktiver Aufbau, parallel zur Bewerbung als System Engineer.
> Ehrlich kein Produktiv-Setup – das hier ist *learning in public*.

[![Debian 12](https://img.shields.io/badge/Debian-12_Bookworm-A81D33?logo=debian&logoColor=white)](https://www.debian.org/)
[![Puppet](https://img.shields.io/badge/Puppet-8.x-FFAE1A?logo=puppet&logoColor=black)](https://puppet.com/)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)](https://docs.docker.com/compose/)

## Ziel

Selbständig durcharbeiten, was die Stellenausschreibung *„System Engineer mit Puppet/Salt"* erwartet – an einem echten, reproduzierbaren Setup statt nur in einem Buch. Vier ISP-Kerndienste in Puppet-Manifesten, auf einem Debian-12-Container:

- **BIND9** – authoritative DNS, IPv4/IPv6
- **ISC-DHCP-Server** – LAN-Lease-Pool
- **Postfix** – minimaler MTA mit Local-Delivery
- **Nginx** – Default-Vhost + TLS-Vorbereitung

## Lab-Aufbau

```
                 ┌──────────────────────────────────┐
                 │  puppet-lab (Debian 12 Container) │
                 │                                   │
   docker-compose│  ┌────────┐ ┌────────┐ ┌────────┐│
   ───────────▶  │  │ bind9  │ │  dhcp  │ │postfix ││
                 │  └────────┘ └────────┘ └────────┘│
                 │           ┌────────┐             │
                 │           │ nginx  │             │
                 │           └────────┘             │
                 │                                   │
                 │  puppet apply manifests/site.pp   │
                 └──────────────────────────────────┘
```

## Quickstart

```bash
git clone https://github.com/R042160/puppet-lab-debian-isp.git
cd puppet-lab-debian-isp
docker compose up -d
./scripts/apply.sh        # läuft puppet apply im Container
./scripts/smoke.sh        # prüft, dass alle 4 Dienste laufen
```

## Struktur

```
.
├── docker-compose.yml
├── Dockerfile
├── manifests/
│   └── site.pp            # entrypoint, klassifiziert den Node
├── modules/
│   ├── isp_bind/          # BIND9 authoritative
│   ├── isp_dhcp/          # ISC-DHCP-Server
│   ├── isp_postfix/       # Postfix MTA
│   └── isp_nginx/         # Nginx default vhost
├── scripts/
│   ├── apply.sh
│   └── smoke.sh
└── docs/
    └── learnings.md       # ehrliche Notizen aus dem Lernprozess
```

## Was ich bewusst (noch) nicht mache

- **Kein puppet master/agent** – `puppet apply` reicht für ein 1-Node-Lab und macht den Loop schnell. Master/Agent kommt im nächsten Schritt.
- **Kein Hiera** – Daten sind aktuell in den Manifesten. Hiera-Separation ist ein Refactor-Ziel, sobald die Module sauber laufen.
- **Keine PDK-Tests** – kommt, sobald die Module stabil sind.
- **Kein Forge-Module-Reuse** – Ziel ist *Verstehen, wie es funktioniert*, nicht möglichst wenig Code.

## Was hier bewusst stimmen muss

- **Idempotenz**: jedes `puppet apply` führt zu *„0 events"* nach dem ersten Lauf.
- **Resource relationships**: `require`, `notify`, `subscribe` korrekt gesetzt.
- **Konvergenz statt Imperativ**: keine `exec`-Workarounds für Dinge, die als `package`/`service`/`file` ausgedrückt werden können.

## Lernpfad

*Aktuelle Version: **v0.1** – Hiera-Layer eingeführt, Daten aus Manifesten ausgelagert.*

- [x] Repo-Struktur + docker-compose
- [x] `isp_bind` Modul (Package + Service + named.conf.options)
- [x] `isp_dhcp` Modul (Package + Service + dhcpd.conf)
- [x] `isp_postfix` Modul (Package + Service + main.cf)
- [x] `isp_nginx` Modul (Package + Service + default-site)
- [x] `scripts/apply.sh` + `scripts/smoke.sh`
- [x] **Hiera-Refactor** (Daten aus Manifesten ausgelagert) → `hiera.yaml` + `data/common.yaml`
- [ ] PDK-Init für jedes Modul (`pdk new module`)
- [ ] rspec-puppet Smoke-Test
- [ ] Master/Agent statt apply
- [ ] Salt-Variante zum Vergleich

## Warum öffentlich

Weil ein Lebenslauf mit *„Puppet/Salt – in Vorbereitung"* schwächer ist als ein öffentliches Repo, in dem man den Lernprozess nachvollziehen kann. Wer das hier liest, sieht genau, wo ich aktuell stehe – und sieht auch, dass ich dranbleibe.

## Kontakt

- GitHub: [@R042160](https://github.com/R042160)
- E-Mail: ronesto@hotmail.com
