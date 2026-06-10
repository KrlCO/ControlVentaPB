USE [SISDOCU2];
GO

/*
    Arquitectura Hot / Cold para Control Venta Ruta
    Restriccion vigente:
    - NO usar transacciones distribuidas
    - NO depender de MSDTC

    Criterio:
    - HOT: ultimos 7 dias cerrados, excluyendo el dia actual
    - COLD: mes actual + mes anterior
    - La app consulta:
      - dbo.Cache_LiquidacionesRuta_Hot
      - dbo.Cache_LiquidacionesRuta_Mensual

    Nota:
    - Este script usa OPENQUERY para la lectura remota.
    - El swap de sinonimo usa transaccion local solamente.
*/

/* ============================================================
   PARTE 1: TABLAS A/B, INDICES Y SINONIMOS
   ============================================================ */

IF EXISTS (SELECT 1 FROM sys.synonyms WHERE name = 'Cache_LiquidacionesRuta_Hot')
    DROP SYNONYM dbo.Cache_LiquidacionesRuta_Hot;

IF EXISTS (SELECT 1 FROM sys.synonyms WHERE name = 'Cache_LiquidacionesRuta_Mensual')
    DROP SYNONYM dbo.Cache_LiquidacionesRuta_Mensual;

IF OBJECT_ID('dbo.Cache_LiquidacionesRuta_Hot_A', 'U') IS NOT NULL
    DROP TABLE dbo.Cache_LiquidacionesRuta_Hot_A;

IF OBJECT_ID('dbo.Cache_LiquidacionesRuta_Hot_B', 'U') IS NOT NULL
    DROP TABLE dbo.Cache_LiquidacionesRuta_Hot_B;

IF OBJECT_ID('dbo.Cache_LiquidacionesRuta_Mensual_A', 'U') IS NOT NULL
    DROP TABLE dbo.Cache_LiquidacionesRuta_Mensual_A;

IF OBJECT_ID('dbo.Cache_LiquidacionesRuta_Mensual_B', 'U') IS NOT NULL
    DROP TABLE dbo.Cache_LiquidacionesRuta_Mensual_B;
GO

CREATE TABLE dbo.Cache_LiquidacionesRuta_Hot_A
(
    IdCache                    INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    EMPRESA                    VARCHAR(10)   NULL,
    DOCUMENTO                  VARCHAR(50)   NULL,
    ORIGEN                     VARCHAR(10)   NULL,
    DESTINO                    VARCHAR(10)   NULL,
    LIQUIDACION                VARCHAR(50)   NULL,
    [ID TRANSACCION]           VARCHAR(50)   NULL,
    HORA_TRANSACCION           DATETIME      NULL,
    [TAG ID]                   VARCHAR(100)  NULL,
    BUS                        VARCHAR(20)   NULL,
    [METODO PAGO]              VARCHAR(30)   NULL,
    USUARIO                    VARCHAR(50)   NULL,
    FECHA_LIQUIDACION          DATETIME      NULL,
    [SUMA IMPORTE]             DECIMAL(18,2) NULL,
    [SUMA IMPORTE TRNSACCION]  DECIMAL(18,2) NULL,
    [SUMA DIFERENCIA]          DECIMAL(18,2) NULL,
    FECHA_PROCESO              DATETIME      NULL
);
GO

CREATE TABLE dbo.Cache_LiquidacionesRuta_Hot_B
(
    IdCache                    INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    EMPRESA                    VARCHAR(10)   NULL,
    DOCUMENTO                  VARCHAR(50)   NULL,
    ORIGEN                     VARCHAR(10)   NULL,
    DESTINO                    VARCHAR(10)   NULL,
    LIQUIDACION                VARCHAR(50)   NULL,
    [ID TRANSACCION]           VARCHAR(50)   NULL,
    HORA_TRANSACCION           DATETIME      NULL,
    [TAG ID]                   VARCHAR(100)  NULL,
    BUS                        VARCHAR(20)   NULL,
    [METODO PAGO]              VARCHAR(30)   NULL,
    USUARIO                    VARCHAR(50)   NULL,
    FECHA_LIQUIDACION          DATETIME      NULL,
    [SUMA IMPORTE]             DECIMAL(18,2) NULL,
    [SUMA IMPORTE TRNSACCION]  DECIMAL(18,2) NULL,
    [SUMA DIFERENCIA]          DECIMAL(18,2) NULL,
    FECHA_PROCESO              DATETIME      NULL
);
GO

