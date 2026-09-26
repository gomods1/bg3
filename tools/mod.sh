# Dev shortcuts for the running game (source this file in Git Bash):
#   modcmd <id>          run a mod command (the mod menu's ids: nearby, farther, markers...)
#   modsel <text>        put the open list's cursor on the first entry containing text
#   modlist              print the open list
G="python tools/game.py"
modcmd() { $G lua "ID='$1'
$(cat tools/console/run_command.lua)"; }
modsel() { $G lua "PATTERN='$1'
$(cat tools/console/select.lua)"; }
modlist() { $G lua-file tools/console/list_screen.lua; }
# modact <action text> <target text>: arm an action from the actions list and confirm it on the
# first target whose line contains the text, after the game's preview was read (dev only).
modact() {
    modcmd actions >/dev/null; sleep 1.5; modsel "$1" >/dev/null; $G press enter >/dev/null; sleep 2
    modsel "$2" >/dev/null; $G press down up >/dev/null
    local L="$LOCALAPPDATA/Larian Studios/Baldur's Gate 3/Script Extender/BG3Access/logs/speech.log"
    local n=$(wc -l < "$L")
    for i in $(seq 1 60); do [ $(tail -n +$((n+1)) "$L" | grep -c "por ciento\|no es posible\|no se pudo\|cura de") -gt 0 ] && break; sleep 1; done
    $G press enter >/dev/null; sleep 9; tail -n +$((n+1)) "$L" | grep -v "^ *[0-9]* ! " | cut -c1-300
}
# modwait: wait until one of the party's turns (or a reaction, or the end) comes up; prints what was said.
modwait() {
    local L="$LOCALAPPDATA/Larian Studios/Baldur's Gate 3/Script Extender/BG3Access/logs/speech.log"
    local n=$(wc -l < "$L")
    for i in $(seq 1 150); do [ $(tail -n +$((n+1)) "$L" | grep -c "Turno: Tav\|Turno: Corazón\|Turno: Gale\|¿Reacción\|Fin del combate") -gt 0 ] && break; sleep 2; done
    sleep 3; tail -n +$((n+1)) "$L" | cut -c1-300
}
