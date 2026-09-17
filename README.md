# Backup Script

A small Bash script I built to make my own backups easier.

## About

This project started from a simple problem: I wanted an easy way to back up some of my files and keep those backups both on my computer and in Google Drive.

Instead of using an existing backup solution, I decided to build something myself. It gave me a practical way to learn and improve my Bash and Linux skills while solving a problem I actually had.

This is a **personal project**, made primarily for **my own use and learning**. It's not meant to be a complete or universal backup solution.

The project has also been a way for me to practice working with command-line tools, Git, error handling, logs, and `rclone`.

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

## Requirements

* Linux
* Bash
* `tar`
* `rclone`
* A configured Google Drive remote in `rclone`

## Configuration

The script currently uses the following paths and `rclone` settings:

| Setting                 | Value                 |
| ----------------------- | --------------------- |
| Local backup directory  | `~/Backups/`          |
| `rclone` remote         | `gdrive`              |
| Remote backup directory | `gdrive:files-backup` |
| Log file                | `backup.log`          |

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

A typical backup might look like this:

```text
$ ./backup.sh ~/Documents

Creating compressed file...
Backup created successfully.
Sending to drive...
Backup uploaded successfully.
Backup completed.
```

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

### Help

```bash
./backup.sh --help
```

or:

```bash
./backup.sh -h
```

## How it works

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

## Logs

The script keeps a log of its operations in:

```text
backup.log
```

The log records things such as backup operations, uploads, restores, errors, and interruptions.

The log file is excluded from Git through `.gitignore`.

## Security

This project is intended for personal use.

Sensitive information such as credentials, tokens, personal files, or private `rclone` configuration should never be committed to this repository.

## Current limitations

This is still a relatively small project and there are things I may improve over time.

For example:

* No automatic scheduled backups yet
* No built-in backup retention policy
* No built-in encryption
* Configuration is currently tailored to my own setup

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
* Logging
* Git and GitHub
* Testing different failure scenarios

## Future ideas

Some things I may experiment with in the future:

* Scheduled backups with `cron` or `systemd`
* Better configuration options
* Backup retention and cleanup
* More restore options
* Further improvements to error handling

---

**This is a personal learning project, built to solve a real problem I had and to get better at Bash and Linux along the way.**
