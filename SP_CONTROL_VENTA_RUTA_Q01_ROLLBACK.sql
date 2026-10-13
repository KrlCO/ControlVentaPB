-- ROLLBACK: definición vigente al 2026-10-12 (modify_date 2026-09-12 13:12:35), tal cual estaba en el servidor.
USE [OFIVENT]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* ============================================================================
   FIX 2026-09-12 · Deduplicación de #NIU por TRANSACTIONID
   ============================================================================
   Servidor : 172.19.0.52   BD : OFIVENT
   Objeto   : dbo.SP_CONTROL_VENTA_RUTA_Q01   (ALTER, no recrea)

   PROBLEMA
   El PASO 3 dejaba una sola transacción por documento:
       PARTITION BY CompanyCode, COALESCE(NULLIF(DocumentTravel,''), TRANSACTIONID)
   Si un boleto tiene más de una fila en TMCALL_NIU (reintento, doble cobro, o una
   reasignación que deja dos filas sobre el mismo DocumentTravel) y
   TCDOCU_RUTA.NIU_TRAN_ID apunta a la que se descartaba, el cruce se perdía y el
   boleto salía como EFECTIVO con toda su venta en la columna diferencia.

   CAMBIO (2 puntos, nada más)
   1. PASO 3 · el dedup pasa a ser PARTITION BY CompanyCode, TRANSACTIONID.
   2. PASO 4 · en los dos SELECT finales (RUTA y CARG), el LEFT JOIN NI_DOC pasa a
      OUTER APPLY ... TOP 1 ORDER BY transactionDate DESC, para que la rama legada
      siga quedándose con la transacción más reciente del documento.

   No cambia la firma, ni las columnas devueltas, ni el orden de las columnas.
   El contrato WITH RESULT SETS de SP_Cache_LiquidacionesRuta_Mensual_U01 (16
   columnas) sigue igual.

   VERIFICADO (sólo lectura, ventana 2026-09-10 → 2026-09-12, 48,307 documentos)
     filas devueltas        48,307  ->  48,307   (sin duplicación por el APPLY)
     PAGO QR          5,742 / 69,323.00  ->  5,744 / 69,345.00
     EFECTIVO                 42,565     ->      42,563
     documentos que cambian: 2, y son exactamente los dos que hoy están mal:
       BG15-0000060498  EFECTIVO -> PAGO QR  tran 996262557136878  14.00
       BH01-0000058439  EFECTIVO -> PAGO QR  tran 996262557139130   8.00

   ANTES DE APLICAR
     - Respaldar la definición vigente:
         SELECT OBJECT_DEFINITION(OBJECT_ID('dbo.SP_CONTROL_VENTA_RUTA_Q01'));
       (o usar FIX_01_dedup_Q01_ROLLBACK.sql, que ya la trae)
     - Aplicar fuera de la ventana en que corre el job de caché de .57
       (JOB_Actualizar_Cache_LiquidacionesRuta_Mensual, cada 15 min).

   PENDIENTE, NO INCLUIDO AQUÍ
     El OR EXISTS del PASO 1, que provoca el barrido de 55M filas. Es un cambio
     de otra naturaleza (rendimiento) y va en su propio script.
   ============================================================================ */

/**
 * ============================================================================
 * PROCEDIMIENTO : SP_CONTROL_VENTA_RUTA_Q01
 * ============================================================================
 * SISTEMA       : OFIVENT
 * MÓDULO        : Reportes / Consolidado de Ventas y Liquidaciones
 * AUTOR         : Carlos Enrique Cerquín Oropeza
 * FECHA         : 11 Marazo 2026
 * MOTOR BD      : SQL Server
 * 
 * DESCRIPCIÓN:
 * Es el procedimiento principal utilizado para conciliar y reportar las ventas 
 * de ruta (pasajes) y carga. Extrae datos de ventas y los cruza contra 
 * la pasarela de pagos remota (NIUBIZ en VAULT) para consolidar los montos.
 * Soporta ejecuciones flexibles: Por Mes, Día o Rango exacto de fechas.
 * 
 * CARACTERÍSTICAS TÉCNICAS:
 * - Ventana Deslizante Automática (Modo MES): Incluye automáticamente el mes
 *   anterior completo para garantizar que no se pierdan liquidaciones tardías.
 * - Detección Defensiva de Esquema (Rollout QR): Verifica la existencia de las 
 *   columnas NIU_TRAN_ID y CO_MEDI_PAGO en TCDOCU_CARG antes de armar la 
 *   consulta dinámica para tolerar distintas fases de despliegue en BDs.
 * - Cruce y Prioridad Dual: El emparejamiento con NIUBIZ se intenta primero
 *   usando TRANSACTION_ID (nuevo esquema) y cae como respaldo a DocumentTravel
 *   (esquema legado) de forma automática gracias al OUTER APPLY.
 * - Optimización Linked Server: Limita la búsqueda en la pasarela a los últimos
 *   500,000 registros para evitar escaneos pesados sobre el servidor VAULT.
 * 
 * EJEMPLO DE USO:
 *   EXEC SP_CONTROL_VENTA_RUTA_Q01 @Modo = 'MES'
 *   EXEC SP_CONTROL_VENTA_RUTA_Q01 @Modo = 'RANGO', @FechaInicio = '2026-09-01', @FechaFin = '2026-09-08'
 *
 * HISTORIAL:
 * - 2026-09-12: #NIU se deduplica por TRANSACTIONID (antes por documento, lo que
 *               descartaba transacciones a las que sí apuntaba NIU_TRAN_ID y hacía
 *               que el boleto saliera como EFECTIVO). La rama legada por
 *               DocumentTravel se resuelve con OUTER APPLY TOP 1 en el PASO 4.
 * ============================================================================
 */
