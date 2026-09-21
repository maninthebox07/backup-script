# Backup Script

A small Bash script I built to make my own backups easier.

## About

This project started from a simple problem: I wanted an easy way to back up some of my files and keep those backups both on my computer and in Google Drive.

Instead of using an existing backup solution, I decided to build something myself. It gave me a practical way to learn and improve my Bash and Linux skills while solving a problem I actually had.

This is a **personal project**, made primarily for **my own use and learning**. It's not meant to be a complete or universal backup solution.

The project has also been a way for me to practice working with command-line tools, Git, error handling, logs, package management, scheduling, and `rclone`.

## What it does

The script can:

* Back up files and directories
* Compress backups into `.tar.gz` archives
* Add timestamps to backup filenames
* Store backups locally
* Upload backups to Google Drive using `rclone`
* Restore existing backups
* List available backups
* Preview operations with `--dry-run`
* Display usage information with `--help`
* Validate arguments and required dependencies
* Keep a log of operations
* Handle interruptions with `Ctrl+C`
* Save lists of explicitly installed official and AUR packages
* Restore official packages using `pacman`
* Restore AUR packages using `yay`
* Automatically remove old backups according to the configured retention policy
* Run scheduled backups using `systemd`

## Requirements

* Linux
* Bash
* `tar`
* `rclone`
* `pacman`
* A configured Google Drive remote in `rclone`

`yay` is only required when restoring AUR packages.

`systemd` is required for the optional automatic backup scheduling.

## Configuration

The script currently uses the following paths and `rclone` settings:

| Setting | Value |
| --- | --- |
| Local backup directory | `~/Backups/` |
| `rclone` remote | `gdrive` |
| Remote backup directory | `gdrive:files-backup` |
| Log file | `~/Projects/bash-projects/backup-script/backup.log` |

These names and paths were chosen for my own setup.

> **Note:** If you want to use different names or paths, you'll need to replace the corresponding values directly in `backup.sh`.

The script expects the `rclone` remote to be named `gdrive` and stores uploaded backups in `files-backup`.

## Installation

Clone the repository:

```bash
git clone git@github.com:maninthebox07/backup-script.git

cd backup-script
```

Make the script executable:

```bash
chmod +x backup.sh
```

Before using the script, configure `rclone` with a Google Drive remote named `gdrive`.

## Usage

### Create a backup

Back up a file:

```bash
./backup.sh /path/to/file
```

Or a directory:

```bash
./backup.sh /path/to/directory
```

Backups are stored locally in:

```text
~/Backups/
```

and then uploaded to:

```text
gdrive:files-backup
```

Each backup receives a timestamped filename.

### List backups

```bash
./backup.sh --list
```

or:

```bash
./backup.sh -l
```

Example:

```text
$ ./backup.sh --list

/

├── documents-2026-09-17-18-41-58.tar.gz

├── documents-2026-09-17-18-57-19.tar.gz

└── photos-2026-09-17-19-09-50.tar.gz
```

### Restore a backup

Restore a backup to the default location:

```bash
./backup.sh --restore backup-name.tar.gz
```

You can also specify a destination:

```bash
./backup.sh --restore backup-name.tar.gz /path/to/destination
```

When a destination is provided, the archive is extracted there.

`--restore` is an exclusive operation and cannot be combined with other options or backup targets.

### Dry run

Use `--dry-run` to see what the script would do without creating or uploading a new backup:

```bash
./backup.sh --dry-run /path/to/file
```

or:

```bash
./backup.sh -d /path/to/file
```

### Package backup

The script can save lists of explicitly installed packages:

```bash
./backup.sh --packages
```

or:

```bash
./backup.sh -p
```

This creates two files:

```text
packages-YYYY-MM-DD-HH-MM-SS.txt
aur-packages-YYYY-MM-DD-HH-MM-SS.txt
```

The first contains explicitly installed packages from the configured repositories, while the second contains explicitly installed foreign packages, such as AUR packages.

The package lists contain package names rather than exact package versions. This means restoration uses the versions currently available from the configured repositories or AUR at the time of restoration.

### Restore packages

To restore a package backup:

```bash
./backup.sh --restore-packages packages-2026-09-20-21-30-00.txt
```

The script automatically looks for the corresponding AUR package list using the same timestamp.

Official packages are restored using:

```bash
pacman
```

AUR packages are restored using:

```bash
yay
```

Packages that are already installed are skipped when possible.

> **Note:** AUR packages are not guaranteed to remain available or build successfully in the future. A package may be removed from the AUR, have changed sources or checksums, require manual intervention, or conflict with another installed package. Some AUR packages may therefore require manual restoration.

### Help

```bash
./backup.sh --help
```

or:

```bash
./backup.sh -h
```

## Backup retention

The script automatically removes older backups from the remote repository according to a retention policy.

The current configuration keeps:

