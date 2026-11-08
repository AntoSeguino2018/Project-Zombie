#!/bin/bash
# Lancia i test automatici del progetto (Git Bash su Windows, o Linux/macOS).
#
# Uso, dalla cartella del progetto:
#   bash tests/run_tests.sh                     tutti i test (circa 10 minuti)
#   TESTS="test_31" NET="" bash tests/run_tests.sh      solo alcuni
#   GODOT=/percorso/godot bash tests/run_tests.sh       altro eseguibile
#
# Ogni test stampa "RISULTATO: N errori" e una riga FAIL per ogni controllo
# fallito; qui si mostrano solo quelle (più gli errori di script). I log
# completi finiscono in tests/logs/.
#
# Tipi di test:
# - test_*: da soli, senza grafica (--headless).
# - net_*: in rete con due istanze (host e client) sulla stessa macchina;
#   net_zombies ne usa tre (host, client e uno che entra a partita iniziata).
# - soak: 35 s di partita senza controlli, per vedere che non escano errori.
# Script lunghi da lanciare a mano (non sono nell'elenco):
# - waves_complex.gd: 10 ondate nel Complesso, segnala zombie incastrati.
# - bench_items_win.gd: FPS in finestra con 0-10 tipi di oggetti (senza
#   --headless): serve a riconoscere cali di prestazioni.

cd "$(dirname "$0")/.."
G=${GODOT:-/c/Dev/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe}
T=tests
L=tests/logs
mkdir -p $L

ALL_TESTS="test_friendly test_damage test_15b test_16 test_17 test_19 test_enemy test_31 test_32 test_33 test_34 test_35 test_36 test_37 test_38 test_39 test_40 soak"
ALL_NET="net_test net_combat net_crates net_waves net_revive net_money net_items net_complex net_magnum net_zombies net_campus net_helicopter"

for t in ${TESTS-$ALL_TESTS}; do
  echo "== $t"
  timeout 300 $G --headless --path . --script $T/$t.gd > $L/$t.log 2>&1
  grep -E "FAIL|RISULTATO|SCRIPT ERROR|Parse Error" $L/$t.log | head -20
done

for n in ${NET-$ALL_NET}; do
  echo "== $n"
  timeout 200 $G --headless --path . --script $T/$n.gd -- host > $L/${n}_host.log 2>&1 &
  sleep 2
  if [ "$n" = "net_zombies" ]; then
    timeout 200 $G --headless --path . --script $T/$n.gd -- late > $L/${n}_late.log 2>&1 &
  fi
  timeout 200 $G --headless --path . --script $T/$n.gd -- client > $L/${n}_client.log 2>&1
  wait
  grep -hE "FAIL|RISULTATO|SCRIPT ERROR|Parse Error" $L/${n}_*.log | head -30
done
