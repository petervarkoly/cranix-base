#!/bin/bash

# Skript zum Löschen der userWorkstations-Attribute eines AD-Benutzers
# Wird direkt auf dem Samba-AD-Server ausgeführt

# Farben für bessere Lesbarkeit
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Prüfen, ob Skript als root ausgeführt wird
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Dieses Skript muss als root ausgeführt werden!${NC}"
   exit 1
fi

# Funktion zur Anzeige der Hilfe
show_help() {
    echo "Verwendung: $0 [OPTIONEN] BENUTZERNAME"
    echo ""
    echo "Löscht die userWorkstations-Attribute eines AD-Benutzers"
    echo ""
    echo "Optionen:"
    echo "  -h, --help     Diese Hilfe anzeigen"
    echo "  -v, --verbose  Ausführliche Ausgabe aktivieren"
    echo ""
    echo "Beispiele:"
    echo "  $0 max.mustermann"
    echo "  $0 -v max.mustermann"
}

# Funktion zum Loggen von Nachrichten
log() {
    local level=$1
    local message=$2
    case $level in
        "INFO")
            [[ "$VERBOSE" == true ]] && echo -e "${GREEN}[INFO]${NC} $message"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
    esac
}

# Initialisierung der Variablen
VERBOSE=false
USERNAME=""

# Parameter parsen
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            if [[ -z "$USERNAME" ]]; then
                USERNAME="$1"
            else
                log "ERROR" "Unbekannter Parameter: $1"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Prüfen ob Benutzername angegeben wurde
if [[ -z "$USERNAME" ]]; then
    log "ERROR" "Kein Benutzername angegeben!"
    show_help
    exit 1
fi


# Temporäre LDIF-Datei erstellen
TMP_LDIF=$(mktemp)
if [[ "$VERBOSE" == true ]]; then
    log "INFO" "Erstelle temporäre LDIF-Datei: $TMP_LDIF"
fi

DN=$( /usr/bin/ldbsearch -H /var/lib/samba/private/sam.ldb uid=$USERNAME dn | grep dn: )

# LDIF-Datei mit den Lösch-Anweisungen erstellen
cat > "$TMP_LDIF" << EOF
$DN
changetype: modify
delete: userWorkstations
-
EOF

if [[ "$VERBOSE" == true ]]; then
    log "INFO" "LDIF-Datei-Inhalt:"
    cat "$TMP_LDIF"
fi

ldbmodify -H /var/lib/samba/private/sam.ldb "$TMP_LDIF" 2>/dev/null

# Aufräumen
rm -f "$TMP_LDIF"

# Verifikation
if [[ "$VERBOSE" == true ]]; then
    log "INFO" "Überprüfung der Änderungen:"
    NEW_VALUE=$(samba-tool user show "$USERNAME" | grep -i "userWorkstations" || echo "userWorkstations: (nicht gesetzt)")
    echo "  $NEW_VALUE"
fi

exit 0
