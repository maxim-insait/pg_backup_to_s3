#! /bin/bash

BANK_NAME=""
BANK_PG_CONTAINER=""
BANK_PG_DB=""
BANK_PG_USER=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --bank_name) BANK_NAME="$2"; shift ;;
        --bank_pg_container) BANK_PG_CONTAINER="$2"; shift ;;
        --bank_pg_db) BANK_PG_DB="$2"; shift ;;
        --bank_pg_user) BANK_PG_USER="$2"; shift ;;
        --bank_pg_password) BANK_DB_PG_PASSWORD="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

if [ -z "$BANK_NAME" ] || [ -z "$BANK_PG_DB" ] || [ -z "$BANK_PG_USER" ] || [ -z "$BANK_PG_CONTAINER"]; then
    echo "Error: All parameters (bank_name,bank_pg_container, bank_pg_db, bank_pg_user) are required."
    exit 1
fi

CURRENT_DATE=$(date +"%Y_%m_%d")

mkdir -p db_backups

BANK_BACKUP_NAME="bank_db_backup_$CURRENT_DATE"
BANK_BACKUP_DIR_PATH="./db_backups/$BANK_BACKUP_NAME"
ARCHIVE_NAME=./db_backups/$BANK_BACKUP_NAME.tar.gz

#Platform schema in bank db

# docker exec -t $BANK_PG_CONTAINER pg_dump -U $BANK_PG_USER  -d $BANK_PG_DB dbname -Fc | tar -cvf $BANK_BACKUP_DIR_PATH.tar.gz
docker exec -t $BANK_PG_CONTAINER pg_dump -U $BANK_PG_USER  -d $BANK_PG_DB dbname > $BANK_BACKUP_DIR_PATH.sql
if [ $? -ne 0 ]; then
    echo "Failed to dump the database. Make sure the container '$BANK_PG_CONTAINER' exists and the credentials are correct."
    exit 1
fi

tar -cf $ARCHIVE_NAME $BANK_BACKUP_DIR_PATH.sql
if [ $? -ne 0 ]; then
    echo "Couldn't create tar archive."
    exit 1
fi

tar -tf $ARCHIVE_NAME > /dev/null
if [ $? -ne 0 ]; then
    echo "Tar archive is empty or corrupted."
    exit 1
fi

rm -rf $BANK_BACKUP_DIR_PATH.sql

aws s3 cp $ARCHIVE_NAME s3://insaitbackupsv1/$BANK_NAME/
if [ $? -ne 0 ]; then
    echo "Failed to upload the backup to S3. Check your AWS credentials and permissions."
    exit 1
fi

rm -rf $ARCHIVE_NAME

echo "Bank db backup uploaded to S3 successfully."