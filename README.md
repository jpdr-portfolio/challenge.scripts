# Scripts del challenge
## Repositorios

- https://github.com/jpdr-portfolio/challenge.scripts : este repo
- https://github.com/jpdr-portfolio/csv.generator : Generador de archivos CSV con valores aleatorios.
- https://github.com/jpdr-portfolio/batch.sale : Procesador Batch del CSV y carga en Tabla Postgres (challenge)

## Instrucciones

- Clonar este repo:
  
  `git clone https://github.com/jpdr-portfolio/challenge.scripts.git`
- Dentro de la carpeta ejecutar
  
  `create.bat`
- Se generará un stack en Docker con una instancia de Postgres, el Generador de CSV y el Procesador (la consigna del challenge).   
  Debería tardar 1:30 - 2:00 min.   
  Las imagenes ocupan sumadas unos 1.2 GB en total.   
  El volumen de Postgres aumenta en tamaño en cada ejecución.

## Componentes de stack (ir directo a [Pruebas](#pruebas) si el tiempo apremia)




### Generador
- El generador tiene estos argunmentos:
  - Cantidad de registros (obligatorio)
  - Nombre del archivo a generar (opcional)
- Generará 2 archivos:
  - Un archivo CSV a usar de input.
  - Un archivo de control con suma total de registros, monto y cantidad. 
- El archivo CSV debe tener como prefijo alguna de estas 2 rutas:
  - `/csv/`
  - `/tmp/bsdata/`   
  
  La primera `/csv/` es un volumen compartido con la carpeta desde donde ejecutamos los comandos (mucho mas lenta para R/W).   
  La segunda `/tmp/bsdata/` es un volumen interno de Docker. (mucho mas rapida para R/W).
- En caso de no enviar el nombre del archivo, se genera uno con timestamp como nombre en la carpeta /csv.  
- Dejará el archivo de control siempre en /csv.
- A considerar:   
  `         150 registros son ≈ 1 KB`   
  `  10.000.000 registros son ≈ 700 MB`    
  ` 150.000.000 registros son ≈ 10 GB`   

#### Ejemplos de comando de ejecucion:
##### Generar 10.000.000 reg, con nombre 'lote.csv' 
`docker compose run --rm csv-generator 10000000 /tmp/bsdata/lote.csv`
##### Generar 150.000.000 reg, con nombre aleatorio
`docker compose run --rm csv-generator 150000000`





### Procesador
El procesador toma como argumento el nombre del archivo CSV.
- Tiene espejada la carpeta ./csv
- También tiene definido el volumen interno /tmp/bsdata

Entonces, para disponiblizarle el archivo al procesador:   
- Opcion 1: Se puede pasar un archivo directamente generado en /tmp/bsdata
- Opcion 2: Copiar el archivo generado en /csv a /tmp/bsdata, y luego idem 1. 
- Opcion 3: Se puede pasar un archivo directamente generado en /csv.  
    
Es preferible usar la __Opcion 1__, porque la 3 agrega latencia de I/O al estar el volumen 'fuera' de Docker, y por ende tarda más el Generador y el Procesador.   
La opcion 3 tiene demora en la copia a Docker desde /csv a /tmp/bsdata.

##### Ejemplo de comando de ejecucion:
`docker compose run --rm batch-sale csvSalesFileName=/tmp/bsdata/lote.csv`




## Pruebas

### Opcion: Generacion y lectura interna en Docker /tmp/bsdata   

Ejecutar estos comandos para probar con un archivo 'lote.csv' de 10.000.000 registros.

- Generar archivo
    
`docker compose run --rm csv-generator 10000000 /tmp/bsdata/lote.csv`   

- Procesar archivo
  
`docker compose run --rm batch-sale csvSalesFileName=/tmp/bsdata/lote.csv`

- Generar control contra BD   
  - (CMD)   
`docker compose exec db psql -U spring -d challenge -t -A -F"|" -c "select count(1),sum(amount),sum(quantity) from public.sales_details where master_id = ( select max(master_id) from public.sales_master where status = 'COMPLETED' ) group by master_id"  > ./csv/lote.db.control 2>&1`   
  - (PS|BASH)   
`docker compose exec db psql -U spring -d challenge -t -A -F'|' -c "select count(1),sum(amount),sum(quantity) from public.sales_details where master_id = ( select max(master_id) from public.sales_master where status = 'COMPLETED' ) group by master_id"  > ./csv/lote.db.control 2>&1`

- Comparar visualmente totales de control CSV vs counts,sums de bd   
 (controlar que estos dos archivos sean iguales):   
  - (CMD)   
`type .\csv\lote.csv.control`  
`type .\csv\lote.db.control`   
  - (PS|BASH)   
`type ./csv/lote.csv.control`  
`type ./csv/lote.db.control`


### Opcion: Generacion volumen montado /csv, subir a Docker y lectura interna en Docker /tmp/bsdata      

Ejecutar estos comandos para probar con un archivo 'lote.csv' de 10.000.000 registros.   

- Generar archivo
    
`docker compose run --rm csv-generator 10000000 /csv/lote.csv`   

- Subir archivo a volumen interno
  
`docker cp ./csv/lote.csv batch-sale:/tmp/bsdata`

- Borrar archivo de /csv   
  - (CMD)   
`del .\csv\lote.csv`   
  - (PS|BASH)   
`del ./csv/lote.csv`

- Procesar archivo   
  
`docker compose run --rm batch-sale csvSalesFileName=/tmp/bsdata/lote.csv`

- Generar control contra BD   
  - (CMD)   
`docker compose exec db psql -U spring -d challenge -t -A -F"|" -c "select count(1),sum(amount),sum(quantity) from public.sales_details where master_id = ( select max(master_id) from public.sales_master where status = 'COMPLETED' ) group by master_id"  > ./csv/lote.db.control 2>&1`   
  - (PS|BASH)   
`docker compose exec db psql -U spring -d challenge -t -A -F'|' -c "select count(1),sum(amount),sum(quantity) from public.sales_details where master_id = ( select max(master_id) from public.sales_master where status = 'COMPLETED' ) group by master_id"  > ./csv/lote.db.control 2>&1`

- Comparar visualmente totales de control CSV vs counts,sums de bd   
 (controlar que estos dos archivos sean iguales):   
  - (CMD)   
`type .\csv\lote.csv.control`  
`type .\csv\lote.db.control`   
  - (PS|BASH)   
`type ./csv/lote.csv.control`  
`type ./csv/lote.db.control`

