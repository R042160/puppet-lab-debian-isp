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
