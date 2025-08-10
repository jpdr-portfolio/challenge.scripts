# :hourglass: Información sobre entregables del challenge   
## 🗃️ Repositorios 

- https://github.com/jpdr-portfolio/challenge.scripts : Este repo.
- https://github.com/jpdr-portfolio/csv.generator : Generador de archivos CSV con valores aleatorios.
- https://github.com/jpdr-portfolio/batch.sale : Procesador Batch del CSV y carga en Tabla Postgres (challenge)

## :page_with_curl: Detalles del desarrollo

- Java 21
- Spring Boot, Spring Batch, Spring Data JCBC y JPA
- Builds con Gradle
- Base de datos PostgreSQL 16.
- Los nombres en toda la solución estan en idioma ingles
- Se requiere Docker (Desktop) para poder desplegar el ambiente mediante docker-compose
- Datos: Por cada archivo CSV, el procesador llamado __'batch.sale'__ registra el archivo en una tabla llamada 'sales_master'. Luego procesa el archivo insertando en la tabla 'sales_details'. Cuando finaliza actualiza el registro de la tabla 'sales_master'.
  - Entrada
    - Campos Archivo CSV:  
      - Id de registro (id)
      - Punto de Venta (pointOfSale)
      - Monto (amount)
      - Cantidad (quantity)
      - Temperatura (temperature)
      - Id de Cliente (customerId) (dato tipo Entero inventado para agregar volumen) 
      - Id de Producto (productId) (dato tipo UUID inventado para agregar volumen)
  - Salida
    - Campos Tabla sales_master (tabla que uso para identificar los registros de una carga determinada)
      - master_id (id que relaciona este archivo con los registros de la tabla sales_details)
      - file_name (nombre del archivo procesado)
      - creation_timestamp (timestamp de inicio del proceso)
      - status (estado PENDING o COMPLETED)
      - update_timestamp (timestamp de fin del proceso)   
    - Campos Tabla sales_details (tabla con los datos del CSV procesados)
      - master_id (id de la tabla sales_master)
      - details_id (id del registro en el CSV)
      - point_of_sale (punto de venta)
      - amount (monto)
      - quantity (cantidad)
      - taxes (monto x el impuesto que aplique al punto de venta)
      - customer_id (id del cliente)
      - product_id (id del producto)
      - creation_timestamp (timpestamp de generacion del registro)

## :floppy_disk: Instalación:

Se utiliza Docker Compose para generar el entorno para poder correrlo localmente.

- Clonar este repo:
  
  `git clone https://github.com/jpdr-portfolio/challenge.scripts.git`
- Dentro de la carpeta `challenge.scripts` ejecutar
  
  `create.bat`
- Se generará un stack en Docker con una instancia de Postgres, el Generador de CSV __'csv.generator'__ y el Procesador __'batch.sale'__ (la consigna del challenge).   
  Debería tardar 1:30 - 3:00 min.   
  Las imagenes ocupan sumadas unos 1.2 GB en total.   
  El volumen de Postgres aumenta en tamaño en cada ejecución.

## :books: Componentes (ir directo a [Pruebas](#chart_with_upwards_trend-pruebas) si el tiempo apremia)

### Generador __'csv.generator'__
- El generador tiene estos argumentos:
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





### Procesador __'batch.sale'__
El procesador toma como argumento el nombre del archivo CSV.
- Tiene espejada la carpeta ./csv
- También tiene definido el volumen interno /tmp/bsdata

Entonces, para disponiblizarle el archivo al procesador:   
- Opcion 1: Generar y Procesar archivo en volumen interno /tmp/bsdata.
- Opcion 2: Generar y Procesar archivo en volumen compartido /csv.
- Opcion 3: Generar archivo en volumen compartido /csv, copiarlo a /tmp/bsdata y Procesar desde el volumen interno.
    
Para evaluar performance del procesador, creo que es preferible usar la __Opcion 1__, porque la escritura y lectura del CSV se hace toda en el volumen interno, que es mas rapido.

##### Ejemplo de comando de ejecucion:
`docker compose run --rm batch-sale csvSalesFileName=/tmp/bsdata/lote.csv`




## :chart_with_upwards_trend: Pruebas   