CREATE TABLE dbo.Cache_LiquidacionesRuta_Mensual_A
(
    IdCache                    INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    EMPRESA                    VARCHAR(10)   NULL,
    DOCUMENTO                  VARCHAR(50)   NULL,
    ORIGEN                     VARCHAR(10)   NULL,
    DESTINO                    VARCHAR(10)   NULL,
    LIQUIDACION                VARCHAR(50)   NULL,
    [ID TRANSACCION]           VARCHAR(50)   NULL,
    HORA_TRANSACCION           DATETIME      NULL,
    [TAG ID]                   VARCHAR(100)  NULL,
    BUS                        VARCHAR(20)   NULL,
    [METODO PAGO]              VARCHAR(30)   NULL,
    USUARIO                    VARCHAR(50)   NULL,
    FECHA_LIQUIDACION          DATETIME      NULL,
    [SUMA IMPORTE]             DECIMAL(18,2) NULL,
    [SUMA IMPORTE TRNSACCION]  DECIMAL(18,2) NULL,
    [SUMA DIFERENCIA]          DECIMAL(18,2) NULL,
    FECHA_PROCESO              DATETIME      NULL
);
GO

CREATE TABLE dbo.Cache_LiquidacionesRuta_Mensual_B
(
    IdCache                    INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    EMPRESA                    VARCHAR(10)   NULL,
    DOCUMENTO                  VARCHAR(50)   NULL,
    ORIGEN                     VARCHAR(10)   NULL,
    DESTINO                    VARCHAR(10)   NULL,
    LIQUIDACION                VARCHAR(50)   NULL,
    [ID TRANSACCION]           VARCHAR(50)   NULL,
    HORA_TRANSACCION           DATETIME      NULL,
    [TAG ID]                   VARCHAR(100)  NULL,
    BUS                        VARCHAR(20)   NULL,
    [METODO PAGO]              VARCHAR(30)   NULL,
    USUARIO                    VARCHAR(50)   NULL,
    FECHA_LIQUIDACION          DATETIME      NULL,
    [SUMA IMPORTE]             DECIMAL(18,2) NULL,
    [SUMA IMPORTE TRNSACCION]  DECIMAL(18,2) NULL,
    [SUMA DIFERENCIA]          DECIMAL(18,2) NULL,
    FECHA_PROCESO              DATETIME      NULL
);
GO

CREATE INDEX IX_Cache_LiquidacionesRuta_Hot_A_UsuarioFecha
    ON dbo.Cache_LiquidacionesRuta_Hot_A (USUARIO, FECHA_LIQUIDACION DESC)
    INCLUDE (EMPRESA, LIQUIDACION, [METODO PAGO], [SUMA IMPORTE], [SUMA IMPORTE TRNSACCION], [SUMA DIFERENCIA], FECHA_PROCESO, HORA_TRANSACCION);
GO

CREATE INDEX IX_Cache_LiquidacionesRuta_Hot_A_Liquidacion
    ON dbo.Cache_LiquidacionesRuta_Hot_A (LIQUIDACION)
    INCLUDE (USUARIO, EMPRESA, FECHA_LIQUIDACION, [METODO PAGO]);
GO

CREATE INDEX IX_Cache_LiquidacionesRuta_Hot_B_UsuarioFecha
    ON dbo.Cache_LiquidacionesRuta_Hot_B (USUARIO, FECHA_LIQUIDACION DESC)
    INCLUDE (EMPRESA, LIQUIDACION, [METODO PAGO], [SUMA IMPORTE], [SUMA IMPORTE TRNSACCION], [SUMA DIFERENCIA], FECHA_PROCESO, HORA_TRANSACCION);
GO