* **4 latest backups per file/directory**
* **4 latest package backup sets**

For package backups, the official and AUR package lists are treated as a pair and share the same timestamp.

Retention is applied only after a successful upload.

This allows the remote repository to keep a limited history of backups without growing indefinitely.

## Automatic backups with systemd

The project includes optional `systemd` user units for automatically running backups.

The units are located in:

```text
systemd/
├── backup-files.service
├── backup-files.timer
├── backup-packages.service
└── backup-packages.timer
```

The file backup service runs:

```bash
./backup.sh ~/Projects/ ~/Pictures/ ~/DocumentosPessoais/
```

and is scheduled to run every 14 days.

The package backup service runs:

```bash
./backup.sh --packages
```

and is scheduled to run every Sunday at 14:00.

### Installing the systemd units

Copy the units to the user systemd directory:

```bash
mkdir -p ~/.config/systemd/user

cp systemd/*.service systemd/*.timer ~/.config/systemd/user/
```

Reload the user systemd manager:

```bash
systemctl --user daemon-reload
```

Enable the timers:

```bash
systemctl --user enable --now backup-files.timer
systemctl --user enable --now backup-packages.timer
```

Check their status:

```bash
systemctl --user list-timers --all
```

The services can also be tested manually:

```bash
systemctl --user start backup-files.service
systemctl --user start backup-packages.service
```

Logs from the services can be viewed with:

```bash
journalctl --user -u backup-files.service
journalctl --user -u backup-packages.service
```

The timers are configured as user services, so they operate within the user's environment and home directory.

## How it works

### File backups

The basic workflow is:

```text
Files / Directories

        │

        ▼

   tar (.tar.gz)

        │

        ▼

  ~/Backups/

        │

        ▼

     rclone

        │

        ▼

   Google Drive
```

Each backup gets a timestamp in its filename, so running the script multiple times creates separate backup files instead of replacing the previous ones.

The script uses `rclone copy` rather than `rclone sync`. This is intentional: I want Google Drive to act as a backup repository, so deleting a local file should not cause an existing remote backup to be deleted.

After a successful upload, the retention policy checks the existing remote backups and removes older ones when necessary.

### Package backups

Package backups use the local `pacman` database to generate package lists.

```text
        Installed packages

               │

        ┌──────┴──────┐

        ▼             ▼

   Official          AUR /
   packages         foreign

        │             │

        ▼             ▼

    pacman -Qqen   pacman -Qqem

        │             │

        └──────┬──────┘

               ▼

          Package lists

               │

               ▼

           Google Drive
```

During restoration, the official package list is passed to `pacman`, while the AUR package list is passed to `yay`.

Package backups are also subject to the retention policy.

### Automatic scheduling

Automatic backups are handled by `systemd` timers.

```text
backup-files.timer
        │
        ▼
backup-files.service
        │
        ▼
   backup.sh
```

and:

```text
backup-packages.timer
        │
        ▼
backup-packages.service
        │
        ▼
   backup.sh --packages
```

The timers are responsible only for scheduling the jobs. The actual backup logic remains inside `backup.sh`.

## Logs

The script keeps a log of its operations in:

```text
~/Projects/bash-projects/backup-script/backup.log
```

The log records things such as:

* Backup operations
* Uploads
* Restores
* Package operations
* Errors
* Interruptions

When backups are run through `systemd`, additional service logs can be inspected through the systemd journal.

The log file is excluded from Git through `.gitignore`.

## Security

This project is intended for personal use.

Sensitive information such as credentials, tokens, personal files, or private `rclone` configuration should never be committed to this repository.

The backup archives themselves may contain sensitive personal data, so they should be protected appropriately.

## Current limitations

This is still a relatively small project and there are things I may improve over time.

Current limitations include:

* No built-in encryption
* Configuration is currently tailored to my own setup
* Package backups store package names, not exact versions
* AUR packages may become unavailable or fail to build in the future
* Some AUR package conflicts or build problems may require manual intervention

These are not necessarily problems for my current use case, but they are areas I may explore in the future.

## What I learned

Building this project has been less about creating a sophisticated backup system and more about learning by actually building something.

Along the way, I've practiced:

* Bash scripting
* Linux command-line tools
* Argument parsing
* Exit codes and error handling
* File compression with `tar`
* Remote file management with `rclone`
* Package management with `pacman`
* AUR package management with `yay`
* Logging
* Backup retention and cleanup
* Scheduling with `systemd`
* `systemd` services and timers
* Testing failure scenarios
* Git and GitHub
* Working with branches and merges
* Writing documentation

## Future ideas

Some things I may experiment with in the future:

* Better configuration options
* More restore options
* Further improvements to error handling
* Better handling of package restoration failures
* Backup encryption
* Additional backup targets or storage providers

---

**This is a personal learning project, built to solve a real problem I had and to get better at Bash and Linux along the way.**