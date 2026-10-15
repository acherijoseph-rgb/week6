#!/bin/bash
# ==============================================================================
# Comprehensive Hands-On Lab: Backups, PITR, and Replication
# ==============================================================================

set -e

echo "=== Step 1: Take and Verify a Logical Backup ==="
mkdir -p ~/backups
pg_dump -Fc -f ~/backups/bootcamp.dump bootcamp
pg_restore --list ~/backups/bootcamp.dump | head

# Verify by restoring to a check database
createdb bootcamp_check || true
pg_restore -d bootcamp_check ~/backups/bootcamp.dump
echo "Verification: Logical backup successfully restored to bootcamp_check."

echo "=== Step 2: Enable WAL Archiving ==="
mkdir -p ~/backups/wal

# Configure PostgreSQL for WAL archiving
sudo bash -c 'cat >> /etc/postgresql/*/main/postgresql.conf <<EOF
wal_level = replica
archive_mode = on
archive_command = '\''cp %p /home/`whoami`/backups/wal/%f'\''
EOF'

sudo systemctl restart postgresql
echo "Verification: PostgreSQL restarted with WAL archiving enabled."

# Take base backup
pg_basebackup -D ~/backups/base -Ft -z -Xs -P
echo "Verification: Base backup completed in ~/backups/base."

echo "=== Step 3: Simulate Disaster & PITR Preparation ==="
echo "To execute the disaster simulation and recovery manually:"
echo "1. Run: psql -c \"SELECT now(); DELETE FROM students;\""
echo "2. Stop PostgreSQL: sudo systemctl stop postgresql"
echo "3. Restore the data directory from your base backup archive."
echo "4. Add the following lines to postgresql.conf:"
echo "   restore_command = 'cp ~/backups/wal/%f %p'"
echo "   recovery_target_time = 'YYYY-MM-DD HH:MM:SS'"
echo "5. Start PostgreSQL: sudo systemctl start postgresql"

echo "=== Step 4: Set Up Streaming Standby ==="
psql -c "CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'reppass';" || true

sudo bash -c 'echo "host replication replicator 127.0.0.1/32 md5" >> /etc/postgresql/*/main/pg_hba.conf'
sudo systemctl reload postgresql
echo "Verification: Replication user created and pg_hba.conf updated."

# Build standby directory
pg_basebackup -h 127.0.0.1 -U replicator -D ~/standby -R -P
echo "Verification: Standby cluster initialized at ~/standby."

echo "=== Step 5: Replication Health Query ==="
echo "Run the following query on the primary to verify replication lag:"
cat << 'EOF'
SELECT application_name, state,
       pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes
FROM pg_stat_replication;
EOF
