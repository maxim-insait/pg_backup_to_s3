#!/bin/bash

# Check if the number of arguments is correct
if [ $# -ne 4 ]; then
    echo "Usage: $0 file_path_on_s3 container_id_or_name DATABASE_NAME USER_NAME"
    echo "Example: $0 s3://your-bucket-name/path/to/backup.tar.gz your_postgres_container_name your_database_name"
    exit 1
fi

S3_PATH=$1
DOCKER_CONTAINER=$2
DATABASE_NAME=$3
FILE=$(basename "$S3_PATH")
USER_NAME=$4

BACKUP_DIR=./tmp/

# Check if the AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if the AWS CLI is configured
if ! aws configure get aws_access_key_id &> /dev/null || ! aws configure get aws_secret_access_key &> /dev/null; then
    echo "AWS CLI is not configured. Please run 'aws configure' to configure it."
    exit 1
fi

# Check if the user has permission to access S3
if ! aws s3 ls &> /dev/null; then
    echo "You do not have permission to access S3. Please check your IAM permissions."
    exit 1
fi

# Download the backup file from S3
aws s3 cp "$S3_PATH" $BACKUP_DIR/

tar -zxvf $BACKUP_DIR/$FILE -C $BACKUP_DIR
if [ $? -ne 0 ]; then
    echo "Failed to extract backup from archive '$S3_PATH'."
    rm -rf $BACKUP_DIR
    exit 1
fi

table_count=$(docker exec -i $DOCKER_CONTAINER psql -U $USER_NAME -d $DATABASE_NAME -qt -c "select count(table_name) from information_schema.tables where table_schema NOT LIKE 'pg_%' and table_schema NOT LIKE 'public' and table_schema NOT LIKE 'information_schema';")

if [ $table_count -eq 0 ]; then
    echo "Database '$DATABASE_NAME' is empty applying backup."
else
    echo "Failed to apply backup: Database '$DATABASE_NAME' exists and has $table_count table(s) backup can only be applyed on empty database."
    rm -rf $BACKUP_DIR
    exit 1
fi

docker exec -i $DOCKER_CONTAINER psql -v -U "$USER_NAME" -d "$DATABASE_NAME"  < $BACKUP_DIR/backup.sql
if [ $? -ne 0 ]; then
    echo "Failed to restore backup, user name from backup '$S3_PATH' should exist in database."
    rm -rf $BACKUP_DIR
    exit 1
fi

rm -rf $BACKUP_DIR
echo "Bakup restored successfully."