Los tiempos de ejecución varian en funcion de donde se hagan las operaciones de lectura/escritura del archivo CSV principalmente.   

- Volumen interno de docker montado como /tmp/bsdata
- Volumen compartido con host en /csv

El volumen interno ofrece tiempos muy superiores al compartido.

### Opcion 1: Generacion y lectura en volumen interno /tmp/bsdata (con outputs de ejemplo)

Ejecutar estos comandos para probar con un archivo 'lote.csv' de 10.000.000 registros.

- Generar archivo
    
`docker compose run --rm csv-generator 10000000 /tmp/bsdata/lote.csv`   

  _Resultado:_   
  ``````
23:56:30.590 [main] INFO  - CSV generator v1.0.0.
23:56:30.604 [main] INFO  - Using 1 threads to generate 150000000 CSV records.
23:56:30.604 [main] INFO  - The file will be stored as /tmp/bsdata/lote.csv
23:56:30.635 [main] INFO  - Temporal file /tmp/3405257264593547376.tmp
23:56:30.635 [main] INFO  - Generating file...
23:59:19.074 [main] INFO  - Moving file to final path
00:00:01.766 [main] INFO  - File has been created: /tmp/bsdata/lote.csv
00:00:01.769 [main] INFO  - A total of 11319097153 bytes where generated
00:00:01.770 [main] INFO  - It took a total time of 211170 ms.
  ``````

- Procesar archivo
  
