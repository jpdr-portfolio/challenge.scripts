@echo off
echo SCRIPT: -----  Create Script -----
echo SCRIPT: Eliminando recursos si existen
docker-compose down -v --rmi all --volumes
echo SCRIPT: Haciendo build de imagenes
docker-compose build --no-cache
echo SCRIPT: Levantando contenedores
docker-compose up -d
echo SCRIPT: Limpiando inicializador de tablas (init-sql)
docker-compose rm -sf init-sql
echo SCRIPT: Fin