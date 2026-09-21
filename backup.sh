#!/bin/bash

BACKUP_DIR="$HOME/Backups"
DATE=$(date +%Y-%m-%d-%H-%M-%S)
LOG_FILE="$HOME/Projects/bash-projects/backup-script/backup.log"
DEPENDENCIES=("tar" "rclone" "pacman")
DRY_RUN=false
LIST=false
RESTORE=false
HELP=false
PACKAGES=false
RESTORE_PACKAGES=false
FILES=()

RESTORE_BACKUP=""
RESTORE_DESTINATION=""
RESTORE_PACKAGES_BACKUP=""

usage() {
    echo "Usage: ./backup.sh [OPTIONS] <file|directory> ...

Description:
    Creates compressed backups of files/directories and sends them
    to Google Drive.

Options:
    -r, --restore <backup> [destination]
        Restore a backup from Google Drive.
        If destination is provided, extract the backup there.

    -l, --list
        List available backups.

    -d, --dry-run
        Show what would be done without actually performing the backup.
    
    -p, --packages
        Save lists of installed official and AUR packages.

    -rp, --restore-packages <backup>
        Restore official and AUR packages from a package backup.

    -h, --help
        Show this help message.

Examples:
    ./backup.sh file.txt
    ./backup.sh file.txt ~/Documents
    ./backup.sh --restore backup.tar.gz
    ./backup.sh --restore backup.tar.gz ~/Restored
    ./backup.sh --list
    ./backup.sh --dry-run ~/Documents
    ./backup.sh --packages
    ./backup.sh --restore-packages packages-2026-09-20-21-30-00.txt"

    return 0
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

ctrl_c() {
    echo -e "\nBackup interrupted."
    log "Backup interrupted by user"

    exit 130
}

trap ctrl_c INT

file_compression() {
    BASE_NAME=$(basename "$1")
    DIR_NAME=$(dirname "$1")

    if [ ! -e "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"

        if [ $? -ne 0 ]; then
            echo "Error creating backup directory: $BACKUP_DIR"
            log "Error creating backup directory: $BACKUP_DIR"
            return 1
        fi
    fi
    
    if [ "$DRY_RUN" == false ]; then
        if [ -e "$1" ]; then

            log "Creating compressed file"
            tar -czf "$BACKUP_DIR/$BASE_NAME-$DATE.tar.gz" \
                -C "$DIR_NAME" "$BASE_NAME"

            if [ $? -ne 0 ]; then
                echo "Error creating backup for $1."
                log "Error creating backup for $1"
                return 1
            fi

            log "$1 compressed"
        else
            echo "$1 is not a file or directory."
            log "$1 is not a file or directory"
            return 1
        fi
    else
        if [ -e "$1" ]; then
            echo "[DRY-RUN] Would compress: $1"
            echo "[DRY-RUN] Would create: $BACKUP_DIR/$BASE_NAME-$DATE.tar.gz"
        else
            echo "[DRY-RUN] $1 is not a file or directory."
            return 1
        fi
    fi
}

restore() {
    if [[ "$#" -lt 1 || "$#" -gt 2 ]]; then
        echo "Usage: --restore <backup> [destination]"
        return 1
    fi

    echo "Restoring file from drive."
    log "Restoring file from drive"
    rclone copy "gdrive:files-backup/$1" "$HOME"

    if [ $? -ne 0 ]; then
        echo "Error restoring the file."
        log "Error restoring the file"
        return 1
    fi

    if [ "$#" -eq 2 ]; then
        if [ ! -d "$2" ]; then
            log "Creating destination directory"
            mkdir -p "$2"

            if [ $? -ne 0 ]; then
                echo "Error creating destination directory: $2"
                log "Error creating destination directory: $2"
                return 1
            fi
        fi

        echo "Extracting backup."
        log "Extracting backup"
        tar -xzf "$HOME/$1" -C "$2"

        if [ $? -ne 0 ]; then
            echo "Error extracting backup."
            log "Error extracting backup"
            return 1
        fi

        echo "$1 was restored and extracted to $2"
    else
        echo "$1 was restored to $HOME"
    fi
}

list() {
    log "Listing remote"
    rclone tree gdrive:files-backup

    if [ $? -ne 0 ]; then
        log "Error listing remote"
        return 1
    fi
    log "Remote listed"
}

check_dependencies() {
    has_failed=0

    for cmd in "${DEPENDENCIES[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "The required command $cmd was not found."
            log "The required command $cmd was not found"
            has_failed=1
        fi
    done

    if [ "$has_failed" -ne 0 ]; then
        echo "Please install the missing programs before continuing."
        return 1
    fi

    return 0
}

package_backup() {
    mkdir -p "$BACKUP_DIR"

    if [ $? -ne 0 ]; then
        echo "Error creating backup directory: $BACKUP_DIR"
        log "Error creating backup directory: $BACKUP_DIR"
        return 1
    fi

    echo "Saving official packages."
    log "Saving official packages"
    pacman -Qqen > "$BACKUP_DIR/packages-$DATE.txt"

    if [ $? -ne 0 ]; then
        echo "Error saving official packages."
        log "Error saving official packages"

        return 1
    fi

    echo "Saving AUR packages."
    log "Saving AUR packages"
    pacman -Qqem > "$BACKUP_DIR/aur-packages-$DATE.txt"

    if [ $? -ne 0 ]; then
        echo "Error saving AUR packages."
        log "Error saving AUR packages"

        return 1
    fi

    echo "Packages successfully saved."
    log "Packages successfully saved"
}

restore_packages(){
    if [[ "$#" -ne 1 ]]; then
        echo "Usage: --restore-packages <backup>"
        return 1
    fi

    TIMESTAMP="${1#packages-}"
    AUR_BACKUP="aur-packages-$TIMESTAMP"

    echo "Restoring packages from drive."
    log "Restoring packages from drive"
    rclone copy "gdrive:files-backup/$1" "$HOME"

    if [ $? -ne 0 ]; then
        echo "Error restoring the official packages file."
        log "Error restoring the official packages file"
        return 1
    fi

    rclone copy "gdrive:files-backup/$AUR_BACKUP" "$HOME"

    if [ $? -ne 0 ]; then
        echo "Error restoring the AUR packages file."
        log "Error restoring the AUR packages file"
        return 1
    fi

    pacman -S --needed - < "$HOME/$1"

    if [ $? -ne 0 ]; then
        echo "Error installing official packages."
        log "Error installing official packages"
        return 1
    fi

    if ! command -v yay >/dev/null 2>&1; then
        echo "Error: yay is required to restore AUR packages."
        log "Error: yay is required to restore AUR packages"
        return 1
    fi

    yay -S --needed - < "$HOME/$AUR_BACKUP"

    if [ $? -ne 0 ]; then
        echo "Error installing the AUR packages."
        log "Error installing the AUR packages"
        return 1
    fi
}

if [ "$#" -eq 0 ]; then
    echo "Usage: ./backup.sh <file|directory> [file|directory ...]"
    log "Error. No arguments entered."
    exit 1
fi

while [ "$#" -gt 0 ]; do
    case "$1" in
        -r | --restore)
            RESTORE=true

            shift

            if [ "$#" -ge 1 ]; then
                RESTORE_BACKUP="$1"
            fi

            if [ "$#" -ge 2 ]; then
                RESTORE_DESTINATION="$2"
                shift
            fi
            ;;

        -h | --help)
            HELP=true
            ;;

        -l | --list)
            LIST=true
            ;;

        -d | --dry-run)
            DRY_RUN=true
            ;;
        -p | --packages)
            PACKAGES=true
            ;;
        -rp | --restore-packages)
            RESTORE_PACKAGES=true

            shift

            if [ "$#" -ge 1 ]; then
                RESTORE_PACKAGES_BACKUP="$1"
            fi
            ;;
        *)
            if [[ "$1" == -* && ! -e "$1" ]]; then
                echo "Error: unknown option: $1"
                log "Error: unknown option: $1"
                exit 1
            fi

            FILES+=("$1")
            ;;
    esac

    shift