`docker compose run --rm batch-sale csvSalesFileName=/tmp/bsdata/lote.csv`

  _Resultado:_    
 ``````   [+] Creating 1/1   
     ✔ Container db  Running                                                                                           0.0s   
    [+] Running 1/1   
     ✔ Container challenge_jpdr-init-sql-1  Started                                                                    0.3s   
    
      .   ____          _            __ _ _
     /\\ / ___'_ __ _ _(_)_ __  __ _ \ \ \ \
    ( ( )\___ | '_ | '_| | '_ \/ _` | \ \ \ \
     \\/  ___)| |_)| | | | | || (_| |  ) ) ) )
      '  |____| .__|_| |_|_| |_\__, | / / / /
     =========|_|==============|___/=/_/_/_/
    
     :: Spring Boot ::                (v3.5.4)
    
    2025-08-10T00:03:42.942Z  INFO 1 --- [batch.sale] [           main] c.challenge.acc.batch.sale.Application   : Starting Application v0.0.1-SNAPSHOT using Java 21.0.8 with PID 1 (/app/app.jar started by root in /app)
    2025-08-10T00:03:42.946Z  INFO 1 --- [batch.sale] [           main] c.challenge.acc.batch.sale.Application   : No active profile set, falling back to 1 default profile: "default"
    2025-08-10T00:03:44.218Z  INFO 1 --- [batch.sale] [           main] .s.d.r.c.RepositoryConfigurationDelegate : Multiple Spring Data modules found, entering strict repository configuration mode
    2025-08-10T00:03:44.220Z  INFO 1 --- [batch.sale] [           main] .s.d.r.c.RepositoryConfigurationDelegate : Bootstrapping Spring Data JDBC repositories in DEFAULT mode.
    2025-08-10T00:03:44.275Z  INFO 1 --- [batch.sale] [           main] .RepositoryConfigurationExtensionSupport : Spring Data JDBC - Could not safely identify store assignment for repository candidate interface com.challenge.acc.batch.sale.repository.SalesMasterRepository; If you want this repository to be a JDBC repository, consider annotating your entities with one of these annotations: org.springframework.data.relational.core.mapping.Table.
    2025-08-10T00:03:44.276Z  INFO 1 --- [batch.sale] [           main] .s.d.r.c.RepositoryConfigurationDelegate : Finished Spring Data repository scanning in 42 ms. Found 0 JDBC repository interfaces.
    2025-08-10T00:03:44.297Z  INFO 1 --- [batch.sale] [           main] .s.d.r.c.RepositoryConfigurationDelegate : Multiple Spring Data modules found, entering strict repository configuration mode
    2025-08-10T00:03:44.299Z  INFO 1 --- [batch.sale] [           main] .s.d.r.c.RepositoryConfigurationDelegate : Bootstrapping Spring Data JPA repositories in DEFAULT mode.
    2025-08-10T00:03:44.341Z  INFO 1 --- [batch.sale] [           main] .s.d.r.c.RepositoryConfigurationDelegate : Finished Spring Data repository scanning in 31 ms. Found 1 JPA repository interface.
    2025-08-10T00:03:44.821Z  INFO 1 --- [batch.sale] [           main] com.zaxxer.hikari.HikariDataSource       : HikariPool-1 - Starting...
    2025-08-10T00:03:45.219Z  INFO 1 --- [batch.sale] [           main] com.zaxxer.hikari.pool.HikariPool        : HikariPool-1 - Added connection org.postgresql.jdbc.PgConnection@2dd8ff1d
    2025-08-10T00:03:45.222Z  INFO 1 --- [batch.sale] [           main] com.zaxxer.hikari.HikariDataSource       : HikariPool-1 - Start completed.
    2025-08-10T00:03:45.430Z  INFO 1 --- [batch.sale] [           main] o.hibernate.jpa.internal.util.LogHelper  : HHH000204: Processing PersistenceUnitInfo [name: default]
    2025-08-10T00:03:45.563Z  INFO 1 --- [batch.sale] [           main] org.hibernate.Version                    : HHH000412: Hibernate ORM core version 6.6.22.Final
    2025-08-10T00:03:45.659Z  INFO 1 --- [batch.sale] [           main] o.h.c.internal.RegionFactoryInitiator    : HHH000026: Second-level cache disabled
    2025-08-10T00:03:46.148Z  INFO 1 --- [batch.sale] [           main] o.s.o.j.p.SpringPersistenceUnitInfo      : No LoadTimeWeaver setup: ignoring JPA class transformer
    2025-08-10T00:03:46.350Z  INFO 1 --- [batch.sale] [           main] org.hibernate.orm.connections.pooling    : HHH10001005: Database info:
            Database JDBC URL [Connecting through datasource 'HikariDataSource (HikariPool-1)']
            Database driver: undefined/unknown
            Database version: 16.9
            Autocommit mode: undefined/unknown
            Isolation level: undefined/unknown
            Minimum pool size: undefined/unknown
            Maximum pool size: undefined/unknown
    2025-08-10T00:03:47.557Z  INFO 1 --- [batch.sale] [           main] o.h.e.t.j.p.i.JtaPlatformInitiator       : HHH000489: No JTA platform available (set 'hibernate.transaction.jta.platform' to enable JTA platform integration)
    2025-08-10T00:03:47.560Z  INFO 1 --- [batch.sale] [           main] j.LocalContainerEntityManagerFactoryBean : Initialized JPA EntityManagerFactory for persistence unit 'default'
    2025-08-10T00:03:48.950Z  INFO 1 --- [batch.sale] [           main] c.challenge.acc.batch.sale.Application   : Started Application in 6.821 seconds (process running for 7.624)
    2025-08-10T00:03:48.959Z  INFO 1 --- [batch.sale] [           main] o.s.b.a.b.JobLauncherApplicationRunner   : Running default command line with: [csvSalesFileName=/tmp/bsdata/lote.csv]
    2025-08-10T00:03:49.126Z  INFO 1 --- [batch.sale] [           main] o.s.b.c.l.s.TaskExecutorJobLauncher      : Job: [SimpleJob: [name=csvLoaderJob]] launched with the following parameters: [{'run.id':'{value=3, type=class java.lang.Long, identifying=true}','csvSalesFileName':'{value=/tmp/bsdata/lote.csv, type=class java.lang.String, identifying=true}'}]
    2025-08-10T00:03:49.168Z  INFO 1 --- [batch.sale] [           main] o.s.batch.core.job.SimpleStepHandler     : Executing step: [csvLoaderMasterCreatorStep]
    2025-08-10T00:03:49.256Z  INFO 1 --- [batch.sale] [           main] o.s.batch.core.step.AbstractStep         : Step: [csvLoaderMasterCreatorStep] executed in 87ms
    2025-08-10T00:03:49.279Z  INFO 1 --- [batch.sale] [           main] o.s.batch.core.job.SimpleStepHandler     : Executing step: [csvLoaderStep]
    2025-08-10T00:19:59.909Z  INFO 1 --- [batch.sale] [           main] o.s.batch.core.step.AbstractStep         : Step: [csvLoaderStep] executed in 16m10s629ms
    2025-08-10T00:19:59.940Z  INFO 1 --- [batch.sale] [           main] o.s.batch.core.job.SimpleStepHandler     : Executing step: [csvLoaderMasterUpdaterStep]
    2025-08-10T00:20:00.079Z  INFO 1 --- [batch.sale] [           main] o.s.batch.core.step.AbstractStep         : Step: [csvLoaderMasterUpdaterStep] executed in 139ms
    2025-08-10T00:20:00.095Z  INFO 1 --- [batch.sale] [           main] o.s.b.c.l.s.TaskExecutorJobLauncher      : Job: [SimpleJob: [name=csvLoaderJob]] completed with the following parameters: [{'run.id':'{value=3, type=class java.lang.Long, identifying=true}','csvSalesFileName':'{value=/tmp/bsdata/lote.csv, type=class java.lang.String, identifying=true}'}] and the following status: [COMPLETED] in 16m10s943ms
    2025-08-10T00:20:00.107Z  INFO 1 --- [batch.sale] [           main] j.LocalContainerEntityManagerFactoryBean : Closing JPA EntityManagerFactory for persistence unit 'default'
    2025-08-10T00:20:00.112Z  INFO 1 --- [batch.sale] [           main] com.zaxxer.hikari.HikariDataSource       : HikariPool-1 - Shutdown initiated...
    2025-08-10T00:20:00.127Z  INFO 1 --- [batch.sale] [           main] com.zaxxer.hikari.HikariDataSource       : HikariPool-1 - Shutdown completed.
``````

_Esta línea:_   
``````
    2025-08-10T00:20:00.095Z  INFO 1 --- [batch.sale] [           main] o.s.b.c.l.s.TaskExecutorJobLauncher      : Job: [SimpleJob: [name=csvLoaderJob]] completed with the following parameters: [{'run.id':'{value=3, type=class java.lang.Long, identifying=true}','csvSalesFileName':'{value=/tmp/bsdata/lote.csv, type=class java.lang.String, identifying=true}'}] and the following status: [COMPLETED] in 16m10s943ms
``````
_Indica que la ejecución del Job termino bien y duró 16 minutos aprox._





- Generar control contra BD   
  - (CMD)   
`docker compose exec db psql -U spring -d challenge -t -A -F"|" -c "select count(1),sum(amount),sum(quantity) from public.sales_details where master_id = ( select max(master_id) from public.sales_master where status = 'COMPLETED' ) group by master_id"  > ./csv/lote.db.control 2>&1`   
  - (PS|BASH)   
`docker compose exec db psql -U spring -d challenge -t -A -F'|' -c "select count(1),sum(amount),sum(quantity) from public.sales_details where master_id = ( select max(master_id) from public.sales_master where status = 'COMPLETED' ) group by master_id"  > ./csv/lote.db.control 2>&1`

  Resultado:   
  `(sin output)`


- Comparar visualmente totales de control CSV vs counts,sums de bd   
 (controlar que estos dos archivos sean iguales):   
  - (CMD)   
`type .\csv\lote.csv.control`  
`type .\csv\lote.db.control`   
  - (PS|BASH)   
`type ./csv/lote.csv.control`  
`type ./csv/lote.db.control`   

  Resultado:   
  `>type .\csv\lote.csv.control`   
  `150000000|7508255848393.30|74996896123`   
  `>type .\csv\lote.db.control`      
  `150000000|7508255848393.30|74996896123`

  _Se puede ver que los totales del CSV y los totales de la tabla coinciden._

### Opcion 2: Generacion y lectura en volumen montado /csv

Ejecutar estos comandos para probar con un archivo 'lote.csv' de 10.000.000 registros.   

- Generar archivo
    
`docker compose run --rm csv-generator 10000000 /csv/lote.csv`   

- Procesar archivo   
  
`docker compose run --rm batch-sale csvSalesFileName=/csv/lote.csv`

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



### Opcion 3: Generación en volumen montado /csv, subir a volumen interno /tmp/bsdata y procesar.

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