CREATE INDEX IX_Cache_LiquidacionesRuta_Hot_B_Liquidacion
    ON dbo.Cache_LiquidacionesRuta_Hot_B (LIQUIDACION)
    INCLUDE (USUARIO, EMPRESA, FECHA_LIQUIDACION, [METODO PAGO]);
GO

CREATE INDEX IX_Cache_LiquidacionesRuta_Mensual_A_UsuarioFecha
    ON dbo.Cache_LiquidacionesRuta_Mensual_A (USUARIO, FECHA_LIQUIDACION DESC)
    INCLUDE (EMPRESA, LIQUIDACION, [METODO PAGO], [SUMA IMPORTE], [SUMA IMPORTE TRNSACCION], [SUMA DIFERENCIA], FECHA_PROCESO, HORA_TRANSACCION);
GO

CREATE INDEX IX_Cache_LiquidacionesRuta_Mensual_A_Liquidacion
    ON dbo.Cache_LiquidacionesRuta_Mensual_A (LIQUIDACION)
    INCLUDE (USUARIO, EMPRESA, FECHA_LIQUIDACION, [METODO PAGO]);
GO

CREATE INDEX IX_Cache_LiquidacionesRuta_Mensual_B_UsuarioFecha
    ON dbo.Cache_LiquidacionesRuta_Mensual_B (USUARIO, FECHA_LIQUIDACION DESC)
    INCLUDE (EMPRESA, LIQUIDACION, [METODO PAGO], [SUMA IMPORTE], [SUMA IMPORTE TRNSACCION], [SUMA DIFERENCIA], FECHA_PROCESO, HORA_TRANSACCION);
GO

CREATE INDEX IX_Cache_LiquidacionesRuta_Mensual_B_Liquidacion
    ON dbo.Cache_LiquidacionesRuta_Mensual_B (LIQUIDACION)
    INCLUDE (USUARIO, EMPRESA, FECHA_LIQUIDACION, [METODO PAGO]);
GO

CREATE SYNONYM dbo.Cache_LiquidacionesRuta_Hot FOR dbo.Cache_LiquidacionesRuta_Hot_A;
CREATE SYNONYM dbo.Cache_LiquidacionesRuta_Mensual FOR dbo.Cache_LiquidacionesRuta_Mensual_A;
GO

PRINT '[OK] Tablas, indices y sinonimos Cache_* creados correctamente.';
GO

/* ============================================================
   PARTE 2: JOB HOT - CADA 15 MINUTOS
   Excluye el dia actual porque la consulta diaria es directa
   ============================================================ */

USE [msdb];
GO

IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'JOB_Cache_LiquidacionesRuta_Hot_15Min')
    EXEC msdb.dbo.sp_delete_job @job_name = N'JOB_Cache_LiquidacionesRuta_Hot_15Min', @delete_unused_schedule = 1;
GO

BEGIN TRANSACTION;
DECLARE @ReturnCodeHot INT = 0;
DECLARE @jobIdHot BINARY(16);

IF NOT EXISTS (
    SELECT 1
    FROM msdb.dbo.syscategories
    WHERE name = N'[Uncategorized (Local)]' AND category_class = 1
)
BEGIN
    EXEC @ReturnCodeHot = msdb.dbo.sp_add_category
        @class = N'JOB',
        @type  = N'LOCAL',
        @name  = N'[Uncategorized (Local)]';
END

EXEC @ReturnCodeHot = msdb.dbo.sp_add_job
    @job_name         = N'JOB_Cache_LiquidacionesRuta_Hot_15Min',
    @enabled          = 1,
    @description      = N'Capa HOT de Ruta. Refresca ultimos 7 dias cerrados cada 15 minutos.',
    @category_name    = N'[Uncategorized (Local)]',
    @owner_login_name = N'sa',
    @job_id           = @jobIdHot OUTPUT;

EXEC @ReturnCodeHot = msdb.dbo.sp_add_jobstep
    @job_id            = @jobIdHot,
    @step_name         = N'STEP_1_Cargar_Tabla_Inactiva_Hot',
    @step_id           = 1,
    @on_success_action = 3,
    @on_fail_action    = 2,
    @subsystem         = N'TSQL',
    @database_name     = N'SISDOCU2',
    @command           = N'