done

if [[ "$HELP" == true && ( "$LIST" == true || "$RESTORE" == true || "$DRY_RUN" == true || "$PACKAGES" == true || "$RESTORE_PACKAGES" == true || "${#FILES[@]}" -gt 0 ) ]]; then
    echo "Error: --help cannot be combined with other options or files."
    exit 1
fi

if [[ "$LIST" == true && ( "$RESTORE" == true || "$DRY_RUN" == true || "$PACKAGES" == true || "$RESTORE_PACKAGES" == true || "${#FILES[@]}" -gt 0 ) ]]; then
    echo "Error: --list cannot be combined with other options or files."
    exit 1
fi

if [[ "$RESTORE" == true && ( "$DRY_RUN" == true || "$PACKAGES" == true || "$RESTORE_PACKAGES" == true || "${#FILES[@]}" -gt 0 ) ]]; then
    echo "Error: --restore cannot be combined with other options or files."
    exit 1
fi

if [[ "$PACKAGES" == true && ( "$DRY_RUN" == true || "$RESTORE_PACKAGES" == true || "${#FILES[@]}" -gt 0 ) ]]; then
    echo "Error: --packages cannot be combined with other options or files."
    exit 1
fi

if [[ "$RESTORE_PACKAGES" == true && ( "$DRY_RUN" == true || "$PACKAGES" == true || "${#FILES[@]}" -gt 0 ) ]]; then
    echo "Error: --restore-packages cannot be combined with other options or files."
    exit 1