ALTER PROCEDURE [dbo].[SP_CONTROL_VENTA_RUTA_Q01]
(
    @Modo VARCHAR(10) = 'MES',
    @FechaInicio DATE = NULL,
    @FechaFin DATE = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET FMTONLY OFF;

    DECLARE @VSFE_INIC DATE, @VSFE_FINA DATE;
    DECLARE @CurrentDate DATE = CAST(GETDATE() AS DATE);

    IF @Modo = 'MES'
    BEGIN
        -- ═══════════════════════════════════════════════════════════
        -- CAMBIO: Se amplía el rango para incluir el mes anterior
        -- completo + el mes en curso. Esto permite que documentos
        -- con FE_VIAJ del último día del mes anterior (ej. 31-ago)
        -- sigan apareciendo en la cache del mes siguiente.
        -- La ventana se desliza automáticamente cada mes.
        -- ═══════════════════════════════════════════════════════════
        SET @VSFE_INIC = DATEFROMPARTS(YEAR(DATEADD(MONTH, -1, @CurrentDate)), MONTH(DATEADD(MONTH, -1, @CurrentDate)), 1);
        SET @VSFE_FINA = EOMONTH(@CurrentDate);
    END
    ELSE IF @Modo = 'DIA'
    BEGIN
        SET @VSFE_INIC = @CurrentDate;
        SET @VSFE_FINA = @CurrentDate;
    END
    ELSE IF @Modo = 'RANGO'
    BEGIN
        IF @FechaInicio IS NULL OR @FechaFin IS NULL
        BEGIN
            RAISERROR('Especifica @FechaInicio y @FechaFin cuando Modo = RANGO', 16, 1);
            RETURN;
        END
        SET @VSFE_INIC = @FechaInicio;
        SET @VSFE_FINA = @FechaFin;
    END
    ELSE
    BEGIN
        RAISERROR('Modo inválido. Usa: MES, DIA o RANGO', 16, 1);
        RETURN;
    END

    -- ═══════════════════════════════════════════════════════════
    -- DETECCIÓN DEFENSIVA DE ESQUEMA (migración gradual QR/NIU)
    -- TCDOCU_RUTA ya trae NIU_TRAN_ID (se usaba desde antes).
    -- CO_MEDI_PAGO en RUTA y (NIU_TRAN_ID / CO_MEDI_PAGO) en CARG
    -- pueden no existir todavía según el servidor/etapa de rollout,
    -- así que se verifican en catálogo antes de referenciarlas.
    -- ═══════════════════════════════════════════════════════════
    DECLARE @HasRutaMedioPago BIT = 0;
    DECLARE @HasCargNiuTranId BIT = 0;
    DECLARE @HasCargMedioPago BIT = 0;

    IF COL_LENGTH('dbo.TCDOCU_RUTA', 'CO_MEDI_PAGO') IS NOT NULL
        SET @HasRutaMedioPago = 1;

    IF COL_LENGTH('dbo.TCDOCU_CARG', 'NIU_TRAN_ID') IS NOT NULL
        SET @HasCargNiuTranId = 1;

    IF COL_LENGTH('dbo.TCDOCU_CARG', 'CO_MEDI_PAGO') IS NOT NULL
        SET @HasCargMedioPago = 1;

    -- ═══════════════════════════════════════════════════════════
    -- PASO 1: Materializamos los documentos RUTA en tabla temporal
    -- ═══════════════════════════════════════════════════════════
    IF OBJECT_ID('tempdb..#RUTA') IS NOT NULL DROP TABLE #RUTA;
    IF OBJECT_ID('tempdb..#CARG') IS NOT NULL DROP TABLE #CARG;
    IF OBJECT_ID('tempdb..#NIU')  IS NOT NULL DROP TABLE #NIU;

    SELECT
        T.CO_EMPR,
        T.TI_DOCU,
        T.NU_DOCU,
        T.FE_VIAJ,
        T.CO_RUMB,
        T.NU_SECU,
        T.CO_DEST_ORIG                                              AS CO_ORIG,
        T.CO_DEST_FINA                                              AS CO_DEST,
        T.IM_TOTA,
        ISNULL(T.NU_LIQI, 'SN LIQUIDAR')                           AS NU_LIQI,
        CASE WHEN LEN(T.DE_OBSE) = 8 THEN T.DE_OBSE
             ELSE T.DE_OBSE_0002 END                                AS CO_VEHI,
        ISNULL(T.NIU_TRAN_ID, 0)                                    AS ID_TRAN,
        ISNULL(T.NU_ID_PAGO, '')                                    AS NU_ID_PAGO,
        CAST(T.FE_USUA_CREA AS DATETIME)                            AS FE_USUA_CREA,
        T.CO_MEDI_PAGO                                               AS CO_MEDI_PAGO
    INTO #RUTA
    FROM TCDOCU_RUTA T WITH(NOLOCK)
    WHERE T.CO_EMPR      IN ('01','39')
      AND T.TI_DOCU       = 'BLT'
      AND T.CO_ESTA_DOCU  = 'ACT'
      AND (
           T.FE_VIAJ BETWEEN @VSFE_INIC AND @VSFE_FINA
           OR EXISTS (SELECT 1 FROM TCLIQI LQ WITH(NOLOCK) WHERE LQ.CO_EMPR = T.CO_EMPR AND LQ.NU_LIQI = T.NU_LIQI AND LQ.TI_LIQI = 'LRU' AND LQ.FE_LIQI BETWEEN @VSFE_INIC AND @VSFE_FINA)
       );

    -- CO_MEDI_PAGO de RUTA es informativo/futuro; no condiciona el match
    -- (el match real se decide por ID_TRAN, ver PASO 4). Si la columna
    -- existe, la agregamos aparte para no romper el #RUTA si no existe.
    -- CO_MEDI_PAGO ya se incluye directamente en el SELECT INTO #RUTA

    -- ═══════════════════════════════════════════════════════════
    -- PASO 2: Materializamos los documentos CARG en tabla temporal
    -- NIU_TRAN_ID / CO_MEDI_PAGO se incorporan solo si existen en
    -- TCDOCU_CARG (rollout gradual). Se arma vía SQL dinámico porque
    -- SQL Server valida columnas en tiempo de compilación y no
    -- podemos referenciar una columna que podría no existir.
    -- ═══════════════════════════════════════════════════════════
    CREATE TABLE #CARG
    (
        CO_EMPR       CHAR(2)        NOT NULL,
        TI_DOCU       CHAR(3)        NOT NULL,
        NU_DOCU       VARCHAR(20)    NOT NULL,
        FE_VIAJ       DATE           NULL,
        CO_RUMB       VARCHAR(20)    NULL,
        NU_SECU       INT            NULL,
        CO_ORIG       VARCHAR(10)    NULL,
        CO_DEST       VARCHAR(10)    NULL,
        IM_TOTA       DECIMAL(10,2)  NULL,
        NU_LIQI       VARCHAR(20)    NULL,
        CO_VEHI       VARCHAR(20)    NULL,
        NU_ID_PAGO    VARCHAR(50)    NULL,
        FE_USUA_CREA  DATETIME       NULL,
        SERIE         VARCHAR(20)    NULL,
        TI_LIQI       VARCHAR(5)     NULL,
        ID_TRAN       BIGINT         NOT NULL DEFAULT(0),
        CO_MEDI_PAGO  VARCHAR(10)    NOT NULL DEFAULT('')
    );

    DECLARE @ColIdTran  NVARCHAR(200) = CASE WHEN @HasCargNiuTranId = 1 THEN N'ISNULL(T.NIU_TRAN_ID, 0)'  ELSE N'0'   END;
    DECLARE @ColMedPago NVARCHAR(200) = CASE WHEN @HasCargMedioPago = 1 THEN N'ISNULL(T.CO_MEDI_PAGO, '''')' ELSE N'''''' END;

    DECLARE @SqlCarg NVARCHAR(MAX) = N'
        INSERT INTO #CARG
        (
            CO_EMPR, TI_DOCU, NU_DOCU, FE_VIAJ, CO_RUMB, NU_SECU,
            CO_ORIG, CO_DEST, IM_TOTA, NU_LIQI, CO_VEHI, NU_ID_PAGO,
            FE_USUA_CREA, SERIE, TI_LIQI, ID_TRAN, CO_MEDI_PAGO
        )
        SELECT
            T.CO_EMPR,
            T.TI_DOCU,
            T.NU_DOCU,
            T.FE_VIAJ,
            T.CO_RUMB,
            T.NU_SECU,
            T.CO_DEST_ORIG                          ,
            T.CO_DEST_FINA                          ,
            T.IM_TOTA,
            ISNULL(T.NU_LIQI, ''SN LIQUIDAR'')      ,
            T.DE_OBSE_0007                          ,
            ISNULL(T.NU_ID_PAGO, '''')              ,
            CAST(T.FE_USUA_CREA AS DATETIME)        ,
            LEFT(T.NU_DOCU, CHARINDEX(''-'', T.NU_DOCU) - 1),
            ISNULL(T.TI_LIQI, ''-'')                ,
            ' + @ColIdTran + N',
            ' + @ColMedPago + N'
        FROM TCDOCU_CARG T WITH(NOLOCK)
        WHERE T.CO_EMPR      IN (''01'',''39'')
          AND T.TI_DOCU      IN (''BOL'',''FAC'')
          AND T.CO_ESTA_DOCU  = ''ACT''
          AND T.FE_VIAJ BETWEEN @P_INIC AND @P_FINA
          AND T.NU_SECU IS NOT NULL
          AND (
                (LEFT(T.NU_DOCU, CHARINDEX(''-'', T.NU_DOCU) - 1) NOT LIKE ''%[^0-9]%'')
             OR (LEFT(T.NU_DOCU, CHARINDEX(''-'', T.NU_DOCU) - 1) LIKE ''%[^0-9]%''
                 AND ISNULL(T.TI_LIQI, ''-'') = ''LRU'')
          );';

    EXEC sp_executesql @SqlCarg,
         N'@P_INIC DATE, @P_FINA DATE',
         @P_INIC = @VSFE_INIC, @P_FINA = @VSFE_FINA;

    -- Índices en temporales para acelerar los JOINs posteriores
    CREATE INDEX IX_RUTA_DOC ON #RUTA (CO_EMPR, NU_DOCU) INCLUDE (NU_LIQI, ID_TRAN, NU_ID_PAGO);
    CREATE INDEX IX_RUTA_TRAN ON #RUTA (CO_EMPR, ID_TRAN);
    CREATE INDEX IX_CARG_DOC ON #CARG (CO_EMPR, NU_DOCU) INCLUDE (NU_LIQI, NU_ID_PAGO);
    CREATE INDEX IX_CARG_TRAN ON #CARG (CO_EMPR, ID_TRAN);

    -- ═══════════════════════════════════════════════════════════
    -- PASO 3: Pre-agregamos TMCALL_NIU UNA SOLA VEZ
    --
    -- CAMBIO GRADUAL NIUBIZ: en registros nuevos, DocumentTravel ya
    -- NO se graba (queda NULL/''), WALLET pasa a valer siempre 'NIU',
    -- pero TRANSACTIONID y TAGID se siguen grabando igual que antes.
    -- Por eso el filtro de captura ahora trae filas tanto por
    -- DocumentTravel (esquema viejo) como por TRANSACTIONID
    -- (esquema nuevo, cruzando contra ID_TRAN ya materializado en
    -- #RUTA/#CARG). El particionado del ROW_NUMBER también se ajusta:
    -- si no hay DocumentTravel, se particiona por TRANSACTIONID para
    -- no mezclar transacciones distintas en un mismo grupo.
    -- ═══════════════════════════════════════════════════════════
CREATE TABLE #NIU_RAW (
    CompanyCode VARCHAR(10),
    DocumentTravel VARCHAR(50),
    TRANSACTIONID VARCHAR(50),
    TAGID VARCHAR(100),
    transactionDate VARCHAR(50),
    WALLET VARCHAR(50),
    transactionAmount VARCHAR(50)
);

DECLARE @MaxId INT = 0;
SELECT @MaxId = ISNULL(MAX_ID, 0)
FROM OPENQUERY([VAULT], 'SELECT MAX(idtmcallniu) AS MAX_ID FROM NIUBIZ.DBO.TMCALL_NIU');

DECLARE @MinId INT = @MaxId - 500000;
IF @MinId < 0 SET @MinId = 0;

DECLARE @Query NVARCHAR(MAX) = N'
    SELECT CompanyCode, DocumentTravel, TRANSACTIONID, TAGID, transactionDate, WALLET, transactionAmount
    FROM NIUBIZ.DBO.TMCALL_NIU
    WHERE CompanyCode IN (''01'',''39'')
      AND idtmcallniu >= ' + CAST(@MinId AS NVARCHAR(20)) + N'
';

DECLARE @SqlOpenQuery NVARCHAR(MAX) = N'
    INSERT INTO #NIU_RAW
    SELECT * FROM OPENQUERY([VAULT], ''' + REPLACE(@Query, '''', '''''') + N''')
';
EXEC sp_executesql @SqlOpenQuery;

CREATE NONCLUSTERED INDEX IX_NIU_RAW_DOC ON #NIU_RAW(DocumentTravel);
CREATE NONCLUSTERED INDEX IX_NIU_RAW_TRAN ON #NIU_RAW(TRANSACTIONID);

CREATE TABLE #NIU (
    CompanyCode CHAR(2), DocumentTravel VARCHAR(50), TRANSACTIONID VARCHAR(50), TAGID VARCHAR(100),
    transactionDate DATETIME, WALLET VARCHAR(50), transactionAmount DECIMAL(10,2),
    ID_TRANSACCION_STR VARCHAR(50), TAG_ID VARCHAR(100), METODO_PAGO VARCHAR(50)
);