SET NOCOUNT ON;

DECLARE @FechaInicio DATE = DATEADD(DAY, -7, CAST(GETDATE() AS DATE));
DECLARE @FechaFin    DATE = DATEADD(DAY, -1, CAST(GETDATE() AS DATE));

IF @FechaFin < @FechaInicio
BEGIN
    RAISERROR(''Ventana HOT invalida.'', 16, 1);
    RETURN;
END

DECLARE @TablaActiva SYSNAME;
SELECT @TablaActiva = PARSENAME(base_object_name, 1)
FROM sys.synonyms
WHERE name = ''Cache_LiquidacionesRuta_Hot'';

IF @TablaActiva IS NULL
BEGIN
    RAISERROR(''No existe el sinonimo dbo.Cache_LiquidacionesRuta_Hot.'', 16, 1);
    RETURN;
END

IF OBJECT_ID(''tempdb..#CargaRemotaHot'') IS NOT NULL
    DROP TABLE #CargaRemotaHot;

CREATE TABLE #CargaRemotaHot
(
    EMPRESA                   VARCHAR(10),
    DOCUMENTO                 VARCHAR(50),
    ORIGEN                    VARCHAR(10),
    DESTINO                   VARCHAR(10),
    LIQUIDACION               VARCHAR(50),
    [ID TRANSACCION]          VARCHAR(50),
    [TAG ID]                  VARCHAR(100),
    [HORA TRANSACCION]        VARCHAR(30),
    BUS                       VARCHAR(20),
    [METODO PAGO]             VARCHAR(30),
    USUARIO                   VARCHAR(50),
    FECHA_LIQUIDACION         VARCHAR(30),
    [SUMA IMPORTE]            DECIMAL(18,2),
    [SUMA IMPORTE TRNSACCION] DECIMAL(18,2),
    [SUMA DIFERENCIA]         DECIMAL(18,2)
);

DECLARE @RemoteSql NVARCHAR(MAX) =
    ''EXEC OFIVENT.dbo.SP_CONTROL_VENTA_RUTA_Q01 ''
    + ''@Modo = ''''''RANGO'''''''', ''
    + ''@FechaInicio = '''''''''' + CONVERT(VARCHAR(10), @FechaInicio, 120) + '''''''''', ''
    + ''@FechaFin = '''''''''' + CONVERT(VARCHAR(10), @FechaFin, 120) + '''''''''''';

DECLARE @Sql NVARCHAR(MAX) =
    N''INSERT INTO #CargaRemotaHot
      (
          EMPRESA, DOCUMENTO, ORIGEN, DESTINO, LIQUIDACION,
          [ID TRANSACCION], [TAG ID], [HORA TRANSACCION], BUS,
          [METODO PAGO], USUARIO, FECHA_LIQUIDACION,
          [SUMA IMPORTE], [SUMA IMPORTE TRNSACCION], [SUMA DIFERENCIA]
      )
      SELECT
          EMPRESA, DOCUMENTO, ORIGEN, DESTINO, LIQUIDACION,
          [ID TRANSACCION], [TAG ID], [HORA TRANSACCION], BUS,
          [METODO PAGO], USUARIO, FECHA_LIQUIDACION,
          [SUMA IMPORTE], [SUMA IMPORTE TRNSACCION], [SUMA DIFERENCIA]
      FROM OPENQUERY([172.19.0.52], '''''' + REPLACE(@RemoteSql, '''''''', '''''''''''''') + '''''')'';

EXEC sp_executesql @Sql;

IF NOT EXISTS (SELECT 1 FROM #CargaRemotaHot)
BEGIN
    RAISERROR(''La consulta remota HOT devolvio 0 filas. Abortando.'', 16, 1);
    RETURN;
END

IF @TablaActiva = ''Cache_LiquidacionesRuta_Hot_A''
BEGIN
    TRUNCATE TABLE dbo.Cache_LiquidacionesRuta_Hot_B;

    INSERT INTO dbo.Cache_LiquidacionesRuta_Hot_B
    (
        EMPRESA, DOCUMENTO, ORIGEN, DESTINO, LIQUIDACION,
        [ID TRANSACCION], HORA_TRANSACCION, [TAG ID], BUS,
        [METODO PAGO], USUARIO, FECHA_LIQUIDACION,
        [SUMA IMPORTE], [SUMA IMPORTE TRNSACCION], [SUMA DIFERENCIA], FECHA_PROCESO
    )
    SELECT
        EMPRESA, DOCUMENTO, ORIGEN, DESTINO, LIQUIDACION,
        [ID TRANSACCION], TRY_CONVERT(DATETIME, [HORA TRANSACCION]), [TAG ID], BUS,
        [METODO PAGO], USUARIO, TRY_CONVERT(DATETIME, FECHA_LIQUIDACION),
        [SUMA IMPORTE], [SUMA IMPORTE TRNSACCION], [SUMA DIFERENCIA], GETDATE()
    FROM #CargaRemotaHot;
END
ELSE
BEGIN
    TRUNCATE TABLE dbo.Cache_LiquidacionesRuta_Hot_A;

    INSERT INTO dbo.Cache_LiquidacionesRuta_Hot_A
    (
        EMPRESA, DOCUMENTO, ORIGEN, DESTINO, LIQUIDACION,
        [ID TRANSACCION], HORA_TRANSACCION, [TAG ID], BUS,
        [METODO PAGO], USUARIO, FECHA_LIQUIDACION,
        [SUMA IMPORTE], [SUMA IMPORTE TRNSACCION], [SUMA DIFERENCIA], FECHA_PROCESO
    )
    SELECT
        EMPRESA, DOCUMENTO, ORIGEN, DESTINO, LIQUIDACION,
        [ID TRANSACCION], TRY_CONVERT(DATETIME, [HORA TRANSACCION]), [TAG ID], BUS,
        [METODO PAGO], USUARIO, TRY_CONVERT(DATETIME, FECHA_LIQUIDACION),
        [SUMA IMPORTE], [SUMA IMPORTE TRNSACCION], [SUMA DIFERENCIA], GETDATE()
    FROM #CargaRemotaHot;
END

DROP TABLE #CargaRemotaHot;
';

EXEC @ReturnCodeHot = msdb.dbo.sp_add_jobstep
    @job_id            = @jobIdHot,
    @step_name         = N'STEP_2_SWAP_Sinonimo_Hot',
    @step_id           = 2,
    @on_success_action = 1,
    @on_fail_action    = 2,
    @subsystem         = N'TSQL',
    @database_name     = N'SISDOCU2',
    @command           = N'
SET NOCOUNT ON;

DECLARE @TablaActiva SYSNAME;
DECLARE @TablaDestino SYSNAME;
DECLARE @Filas INT;

SELECT @TablaActiva = PARSENAME(base_object_name, 1)
FROM sys.synonyms
WHERE name = ''Cache_LiquidacionesRuta_Hot'';

IF @TablaActiva IS NULL
BEGIN
    RAISERROR(''No existe el sinonimo dbo.Cache_LiquidacionesRuta_Hot.'', 16, 1);
    RETURN;
END

SET @TablaDestino =
    CASE
        WHEN @TablaActiva = ''Cache_LiquidacionesRuta_Hot_A'' THEN ''Cache_LiquidacionesRuta_Hot_B''
        ELSE ''Cache_LiquidacionesRuta_Hot_A''
    END;

IF @TablaDestino = ''Cache_LiquidacionesRuta_Hot_A''
    SELECT @Filas = COUNT(1) FROM dbo.Cache_LiquidacionesRuta_Hot_A;
ELSE
    SELECT @Filas = COUNT(1) FROM dbo.Cache_LiquidacionesRuta_Hot_B;

IF ISNULL(@Filas, 0) = 0
BEGIN
    RAISERROR(''La tabla destino HOT esta vacia. No se ejecuta el swap.'', 16, 1);
    RETURN;
END

BEGIN TRANSACTION;
    DROP SYNONYM dbo.Cache_LiquidacionesRuta_Hot;

    IF @TablaDestino = ''Cache_LiquidacionesRuta_Hot_A''
        CREATE SYNONYM dbo.Cache_LiquidacionesRuta_Hot FOR dbo.Cache_LiquidacionesRuta_Hot_A;
    ELSE
        CREATE SYNONYM dbo.Cache_LiquidacionesRuta_Hot FOR dbo.Cache_LiquidacionesRuta_Hot_B;
COMMIT TRANSACTION;
';

EXEC @ReturnCodeHot = msdb.dbo.sp_update_job
    @job_id = @jobIdHot,
    @start_step_id = 1;

EXEC @ReturnCodeHot = msdb.dbo.sp_add_jobschedule
    @job_id               = @jobIdHot,
    @name                 = N'SCH_Cache_LiquidacionesRuta_Hot_Cada15Min',
    @enabled              = 1,
    @freq_type            = 4,
    @freq_interval        = 1,
    @freq_subday_type     = 4,
    @freq_subday_interval = 15,
    @active_start_date    = 20260601,
    @active_start_time    = 0;

EXEC @ReturnCodeHot = msdb.dbo.sp_add_jobserver
    @job_id = @jobIdHot,
    @server_name = N'(local)';

COMMIT TRANSACTION;
GO

PRINT '[OK] JOB HOT configurado.';
GO

/* ============================================================
   PARTE 3: JOB COLD - CADA 1 HORA
   Mes actual + mes anterior
   ============================================================ */

USE [msdb];
GO

IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'JOB_Cache_LiquidacionesRuta_Cold_1Hora')
    EXEC msdb.dbo.sp_delete_job @job_name = N'JOB_Cache_LiquidacionesRuta_Cold_1Hora', @delete_unused_schedule = 1;
GO

BEGIN TRANSACTION;
DECLARE @ReturnCodeCold INT = 0;
DECLARE @jobIdCold BINARY(16);

IF NOT EXISTS (
    SELECT 1
    FROM msdb.dbo.syscategories
    WHERE name = N'[Uncategorized (Local)]' AND category_class = 1
)
BEGIN
    EXEC @ReturnCodeCold = msdb.dbo.sp_add_category
        @class = N'JOB',
        @type  = N'LOCAL',
        @name  = N'[Uncategorized (Local)]';
END

EXEC @ReturnCodeCold = msdb.dbo.sp_add_job
    @job_name         = N'JOB_Cache_LiquidacionesRuta_Cold_1Hora',
    @enabled          = 1,
    @description      = N'Capa COLD de Ruta. Refresca mes actual y mes anterior cada 1 hora.',
    @category_name    = N'[Uncategorized (Local)]',
    @owner_login_name = N'sa',
    @job_id           = @jobIdCold OUTPUT;

EXEC @ReturnCodeCold = msdb.dbo.sp_add_jobstep
    @job_id            = @jobIdCold,
    @step_name         = N'STEP_1_Cargar_Tabla_Inactiva_Cold',
    @step_id           = 1,
    @on_success_action = 3,
    @on_fail_action    = 2,
    @subsystem         = N'TSQL',
    @database_name     = N'SISDOCU2',
    @command           = N'
SET NOCOUNT ON;

DECLARE @FechaInicio DATE = DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 1, 0);
DECLARE @FechaFin    DATE = CAST(GETDATE() AS DATE);

DECLARE @TablaActiva SYSNAME;
SELECT @TablaActiva = PARSENAME(base_object_name, 1)
FROM sys.synonyms
WHERE name = ''Cache_LiquidacionesRuta_Mensual'';

IF @TablaActiva IS NULL
BEGIN
    RAISERROR(''No existe el sinonimo dbo.Cache_LiquidacionesRuta_Mensual.'', 16, 1);
    RETURN;
END

IF OBJECT_ID(''tempdb..#CargaRemotaCold'') IS NOT NULL
    DROP TABLE #CargaRemotaCold;

CREATE TABLE #CargaRemotaCold
(
    EMPRESA                   VARCHAR(10),
    DOCUMENTO                 VARCHAR(50),
    ORIGEN                    VARCHAR(10),
    DESTINO                   VARCHAR(10),
    LIQUIDACION               VARCHAR(50),
    [ID TRANSACCION]          VARCHAR(50),
    [TAG ID]                  VARCHAR(100),
    [HORA TRANSACCION]        VARCHAR(30),
    BUS                       VARCHAR(20),
    [METODO PAGO]             VARCHAR(30),
    USUARIO                   VARCHAR(50),
    FECHA_LIQUIDACION         VARCHAR(30),
    [SUMA IMPORTE]            DECIMAL(18,2),
    [SUMA IMPORTE TRNSACCION] DECIMAL(18,2),
    [SUMA DIFERENCIA]         DECIMAL(18,2)
);

DECLARE @RemoteSql NVARCHAR(MAX) =
    ''EXEC OFIVENT.dbo.SP_CONTROL_VENTA_RUTA_Q01 ''
    + ''@Modo = ''''''RANGO'''''''', ''
    + ''@FechaInicio = '''''''''' + CONVERT(VARCHAR(10), @FechaInicio, 120) + '''''''''', ''
    + ''@FechaFin = '''''''''' + CONVERT(VARCHAR(10), @FechaFin, 120) + '''''''''''';

DECLARE @Sql NVARCHAR(MAX) =
    N''INSERT INTO #CargaRemotaCold
      (
          EMPRESA, DOCUMENTO, ORIGEN, DESTINO, LIQUIDACION,
          [ID TRANSACCION], [TAG ID], [HORA TRANSACCION], BUS,
          [METODO PAGO], USUARIO, FECHA_LIQUIDACION,
          [SUMA IMPORTE], [SUMA IMPORTE TRNSACCION], [SUMA DIFERENCIA]
      )
      SELECT
          EMPRESA, DOCUMENTO, ORIGEN, DESTINO, LIQUIDACION,
          [ID TRANSACCION], [TAG ID], [HORA TRANSACCION], BUS,
          [METODO PAGO], USUARIO, FECHA_LIQUIDACION,
          [SUMA IMPORTE], [SUMA IMPORTE TRNSACCION], [SUMA DIFERENCIA]
      FROM OPENQUERY([172.19.0.52], '''''' + REPLACE(@RemoteSql, '''''''', '''''''''''''') + '''''')'';

EXEC sp_executesql @Sql;

IF NOT EXISTS (SELECT 1 FROM #CargaRemotaCold)
BEGIN
    RAISERROR(''La consulta remota COLD devolvio 0 filas. Abortando.'', 16, 1);
    RETURN;
END

IF @TablaActiva = ''Cache_LiquidacionesRuta_Mensual_A''
BEGIN
    TRUNCATE TABLE dbo.Cache_LiquidacionesRuta_Mensual_B;

    INSERT INTO dbo.Cache_LiquidacionesRuta_Mensual_B
    (
        EMPRESA, DOCUMENTO, ORIGEN, DESTINO, LIQUIDACION,
        [ID TRANSACCION], HORA_TRANSACCION, [TAG ID], BUS,
        [METODO PAGO], USUARIO, FECHA_LIQUIDACION,
        [SUMA IMPORTE], [SUMA IMPORTE TRNSACCION], [SUMA DIFERENCIA], FECHA_PROCESO
    )
    SELECT
        EMPRESA, DOCUMENTO, ORIGEN, DESTINO, LIQUIDACION,
        [ID TRANSACCION], TRY_CONVERT(DATETIME, [HORA TRANSACCION]), [TAG ID], BUS,
        [METODO PAGO], USUARIO, TRY_CONVERT(DATETIME, FECHA_LIQUIDACION),
        [SUMA IMPORTE], [SUMA IMPORTE TRNSACCION], [SUMA DIFERENCIA], GETDATE()
    FROM #CargaRemotaCold;
END
ELSE
BEGIN
    TRUNCATE TABLE dbo.Cache_LiquidacionesRuta_Mensual_A;

    INSERT INTO dbo.Cache_LiquidacionesRuta_Mensual_A
    (
        EMPRESA, DOCUMENTO, ORIGEN, DESTINO, LIQUIDACION,
        [ID TRANSACCION], HORA_TRANSACCION, [TAG ID], BUS,
        [METODO PAGO], USUARIO, FECHA_LIQUIDACION,
        [SUMA IMPORTE], [SUMA IMPORTE TRNSACCION], [SUMA DIFERENCIA], FECHA_PROCESO
    )
    SELECT
        EMPRESA, DOCUMENTO, ORIGEN, DESTINO, LIQUIDACION,
        [ID TRANSACCION], TRY_CONVERT(DATETIME, [HORA TRANSACCION]), [TAG ID], BUS,
        [METODO PAGO], USUARIO, TRY_CONVERT(DATETIME, FECHA_LIQUIDACION),
        [SUMA IMPORTE], [SUMA IMPORTE TRNSACCION], [SUMA DIFERENCIA], GETDATE()
    FROM #CargaRemotaCold;
END

DROP TABLE #CargaRemotaCold;
';

EXEC @ReturnCodeCold = msdb.dbo.sp_add_jobstep
    @job_id            = @jobIdCold,
    @step_name         = N'STEP_2_SWAP_Sinonimo_Cold',
    @step_id           = 2,
    @on_success_action = 1,
    @on_fail_action    = 2,
    @subsystem         = N'TSQL',
    @database_name     = N'SISDOCU2',
    @command           = N'
SET NOCOUNT ON;

DECLARE @TablaActiva SYSNAME;
DECLARE @TablaDestino SYSNAME;
DECLARE @Filas INT;

SELECT @TablaActiva = PARSENAME(base_object_name, 1)
FROM sys.synonyms
WHERE name = ''Cache_LiquidacionesRuta_Mensual'';

IF @TablaActiva IS NULL
BEGIN
    RAISERROR(''No existe el sinonimo dbo.Cache_LiquidacionesRuta_Mensual.'', 16, 1);
    RETURN;
END

SET @TablaDestino =
    CASE
        WHEN @TablaActiva = ''Cache_LiquidacionesRuta_Mensual_A'' THEN ''Cache_LiquidacionesRuta_Mensual_B''
        ELSE ''Cache_LiquidacionesRuta_Mensual_A''
    END;

IF @TablaDestino = ''Cache_LiquidacionesRuta_Mensual_A''
    SELECT @Filas = COUNT(1) FROM dbo.Cache_LiquidacionesRuta_Mensual_A;
ELSE
    SELECT @Filas = COUNT(1) FROM dbo.Cache_LiquidacionesRuta_Mensual_B;

IF ISNULL(@Filas, 0) = 0
BEGIN
    RAISERROR(''La tabla destino COLD esta vacia. No se ejecuta el swap.'', 16, 1);
    RETURN;
END

BEGIN TRANSACTION;
    DROP SYNONYM dbo.Cache_LiquidacionesRuta_Mensual;

    IF @TablaDestino = ''Cache_LiquidacionesRuta_Mensual_A''
        CREATE SYNONYM dbo.Cache_LiquidacionesRuta_Mensual FOR dbo.Cache_LiquidacionesRuta_Mensual_A;
    ELSE
        CREATE SYNONYM dbo.Cache_LiquidacionesRuta_Mensual FOR dbo.Cache_LiquidacionesRuta_Mensual_B;
COMMIT TRANSACTION;
';

EXEC @ReturnCodeCold = msdb.dbo.sp_update_job
    @job_id = @jobIdCold,
    @start_step_id = 1;

EXEC @ReturnCodeCold = msdb.dbo.sp_add_jobschedule
    @job_id               = @jobIdCold,
    @name                 = N'SCH_Cache_LiquidacionesRuta_Cold_CadaHora',
    @enabled              = 1,
    @freq_type            = 4,
    @freq_interval        = 1,
    @freq_subday_type     = 8,
    @freq_subday_interval = 1,
    @active_start_date    = 20260601,
    @active_start_time    = 0;

EXEC @ReturnCodeCold = msdb.dbo.sp_add_jobserver
    @job_id = @jobIdCold,
    @server_name = N'(local)';

COMMIT TRANSACTION;
GO

PRINT '[OK] JOB COLD configurado.';
GO
