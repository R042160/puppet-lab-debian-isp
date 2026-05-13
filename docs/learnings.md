# Lernnotizen – puppet-lab-debian-isp

Ehrliche Notizen aus dem Lernprozess. Wird laufend erweitert.

## v0 – Setup (Mai 2026)

### Was gut funktioniert hat

- **`puppet apply` reicht für den Anfang.** Ein Master/Agent-Setup hätte zwei Container und mehr Netzwerk-Komplexität erfordert. Mit `--modulepath` läuft alles aus dem gemounteten `modules/`-Verzeichnis.
- **Idempotenz prüfen ist trivial:** den zweiten Lauf in `apply.sh` mit erwartetem „0 events"-Output. Wenn beim zweiten Lauf Events auftauchen, ist eine Resource nicht idempotent (häufig: `exec` ohne `unless`/`onlyif`).
- **Resource relationships** mit `require`/`notify`/`subscribe` machen die Manifeste lesbar wie ein DAG.

### Wo es geknackt hat

- **Postfix interaktiv:** ohne `debconf-set-selections` blockiert `apt install postfix` mit einer Auswahl-Maske. Lösung: ein `exec` mit `unless`-Guard, der `mailer_type` und `mailname` vorab seedet.
- **DHCP ohne Interface:** `isc-dhcp-server` startet im Lab-Container nicht sauber, weil keine echte Schnittstelle gebunden ist. Das Manifest deklariert den Service trotzdem – Intent vor Reality.
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
