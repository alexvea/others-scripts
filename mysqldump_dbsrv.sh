#!/usr/bin/env bash
# script permettant de faire un dump de la BDD ocsweb du container dbsrv
# il conserve un jeu de dumps rĂ©cent de 7 jours maximum

SQL_DUMP_PATH="/root/sqldump"
MYSQL_ROOT_PASSWORD=$(cat $SQL_DUMP_PATH/.my.cnf | cut -d"=" -f2 | sed 's/"//g')

docker exec dbsrv sh -c 'exec mysqldump --databases ocsweb -uroot -p"$MYSQL_ROOT_PASSWORD"' > $SQL_DUMP_PATH/ocsweb$(date "+-%m-%d-%Y").sql
find $SQL_DUMP_PATH -type f -name "*.sql" -mtime +7 -exec rm -f {} \;
