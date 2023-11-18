#!/bin/bash
#Source : https://mariadb.com/kb/en/full-backup-and-restore-with-mariabackup/

# Chemin du répertoire de sauvegarde
BACKUP_DIR="/votre/repertoire/de/sauvegarde/de/l'hote"

# Nom du conteneur MariaDB
DOCKER_CONTAINER_NAME="NomDeVotreConteneur"

# Nom d'utilisateur MariaDB
DB_USER="USERNAME"

# Mot de passe MariaDB
DB_PASSWORD="PASSWORD"

# Répertoire des logs
LOG_DIR="${BACKUP_DIR}logs"
mkdir -p $LOG_DIR

# Obtenez la liste des bases de données
DATABASES=$(docker exec $DOCKER_CONTAINER_NAME mariadb -u $DB_USER --password=$DB_PASSWORD -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql|sys)")

# Journalisation générale
LOG_FILE="${LOG_DIR}/backup_log_$(date +'%Y-%m-%d').txt"

# Début de la journalisation
echo "======== Début de la sauvegarde le $(date) ========" >> $LOG_FILE

# Sauvegarde de chaque base de données dans un fichier séparé
for DB in $DATABASES
do
    BACKUP_FILE="/media/$(date +'%Y-%m-%d')-$DB.sql"
    LOG_FILE_DB="${LOG_DIR}/backup_log_${DB}_$(date +'%Y-%m-%d').txt"
    
    echo "######## Extraction de la base de donnée : $DB ########" >> $LOG_FILE_DB 2>&1
    docker exec $DOCKER_CONTAINER_NAME mariadb-backup --backup --databases=$DB -u $DB_USER -p $DB_PASSWORD --target-dir /tmp/$DB  >> $LOG_FILE_DB 2>&1
    
    # Vérification de la réussite de la sauvegarde
    if [ $? -eq 0 ]; then
        echo "Sauvegarde de la base de données $DB réussie le $(date)" >> $LOG_FILE_DB
    else
        echo "Échec de la sauvegarde de la base de données $DB le $(date)" >> $LOG_FILE_DB
    fi
    
    echo "######## Compression de la sauvegarde SQL : $BACKUP_FILE ########"  >> $LOG_FILE_DB
    docker exec $DOCKER_CONTAINER_NAME bash -c "cd /tmp && tar czvf $BACKUP_FILE.tar.gz $DB" >> $LOG_FILE_DB 2>&1
    
    echo "######## Transfert de la sauvegarde du container vers l'hôte ########"  >> $LOG_FILE_DB
    docker cp $DOCKER_CONTAINER_NAME:$BACKUP_FILE.tar.gz $BACKUP_DIR  >> $LOG_FILE_DB 2>&1
    
    echo "######## Nettoyage des fichiers temporaires dans le container ########" >> $LOG_FILE_DB
    docker exec $DOCKER_CONTAINER_NAME rm -rf /tmp/$DB >> $LOG_FILE_DB 2>&1
    docker exec $DOCKER_CONTAINER_NAME rm $BACKUP_FILE.tar.gz >> $LOG_FILE_DB 2>&1
    
    cat $LOG_FILE_DB >> $LOG_FILE
done

# Fin de la journalisation
echo "======== Fin de la sauvegarde le $(date) ========" >> $LOG_FILE
