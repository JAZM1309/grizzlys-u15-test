#!/usr/bin/env bash
# Test-Paket aus dem Zweig "eingang" (vom Admin-Bereich abgelegt) ins Test-Repo übernehmen.
# Gleiche Prüfungen wie ./test-hochladen.sh im Grizzlys-Werkzeug.
WZ="$(cd "$(dirname "$0")" && pwd)"; source "$WZ/gemeinsam.sh"
cd "$GITHUB_WORKSPACE"; git_name

if [ "$AKTION" = "neu" ]; then pages_neu; info "Veröffentlichung der Test-App neu angestoßen ($(version_von .))."; exit 0; fi

git fetch -q origin eingang || fehler "Kein Paket gefunden – bitte im Admin-Bereich erneut hochladen."
P="$RUNNER_TEMP/paket"; mkdir -p "$P"
git show origin/eingang:paket.zip > "$RUNNER_TEMP/paket.zip" || fehler "Kein Paket gefunden – bitte im Admin-Bereich erneut hochladen."
unzip -q -o "$RUNNER_TEMP/paket.zip" -d "$P" || fehler "Die Zip-Datei lässt sich nicht entpacken."
Q="$P"
if [ ! -f "$Q/index.html" ] && [ "$(ls -A "$Q" | wc -l)" = 1 ] && [ -d "$Q/$(ls -A "$Q")" ]; then Q="$Q/$(ls -A "$Q")"; fi

V=""
if [ -f "$Q/index.html" ]; then
  grep -q 'class="testRibbon"' "$Q/index.html" || fehler "Das Paket ist keine Testversion (kein Test-Balken). Nichts hochgeladen."
  [ -f "$Q/sw.js" ] || fehler "Im Paket fehlt die sw.js. Nichts hochgeladen."
  grep -q '"grizzlys-u15-test-v' "$Q/sw.js" || fehler "Die sw.js im Paket ist keine Test-sw.js. Nichts hochgeladen."
  V=$(version_von "$Q"); C=$(cache_von "$Q")
  [ "${V##*.}" = "$C" ] || fehler "Version ($V) und Cache-Nummer ($C) passen nicht zusammen. Nichts hochgeladen."
fi
for weg in functions firebase.json firestore.rules .github .git .nojekyll; do rm -rf "${Q:?}/$weg"; done

# Doku nur für Live (Ordner "nur-live" im Paket: README.md, README.txt, FUNCTIONS-ANLEITUNG.txt, PDFs)
# wird im Test-Repo unter .github/live-doku abgelegt und beim nächsten „Live gehen“ mitgenommen.
DOKU_N=0
[ -n "$V" ] && rm -rf .github/live-doku
if [ -d "$Q/nur-live" ]; then
  mkdir -p .github/live-doku
  for f in "$Q/nur-live"/*; do
    case "$(basename "$f")" in *.md|*.txt|*.pdf) cp "$f" .github/live-doku/; DOKU_N=$((DOKU_N+1)) ;; esac
  done
  rm -rf "$Q/nur-live"
fi

ALT=$(version_von .)
if [ -n "$V" ] && [ -n "$ALT" ] && [ "$V" != "$ALT" ] && [ "$(printf '%s\n%s\n' "$ALT" "$V" | sort -V | tail -1)" = "$ALT" ] && [ "$AELTER" != "ja" ]; then
  fehler "ÄLTER: Das Paket ($V) ist älter als die Test-App ($ALT). Nichts hochgeladen."
fi

cp -a "$Q"/. ./
git add -A
if git diff --cached --quiet; then info "Das Paket entspricht schon der Test-App ($ALT) – nichts zu tun."; exit 0; fi
GEAENDERT=$(git diff --cached --name-only | wc -l)

[ -n "$V" ] && pruefung "$GITHUB_WORKSPACE"

git commit -q -m "Test ${V:-Dateien} (Admin-Bereich)"
git push -q origin HEAD:main || fehler "Hochladen ins Test-Repo fehlgeschlagen."
pages_neu
info "Test-App: ${ALT:-?} → ${V:-unverändert} ($GEAENDERT Dateien). In 1–2 Minuten in der Test-App."
[ "$DOKU_N" -gt 0 ] && info "Doku für Live ($DOKU_N Dateien) liegt bereit und geht beim nächsten „Live gehen“ mit."