fi

if [[ "$DRY_RUN" == true && "${#FILES[@]}" -eq 0 ]]; then
    echo "Error: --dry-run requires at least one file or directory."
    exit 1
fi

if [[ "$RESTORE" == true && "$RESTORE_BACKUP" == "" ]]; then
    echo "Error: --restore must have a backup file."
    exit 1
fi

if [[ "$RESTORE_PACKAGES" == true && "$RESTORE_PACKAGES_BACKUP" == "" ]]; then
    echo "Error: --restore-packages must have a package backup file."
    exit 1

fi

if [ "$HELP" == true ]; then
    usage
    exit 0
fi

if [ "$LIST" == true ]; then
    check_dependencies

    if [ $? -ne 0 ]; then
        exit 1
    fi

    list

    if [ $? -ne 0 ]; then
        exit 1
    fi
fi

if [ "$RESTORE" == true ]; then
    check_dependencies

    if [ $? -ne 0 ]; then
        exit 1
    fi

    if [ -n "$RESTORE_DESTINATION" ]; then
        restore "$RESTORE_BACKUP" "$RESTORE_DESTINATION"
    else
        restore "$RESTORE_BACKUP"
    fi

    if [ $? -ne 0 ]; then
        exit 1
    fi
fi

if [ "$PACKAGES" == true ]; then
    check_dependencies

    if [ $? -ne 0 ]; then
        exit 1
    fi

    package_backup

    if [ $? -ne 0 ]; then
        exit 1
    fi

    log "Sending packages backup to drive"
    rclone copy "$BACKUP_DIR" "gdrive:files-backup" \
    --include "*.txt" \
    --progress

    if [ $? -ne 0 ]; then
        echo "rclone: Error sending to drive."
        log "rclone: Error sending to drive"
        exit 1
    fi

    echo "Packages backup successfully sent to Drive."
    log "Packages backup successfully sent to Drive"
fi

if [ "$RESTORE_PACKAGES" == true ]; then
    check_dependencies

    if [ $? -ne 0 ]; then
        exit 1
    fi

    restore_packages "$RESTORE_PACKAGES_BACKUP"

    if [ $? -ne 0 ]; then
        exit 1
    fi
fi

if [ "${#FILES[@]}" -gt 0 ]; then
    check_dependencies

    if [ $? -ne 0 ]; then
        exit 1
    fi

    for file in "${FILES[@]}"; do

        log "Starting backup"

        file_compression "$file"

        if [ $? -ne 0 ]; then
            exit 1
        fi
    done

    if [ "$DRY_RUN" == true ]; then
        log "[DRY-RUN] Sending to drive"
        rclone copy "$BACKUP_DIR" "gdrive:files-backup" \
            --progress \
            --dry-run
    else
        log "Sending to drive"
        rclone copy "$BACKUP_DIR" "gdrive:files-backup" \
            --progress
    fi

    if [ $? -ne 0 ]; then
        echo "rclone: Error sending to drive."
        log "rclone: Error sending to drive"
        exit 1
    else
        if [ "$DRY_RUN" == true ]; then
            echo "[DRY-RUN] Backup simulation completed."
            log "[DRY-RUN] Backup simulation completed"
        else
            echo "File(s) successfully sent to Drive."
            log "File(s) successfully sent to Drive"
            log "Backup completed successfully"
        fi
    fi
fi