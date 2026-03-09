# TODO

- [x] es sollte nur die aktuelle DB als container erzeugt werden
- [x] warum werden symlinks erzeugt können erstmal entfernt werden
- [x] env. template für globale einstellungen
  - [x] TESTEN Automatisch genereiert Hauptpfad von znuny-dev
  - [x] Pfad definition der nutzbaren verzeichnisse packages frameworks tools
  - [x] TESTEN Automatisch genereiert unterpfade
    - [x] dev/docker
    - [x] dev/script
    - [x] dev
- [x] TESTEN unter dev dürfen keine ordner packages frameworks tools angelegt werden
- [x] env. template für instanzen
- [x] environment-* commands sollten in instance integriert werden
- [x] environment-start -> instance-start ohne angabe  Start all development environments
- [x] environment-stop  -> instance-stop ohne angabe  Stop all development environments
- [x] environment-restart -> instance-restart ohne angabe Restart all development environments
- [x] environment-status -> instance-status ohne angabe  Show all environment status
- [x] environment-logs  -> instance-status ohne angabe  Show container logs
- [x] wenn man ein neuen instanz erstellt sollte man via params direkt alle notweniden parameter übergeben können
- [x] Znuny hat mögliche Netzwerkprobleme entdeckt. Sie können entweder versuchen die Seite manuell erneut zu laden oder Sie warten bis ihr Browser die Verbindung wiederhergestellt hat. SecureMode sollte in der config.pm gesetzt sein
- [x] wenn keine globale .env existiert dann sollte nur setup-all und setup-status als befehl zur verfügung stehen
  Nachfragen ob der schritt durchgeführt werden soll (default ja) Step 1: Generate global .env from template (with backup preservation).
  Nachfragen ob der schritt durchgeführt werden soll (default ja) Step 2: Configure directories              (frameworks, packages, tools).
  Nachfragen ob der schritt durchgeführt werden soll (default ja) Step 3: Setting up repositories            (Znuny, tools, etc.).
  Nachfragen ob der schritt durchgeführt werden soll (default ja) Step 4: Creating framework instance        (znuny_dev).
  Nachfragen ob der schritt durchgeführt werden soll (default ja) und auch nur wenn Schrit 4 durchgeführt wurde Step 5: Generating Docker Compose files    (for all frameworks).
  Nachfragen ob der schritt durchgeführt werden soll (default ja) und auch nur wenn Schrit 5 durchgeführt wurde Step 6: Starting development environment   (docker-compose up -d).
- [x] /znuny-dev.sh create dev --- lösht aber erstellt keine neue
- [x] setup-all sollte fragen ob es ein alias für ./znuny-dev.sh definieren soll `zd`, das sollte dann auch in der env festgehalten werden
- [x] wenn ich von gitlab pulle sind nicht alle branches vorhanden wieso?
- [x] prüfe ob docker installiert ist bzw docker desktop in setup-all... verraussetzung siehe check_docker()
- [x] if zd alias is set use zd instead of ./znuny-dev.sh
- [x] neues verzeichnis `logs` im root verzeichnis für jede instance beinhaltet access.log / error.log / fred falls vorhanden
- [x] Available commands: znuny-console, znuny-logs, znuny-config
- [x] ask remove zd alias
- [x] znuny_frameworks ist das notwendig? → Nein, entfernt (Mount wurde nirgends genutzt; generate-apache-config.sh nutzt /opt/znuny)
- [x] setup-remove sollte
  - [x] Remove Instances sollte alle punkte auf einmal löschen aber für jedes instance extra abfragen
    - [x] Remove Docker Environment:
    - [x] Remove Docker Resources:
    - [x] Remove Docker Containers:
    - [x] Remove Docker Volumes:
    - [x] Remove Docker Networks:
- [x] http port start with 10000 (prüfen) + use my.env START_PORT var...
- [x] docker image update to FROM ubuntu:24.04
- [x] eigene config.pm soll genutzt werden
- [x] zd setup-status sollte wie aktuelle alles zeigen
- [x] zd status <framework> sollte nur die instance anzeigen
- [x] modul tools erneut testen
- [x] status <framework|all>"             "Show framework instance or all instance status"
- [x] prüfe ob es funktionen doppelt gibt
- [x] sort indexes in USED_FRAMEWORK_INDICES=2,0
- [x] prüfe alle bash scripte

# Features
- [ ] dashboard
- [ ] reverse proxy