INSERT INTO #NIU
SELECT
    N.CompanyCode, N.DocumentTravel, N.TRANSACTIONID, N.TAGID,
    COALESCE(TRY_CONVERT(DATETIME, N.transactionDate, 120), TRY_CONVERT(DATETIME, N.transactionDate, 126), TRY_CONVERT(DATETIME, N.transactionDate, 103), TRY_CONVERT(DATETIME, N.transactionDate, 101), TRY_CONVERT(DATETIME, N.transactionDate)),
    UPPER(N.WALLET), CAST(REPLACE(ISNULL(N.transactionAmount,'0'),',','.') AS DECIMAL(10,2)),
    CAST(N.TRANSACTIONID AS VARCHAR(50)), CAST(N.TAGID AS VARCHAR(100)), ISNULL(UPPER(N.WALLET), 'EFECTIVO')
FROM #NIU_RAW N
INNER JOIN (SELECT DISTINCT NU_DOCU FROM #RUTA) R ON N.DocumentTravel = R.NU_DOCU
WHERE N.CompanyCode IN ('01','39')
OPTION (HASH JOIN);

INSERT INTO #NIU
SELECT
    N.CompanyCode, N.DocumentTravel, N.TRANSACTIONID, N.TAGID,
    COALESCE(TRY_CONVERT(DATETIME, N.transactionDate, 120), TRY_CONVERT(DATETIME, N.transactionDate, 126), TRY_CONVERT(DATETIME, N.transactionDate, 103), TRY_CONVERT(DATETIME, N.transactionDate, 101), TRY_CONVERT(DATETIME, N.transactionDate)),
    UPPER(N.WALLET), CAST(REPLACE(ISNULL(N.transactionAmount,'0'),',','.') AS DECIMAL(10,2)),
    CAST(N.TRANSACTIONID AS VARCHAR(50)), CAST(N.TAGID AS VARCHAR(100)), ISNULL(UPPER(N.WALLET), 'EFECTIVO')
FROM #NIU_RAW N
INNER JOIN (SELECT DISTINCT NU_DOCU FROM #CARG) C ON N.DocumentTravel = C.NU_DOCU
WHERE N.CompanyCode IN ('01','39')
AND NOT EXISTS (SELECT 1 FROM #NIU X WHERE X.CompanyCode = N.CompanyCode AND ISNULL(X.DocumentTravel,'') = ISNULL(N.DocumentTravel,'') AND ISNULL(X.TRANSACTIONID,'') = ISNULL(N.TRANSACTIONID,''))
OPTION (HASH JOIN);

INSERT INTO #NIU
SELECT
    N.CompanyCode, N.DocumentTravel, N.TRANSACTIONID, N.TAGID,
    COALESCE(TRY_CONVERT(DATETIME, N.transactionDate, 120), TRY_CONVERT(DATETIME, N.transactionDate, 126), TRY_CONVERT(DATETIME, N.transactionDate, 103), TRY_CONVERT(DATETIME, N.transactionDate, 101), TRY_CONVERT(DATETIME, N.transactionDate)),
    UPPER(N.WALLET), CAST(REPLACE(ISNULL(N.transactionAmount,'0'),',','.') AS DECIMAL(10,2)),
    CAST(N.TRANSACTIONID AS VARCHAR(50)), CAST(N.TAGID AS VARCHAR(100)), ISNULL(UPPER(N.WALLET), 'EFECTIVO')
FROM #NIU_RAW N
INNER JOIN (SELECT DISTINCT CAST(ID_TRAN AS VARCHAR(50)) AS ID_TRAN FROM #RUTA WHERE ID_TRAN <> 0) R ON N.TRANSACTIONID = R.ID_TRAN
WHERE N.CompanyCode IN ('01','39')
AND NOT EXISTS (SELECT 1 FROM #NIU X WHERE X.CompanyCode = N.CompanyCode AND ISNULL(X.DocumentTravel,'') = ISNULL(N.DocumentTravel,'') AND ISNULL(X.TRANSACTIONID,'') = ISNULL(N.TRANSACTIONID,''))
OPTION (HASH JOIN);

INSERT INTO #NIU
SELECT
    N.CompanyCode, N.DocumentTravel, N.TRANSACTIONID, N.TAGID,
    COALESCE(TRY_CONVERT(DATETIME, N.transactionDate, 120), TRY_CONVERT(DATETIME, N.transactionDate, 126), TRY_CONVERT(DATETIME, N.transactionDate, 103), TRY_CONVERT(DATETIME, N.transactionDate, 101), TRY_CONVERT(DATETIME, N.transactionDate)),
    UPPER(N.WALLET), CAST(REPLACE(ISNULL(N.transactionAmount,'0'),',','.') AS DECIMAL(10,2)),
    CAST(N.TRANSACTIONID AS VARCHAR(50)), CAST(N.TAGID AS VARCHAR(100)), ISNULL(UPPER(N.WALLET), 'EFECTIVO')
FROM #NIU_RAW N
INNER JOIN (SELECT DISTINCT CAST(ID_TRAN AS VARCHAR(50)) AS ID_TRAN FROM #CARG WHERE ID_TRAN <> 0) C ON N.TRANSACTIONID = C.ID_TRAN
WHERE N.CompanyCode IN ('01','39')
AND NOT EXISTS (SELECT 1 FROM #NIU X WHERE X.CompanyCode = N.CompanyCode AND ISNULL(X.DocumentTravel,'') = ISNULL(N.DocumentTravel,'') AND ISNULL(X.TRANSACTIONID,'') = ISNULL(N.TRANSACTIONID,''))
OPTION (HASH JOIN);

-- ═══════════════════════════════════════════════════════════
-- FIX 2026-09-12: la deduplicación se hace por TRANSACTIONID,
-- no por documento.
--
-- Antes se particionaba por COALESCE(NULLIF(DocumentTravel,''),
-- TRANSACTIONID), o sea se dejaba UNA SOLA transacción por
-- documento (la más reciente). Cuando un boleto tiene más de una
-- fila en TMCALL_NIU (reintento, doble cobro, o una reasignación
-- que deja dos filas sobre el mismo DocumentTravel) y
-- TCDOCU_RUTA.NIU_TRAN_ID apunta a la que se descartaba, el cruce
-- se perdía y el boleto salía como EFECTIVO.
--
-- TRANSACTIONID es la clave real de la transacción y viene
-- siempre informada. El colapso "una fila por documento" que
-- necesita la rama legada se resuelve ahora en el PASO 4, con un
-- OUTER APPLY TOP 1, en vez de borrar filas aquí.
-- ═══════════════════════════════════════════════════════════
WITH CTE AS (
    SELECT ROW_NUMBER() OVER(PARTITION BY CompanyCode, TRANSACTIONID
                             ORDER BY transactionDate DESC) AS RN
    FROM #NIU
)
DELETE FROM CTE WHERE RN > 1;

    CREATE INDEX IX_NIU_DOC  ON #NIU (CompanyCode, DocumentTravel);
    CREATE INDEX IX_NIU_TRAN ON #NIU (CompanyCode, TRANSACTIONID);

    -- ═══════════════════════════════════════════════════════════
    -- PASO 4: Resultado final
    --
    -- CAMBIO: el match ahora prioriza ID_TRAN (NIU_TRAN_ID) cuando
    -- existe (<> 0); si no existe (documentos antiguos o de fuentes
    -- que aún no migran), cae al match por DocumentTravel = NU_DOCU,
    -- exactamente como funcionaba antes. Esto hace que el SP siga
    -- funcionando igual para todo lo que no tenga NIU_TRAN_ID, y
    -- automáticamente use el nuevo esquema para lo que sí lo tenga.
    -- ═══════════════════════════════════════════════════════════
    SELECT
        T.CO_EMPR                                                   AS EMPRESA,
        T.NU_DOCU                                                   AS DOCUMENTO,
        T.CO_ORIG                                                   AS ORIGEN,
        T.CO_DEST                                                   AS DESTINO,
        T.NU_LIQI                                                   AS LIQUIDACION,
        ISNULL(NI.ID_TRANSACCION_STR, '')                           AS [ID TRANSACCION],
        ISNULL(NI.TAG_ID, '')                                       AS [TAG ID],
        NI.transactionDate                                          AS [HORA TRANSACCION],
        ISNULL(T.CO_VEHI, '-')                                      AS BUS,
        CASE
            WHEN ISNULL(NI.METODO_PAGO, '') NOT IN ('', 'EFECTIVO') THEN 'PAGO QR'
            WHEN T.CO_MEDI_PAGO = 'YAP' THEN 'PAGO QR'
            ELSE 'EFECTIVO'
        END                                                         AS [METODO PAGO],
        ISNULL(LQ.CO_USUA_CREA, '')                                 AS USUARIO,
        CAST(LQ.FE_LIQI AS DATE)                                    AS FECHA_LIQUIDACION,
        T.FE_USUA_CREA                                              AS HORA_EMISION,
        SUM(T.IM_TOTA)                                              AS [SUMA IMPORTE],
        SUM(ISNULL(NI.transactionAmount, 0))                        AS [SUMA IMPORTE TRNSACCION],
        SUM(T.IM_TOTA - ISNULL(NI.transactionAmount, 0))            AS [SUMA DIFERENCIA]
    FROM #RUTA T
    LEFT JOIN #NIU NI_TRAN ON NI_TRAN.CompanyCode = T.CO_EMPR AND NI_TRAN.TRANSACTIONID = CAST(T.ID_TRAN AS VARCHAR(50)) AND T.ID_TRAN <> 0
    -- FIX 2026-09-12: #NIU ahora puede traer más de una fila por documento,
    -- así que la rama legada (sin NIU_TRAN_ID) se queda con la más reciente
    -- vía OUTER APPLY TOP 1 en lugar de un LEFT JOIN directo.
    OUTER APPLY (
        SELECT TOP 1
               D.ID_TRANSACCION_STR, D.TAG_ID, D.transactionDate,
               D.TRANSACTIONID, D.METODO_PAGO, D.transactionAmount
        FROM #NIU D
        WHERE T.ID_TRAN = 0
          AND D.CompanyCode    = T.CO_EMPR
          AND D.DocumentTravel = T.NU_DOCU
        ORDER BY D.transactionDate DESC, D.TRANSACTIONID DESC
    ) NI_DOC
    OUTER APPLY (
        SELECT 
            COALESCE(NI_TRAN.ID_TRANSACCION_STR, NI_DOC.ID_TRANSACCION_STR) AS ID_TRANSACCION_STR,
            COALESCE(NI_TRAN.TAG_ID, NI_DOC.TAG_ID) AS TAG_ID,
            COALESCE(NI_TRAN.transactionDate, NI_DOC.transactionDate) AS transactionDate,
            COALESCE(NI_TRAN.TRANSACTIONID, NI_DOC.TRANSACTIONID) AS TRANSACTIONID,
            COALESCE(NI_TRAN.METODO_PAGO, NI_DOC.METODO_PAGO) AS METODO_PAGO,
            COALESCE(NI_TRAN.transactionAmount, NI_DOC.transactionAmount) AS transactionAmount
    ) NI
    LEFT JOIN TCLIQI LQ WITH(NOLOCK)
        ON  LQ.CO_EMPR = T.CO_EMPR
        AND LQ.NU_LIQI = T.NU_LIQI
        AND LQ.TI_LIQI = 'LRU'
    GROUP BY
        T.CO_EMPR, T.NU_DOCU, T.CO_ORIG, T.CO_DEST, T.NU_LIQI,
        NI.ID_TRANSACCION_STR, NI.TAG_ID, NI.transactionDate,
        T.CO_VEHI, NI.TRANSACTIONID, NI.METODO_PAGO,
        LQ.CO_USUA_CREA, LQ.FE_LIQI,
        T.FE_USUA_CREA, T.CO_MEDI_PAGO

    UNION ALL

    SELECT
        T.CO_EMPR                                                   AS EMPRESA,
        T.NU_DOCU                                                   AS DOCUMENTO,
        T.CO_ORIG                                                   AS ORIGEN,
        T.CO_DEST                                                   AS DESTINO,
        T.NU_LIQI                                                   AS LIQUIDACION,
        ISNULL(NI.ID_TRANSACCION_STR, '')                           AS [ID TRANSACCION],
        ISNULL(NI.TAG_ID, '')                                       AS [TAG ID],
        NI.transactionDate                                          AS [HORA TRANSACCION],
        ISNULL(T.CO_VEHI, '-')                                      AS BUS,
        CASE
            WHEN ISNULL(NI.METODO_PAGO, '') NOT IN ('', 'EFECTIVO') THEN 'PAGO QR'
            WHEN T.CO_MEDI_PAGO = 'YAP' THEN 'PAGO QR'
            ELSE 'EFECTIVO'
        END                                                         AS [METODO PAGO],
        ISNULL(LQ.CO_USUA_CREA, '')                                 AS USUARIO,
        CAST(LQ.FE_LIQI AS DATE)                                    AS FECHA_LIQUIDACION,
        T.FE_USUA_CREA                                              AS HORA_EMISION,
        SUM(T.IM_TOTA)                                              AS [SUMA IMPORTE],
        SUM(ISNULL(NI.transactionAmount, 0))                        AS [SUMA IMPORTE TRNSACCION],
        SUM(T.IM_TOTA - ISNULL(NI.transactionAmount, 0))            AS [SUMA DIFERENCIA]
    FROM #CARG T
    LEFT JOIN #NIU NI_TRAN ON NI_TRAN.CompanyCode = T.CO_EMPR AND NI_TRAN.TRANSACTIONID = CAST(T.ID_TRAN AS VARCHAR(50)) AND T.ID_TRAN <> 0
    -- FIX 2026-09-12: #NIU ahora puede traer más de una fila por documento,
    -- así que la rama legada (sin NIU_TRAN_ID) se queda con la más reciente
    -- vía OUTER APPLY TOP 1 en lugar de un LEFT JOIN directo.
    OUTER APPLY (
        SELECT TOP 1
               D.ID_TRANSACCION_STR, D.TAG_ID, D.transactionDate,
               D.TRANSACTIONID, D.METODO_PAGO, D.transactionAmount
        FROM #NIU D
        WHERE T.ID_TRAN = 0
          AND D.CompanyCode    = T.CO_EMPR
          AND D.DocumentTravel = T.NU_DOCU
        ORDER BY D.transactionDate DESC, D.TRANSACTIONID DESC
    ) NI_DOC
    OUTER APPLY (
        SELECT 
            COALESCE(NI_TRAN.ID_TRANSACCION_STR, NI_DOC.ID_TRANSACCION_STR) AS ID_TRANSACCION_STR,
            COALESCE(NI_TRAN.TAG_ID, NI_DOC.TAG_ID) AS TAG_ID,
            COALESCE(NI_TRAN.transactionDate, NI_DOC.transactionDate) AS transactionDate,
            COALESCE(NI_TRAN.TRANSACTIONID, NI_DOC.TRANSACTIONID) AS TRANSACTIONID,
            COALESCE(NI_TRAN.METODO_PAGO, NI_DOC.METODO_PAGO) AS METODO_PAGO,
            COALESCE(NI_TRAN.transactionAmount, NI_DOC.transactionAmount) AS transactionAmount
    ) NI
    LEFT JOIN TCLIQI LQ WITH(NOLOCK)
        ON  LQ.CO_EMPR = T.CO_EMPR
        AND LQ.NU_LIQI = T.NU_LIQI
        AND LQ.TI_LIQI = 'LRU'
    GROUP BY
        T.CO_EMPR, T.NU_DOCU, T.CO_ORIG, T.CO_DEST, T.NU_LIQI,
        NI.ID_TRANSACCION_STR, NI.TAG_ID, NI.transactionDate,
        T.CO_VEHI, NI.TRANSACTIONID, NI.METODO_PAGO,
        LQ.CO_USUA_CREA, LQ.FE_LIQI,
        T.FE_USUA_CREA, T.CO_MEDI_PAGO

    ORDER BY DOCUMENTO;

    -- Limpieza
    DROP TABLE IF EXISTS #RUTA;
    DROP TABLE IF EXISTS #CARG;
    DROP TABLE IF EXISTS #NIU;

END
GO
