#!/bin/bash

BACKUP_DIR="$HOME/Backups"
DATE=$(date +%Y-%m-%d-%H-%M-%S)
LOG_FILE="$HOME/Projects/bash-projects/backup-script/backup.log"
DRY_RUN=false
DEPENDENCIES=("tar" "rclone")

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

    -h, --help
        Show this help message.

Examples:
    ./backup.sh file.txt
    ./backup.sh file.txt ~/Documents
    ./backup.sh --restore backup.tar.gz
    ./backup.sh --restore backup.tar.gz ~/Restored
    ./backup.sh --list
    ./backup.sh --dry-run ~/Documents"

    return 0
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

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

if [ "$#" -eq 0 ]; then
    echo "Usage: ./backup.sh <file|directory> [file|directory ...]"
    log "Error. No arguments entered."
    exit 1
fi

while [ "$#" -gt 0 ]; do
    case "$1" in
        -r | --restore)
            check_dependencies

            if [ $? -ne 0 ]; then
                exit 1
            fi

            if [ "$#" -eq 2 ]; then
                restore "$2"
            elif [ "$#" -eq 3 ]; then
                restore "$2" "$3"
            else
                restore
            fi

            exit $?
            ;;

        -h | --help)
            usage
            exit 0
            ;;

        -l | --list)
            check_dependencies

            if [ $? -ne 0 ]; then
                exit 1
            fi

            list
            exit $?
            ;;

        -d | --dry-run)
            check_dependencies

            if [ $? -ne 0 ]; then
                exit 1
            fi

            DRY_RUN=true
            log "[DRY-RUN] Running with dry-run"
            ;;

        *)
            check_dependencies

            if [ $? -ne 0 ]; then
                exit 1
            fi

            log "Starting backup"
            file_compression "$1"

            if [ $? -ne 0 ]; then
                exit 1
            fi
            ;;
    esac

    shift
done

if [ "$DRY_RUN" == true ]; then
    log "[DRY-RUN] Sending to drive"
    rclone sync "$BACKUP_DIR" "gdrive:files-backup" \
        --backup-dir "gdrive:files-history/$DATE" \
        --progress \
        --dry-run
else
    log "Sending to drive"
    rclone sync "$BACKUP_DIR" "gdrive:files-backup" \
        --backup-dir "gdrive:files-history/$DATE" \
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
