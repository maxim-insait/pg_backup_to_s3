# postgres backup

## Create backup:
Copy script to the host of the postgres container

```bash
sudo chmod +x create_backup.sh
./create_backup.sh \
--bank_name <bank_name> \
--bank_pg_container <container_name> \
--bank_pg_db <database_name> \ # only this db will be backed up
--bank_pg_user <db_user>
```

## Restore backup:

| Make sure to follow the steps:

1. Backups has to be restored on empty database
2. There has to user with the same name as in the db where the bacup was originally made, i.e. if you backed up database where default user is postgres, database where you restore the backup should also have this default user
3. There has to be empty database with the same name as in backed up database.

```bash
sudo chmod +x create_backup.sh
./restore_backup.sh \
<s3_file_uri> \
<container_name> \
<database_name> \
<user_name>
```