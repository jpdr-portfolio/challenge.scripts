**** Inicializacion
Ejecutar create.bat
Se generará un stack con una instancia de Postgres, el Generador de CSV y el Procesador (la consigna del challenge).
Debería tardar 1:30 - 2:00 min.
Las imagenes ocupan sumadas unos 1.2 GB en total.
El volumen de postgres aumenta en tamaño en cada ejecución.

**** Componentes (ir directo a Pruebas si el tiempo apremia)

*** Generador
- El generador tiene estos argunmentos:
  - Cantidad de registros (obligatorio)
  - Nombre del archivo a generar (opcional)
- Generará 2 archivos:
  - Un archivo CSV a usar de input.
  - Un archivo de control con suma total de registros, monto y cantidad. 
- Dejará los archivos en la carpeta /csv local.
- A considerar:
  -         150 registros son ≈ 1 KB
  -  10.000.000 registros son ≈ 700 MB 
  - 150.000.000 registros son ≈ 10 GB

Ejemplos de ejecucion:
** Generar 10.000.000 reg, con nombre 'lote.csv' 
docker compose run --rm csv-generator 10000000 lote.csv
** Generar 150.000.000 reg, con nombre aleatorio
docker compose run --rm csv-generator 150000000


**** Procesador
El procesador toma como argumento el nombre del archivo CSV.
- Tiene espejada la carpeta ./csv
- Tiene un volumen propio /tmp/bsdata

Se puede pasar un archivo directamente generado en /csv (tarda mas), o copiar 
el archivo a /tmp/bsdata (tarda menos, pero el archivo se "duplica" en el host temporalmente 
al copiar y borrar).

Ejemplo de ejecucion:
docker compose run --rm batch-sale csvSalesFileName=/csv/lote.csv





**** Pruebas
Ejecutar estos comandos para probar con un archivo 'lote.csv' de 10.000.000 registros.

# generar archivo
docker compose run --rm csv-generator 10000000 lote.csv

# subir archivo a volumen
docker cp ./csv/lote.csv batch-sale:/tmp/bsdata

# borrar archivo de /csv
(CMD)
del .\csv\lote.csv
(PS|BASH)
del ./csv/lote.csv

# procesar archivo
docker compose run --rm batch-sale csvSalesFileName=/tmp/bsdata/lote.csv

# generar control contra BD
(CMD)
docker compose exec db psql -U spring -d challenge -t -A -F"|" -c "select count(1),sum(amount),sum(quantity) from public.sales_details where master_id = ( select max(master_id) from public.sales_master where status = 'COMPLETED' ) group by master_id"  > ./csv/lote.db.control 2>&1
(PS|BASH)
docker compose exec db psql -U spring -d challenge -t -A -F'|' -c "select count(1),sum(amount),sum(quantity) from public.sales_details where master_id = ( select max(master_id) from public.sales_master where status = 'COMPLETED' ) group by master_id"  > ./csv/lote.db.control 2>&1

# comparar visualmente totales de control csv vs count | sum de bd
# (controlar que estos dos archivos sean iguales):
(CMD)
type .\csv\lote.csv.control       
type .\csv\lote.db.control

(PS|BASH)
type ./csv/lote.csv.control
type ./csv/lote.db.control
