/**
 * ============================================================================
 * PROCEDIMIENTO : SP_CONTROL_VENTA_RUTA_Q01_DIA
 * ============================================================================
 * SISTEMA       : OFIVENT
 * MÓDULO        : Reportes / Liquidaciones de Ruta (Control Diario)
 * AUTOR         : Carlos Enrique Cerquín Oropeza
 * FECHA         : 18 Noviembre 2025
 * MOTOR BD      : SQL Server
 * 
 * DESCRIPCIÓN:
 * Genera el reporte de control de ventas de pasajes de ruta (TCDOCU_RUTA) 
 * y encomiendas/carga (TCDOCU_CARG) enfocado en un usuario liquidador 
 * específico. El alcance está automatizado para revisar las liquidaciones 
 * de las últimas 24-48 horas (ayer y hoy).
 * 
 * CARACTERÍSTICAS TÉCNICAS:
 * - Optimización de Linked Server (Niubiz): En lugar de escanear fechas, 
 *   calcula dinámicamente el @MAX_ID de la tabla remota y retrocede 500,000 
 *   registros para hacer la lectura a VAULT súper rápida.
 * - Centralización mediante CTEs (Common Table Expressions): Agrupa lógica
 *   común en LIQ_USUARIO, RUTA_BASE, CARG_BASE, y TOTA1.
 * - Cruce Inteligente (OUTER APPLY): Empata el pago de Niubiz buscando 
 *   primero por TransactionID y respaldándose con el DocumentTravel.
 * 
 * EJEMPLO DE USO:
 *   EXEC SP_CONTROL_VENTA_RUTA_Q01_DIA @Usuario = 'USUARIO_LIQUIDADOR'
 * ============================================================================
 */
CREATE PROCEDURE [dbo].[SP_CONTROL_VENTA_RUTA_Q01_DIA]
(
    @Usuario VARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;

    SET @Usuario = UPPER(LTRIM(RTRIM(ISNULL(@Usuario, ''))));

    IF @Usuario = ''
    BEGIN
        RAISERROR('Por favor, especifica un usuario.', 16, 1);
        RETURN;
    END;

    DECLARE @VSFE_INIC DATE = CONVERT(DATE, DATEADD(DAY, -1, GETDATE()));
    DECLARE @VSFE_FINA DATE = CONVERT(DATE, GETDATE());

    -- Optimizacion NIUBIZ
    DECLARE @MAX_ID BIGINT;
    SELECT @MAX_ID = MAX(IDTMCALLNIU) FROM VAULT.NIUBIZ.dbo.TMCALL_NIU WITH(NOLOCK);
    
    DECLARE @MIN_ID BIGINT = @MAX_ID - 500000;
    IF @MIN_ID < 0 SET @MIN_ID = 0;

    DECLARE @SQL NVARCHAR(MAX);
    SET @SQL = N'
    SELECT IDTMCALLNIU, CompanyCode, DocumentTravel, TRANSACTIONID, TAGID, transactionDate, WALLET, transactionAmount 
    INTO #NIU_RAW
    FROM OPENQUERY([VAULT], ''
        SELECT IDTMCALLNIU, CompanyCode, DocumentTravel, TRANSACTIONID, TAGID, transactionDate, WALLET, transactionAmount
        FROM NIUBIZ.dbo.TMCALL_NIU WITH(NOLOCK)
        WHERE IDTMCALLNIU >= ' + CAST(@MIN_ID AS NVARCHAR(20)) + '
    '');

    CREATE TABLE #NIU (
        CompanyCode VARCHAR(10),
        DocumentTravel VARCHAR(20),
        TRANSACTIONID VARCHAR(50),
        ID_TRANSACCION_STR VARCHAR(50),
        TAG_ID VARCHAR(100),
        transactionDate DATETIME,
        METODO_PAGO VARCHAR(50),
        transactionAmount DECIMAL(10,2)
    );

    INSERT INTO #NIU (CompanyCode, DocumentTravel, TRANSACTIONID, ID_TRANSACCION_STR, TAG_ID, transactionDate, METODO_PAGO, transactionAmount)
    SELECT 
        CompanyCode,
        DocumentTravel,
        TRANSACTIONID,
        CAST(TRANSACTIONID AS VARCHAR(50)),
        CAST(TAGID AS VARCHAR(100)),
        transactionDate,
        UPPER(WALLET),
        CAST(REPLACE(ISNULL(transactionAmount, ''0''), '','', ''.'') AS DECIMAL(10,2))
    FROM #NIU_RAW
    WHERE ISNULL(CompanyCode, '''') <> '''' AND (ISNULL(DocumentTravel, '''') <> '''' OR ISNULL(TRANSACTIONID, '''') <> '''');

    CREATE INDEX IX_NIU_DOC  ON #NIU (CompanyCode, DocumentTravel);
    CREATE INDEX IX_NIU_TRAN ON #NIU (CompanyCode, TRANSACTIONID);

    ;WITH LIQ_USUARIO AS
    (
        SELECT
            L.CO_EMPR,
            L.NU_LIQI,
            UPPER(LTRIM(RTRIM(L.CO_USUA_CREA))) AS USUARIO,
            L.FE_LIQI,
            L.HO_LIQI
        FROM TCLIQI L WITH(NOLOCK)
        WHERE L.TI_LIQI = ''LRU''
          AND UPPER(LTRIM(RTRIM(L.CO_USUA_CREA))) = @UsuarioParam
          AND L.FE_LIQI >= @VSFE_INICParam
          AND L.FE_LIQI < DATEADD(DAY, 1, @VSFE_FINAParam)
    ),
    RUTA_BASE AS
    (
        SELECT
            T.CO_EMPR,
            T.NU_DOCU,
            T.CO_DEST_ORIG AS CO_ORIG,
            T.CO_DEST_FINA AS CO_DEST,
            ISNULL(T.NU_LIQI, ''SN LIQUIDAR'') AS NU_LIQI,
            T.IM_TOTA,
            CASE
                WHEN LEN(T.DE_OBSE) = 8 THEN T.DE_OBSE
                ELSE T.DE_OBSE_0002
            END AS CO_VEHI,
            T.NIU_TRAN_ID AS ID_TRAN,
            ISNULL(T.NU_ID_PAGO, '''') AS NU_ID_PAGO,
            L.USUARIO,
            L.FE_LIQI,
            L.HO_LIQI,
            CAST(T.FE_USUA_CREA AS DATETIME) AS FE_USUA_CREA
        FROM TCDOCU_RUTA T WITH(NOLOCK)
        INNER JOIN LIQ_USUARIO L
            ON T.CO_EMPR = L.CO_EMPR
           AND T.NU_LIQI = L.NU_LIQI
        WHERE T.CO_EMPR IN (''01'', ''39'')
          AND T.TI_DOCU = ''BLT''
          AND T.CO_ESTA_DOCU = ''ACT''
    ),
    CARG_BASE AS
    (
        SELECT
            T.CO_EMPR,
            T.NU_DOCU,
            T.CO_DEST_ORIG AS CO_ORIG,
            T.CO_DEST_FINA AS CO_DEST,
            ISNULL(T.NU_LIQI, ''SN LIQUIDAR'') AS NU_LIQI,
            T.IM_TOTA,
            T.DE_OBSE_0007 AS CO_VEHI,
            0 AS ID_TRAN,
            ISNULL(T.NU_ID_PAGO, '''') AS NU_ID_PAGO,
            L.USUARIO,
            L.FE_LIQI,
            L.HO_LIQI,
            CAST(T.FE_USUA_CREA AS DATETIME) AS FE_USUA_CREA
        FROM TCDOCU_CARG T WITH(NOLOCK)
        INNER JOIN LIQ_USUARIO L
            ON T.CO_EMPR = L.CO_EMPR
           AND T.NU_LIQI = L.NU_LIQI
        WHERE T.CO_EMPR IN (''01'', ''39'')
          AND T.TI_DOCU IN (''BOL'', ''FAC'')
          AND T.CO_ESTA_DOCU = ''ACT''
          AND T.NU_SECU IS NOT NULL
          AND (
                (ISNUMERIC(LEFT(T.NU_DOCU, 1)) = 0 AND ISNUMERIC(SUBSTRING(T.NU_DOCU, 2, 1)) = 0)
             OR (ISNUMERIC(LEFT(T.NU_DOCU, 1)) = 1 AND ISNULL(T.TI_LIQI, ''-'') = ''LRU'')
          )
    ),
    TOTA1 AS
    (
        SELECT
            R.CO_EMPR,
            R.NU_DOCU,
            R.CO_ORIG,
            R.CO_DEST,
            R.NU_LIQI,
            ISNULL(NI.ID_TRANSACCION_STR, '''') AS ID_TRANSACCION_STR,
            ISNULL(NI.TAG_ID, '''') AS TAG_ID,
            NI.transactionDate,
            ISNULL(R.CO_VEHI, ''-'') AS CO_VEHI,
            CASE
                WHEN NI.TRANSACTIONID IS NULL THEN ''EFECTIVO''
                ELSE ISNULL(NULLIF(NI.METODO_PAGO, ''''), ''PAGO QR'')
            END AS METODO_PAGO,
            R.IM_TOTA,
            ISNULL(NI.transactionAmount, 0) AS IMPORTE_TRNSACCION,
            R.USUARIO,
            DATEADD(
                SECOND,
                DATEDIFF(
                    SECOND,
                    CAST(''00:00:00'' AS TIME),
                    COALESCE(TRY_CONVERT(TIME(0), NULLIF(R.HO_LIQI, '''')), CAST(''00:00:00'' AS TIME))
                ),
                CAST(R.FE_LIQI AS DATETIME)
            ) AS FECHA_LIQUIDACION,
            R.FE_USUA_CREA
        FROM RUTA_BASE R
        LEFT JOIN #NIU NI_TRAN ON NI_TRAN.CompanyCode = R.CO_EMPR AND NI_TRAN.TRANSACTIONID = CAST(R.ID_TRAN AS VARCHAR(50)) AND R.ID_TRAN <> 0
        LEFT JOIN #NIU NI_DOC  ON NI_DOC.CompanyCode = R.CO_EMPR AND NI_DOC.DocumentTravel = R.NU_DOCU AND R.ID_TRAN = 0
        OUTER APPLY (
            SELECT 
                COALESCE(NI_TRAN.ID_TRANSACCION_STR, NI_DOC.ID_TRANSACCION_STR) AS ID_TRANSACCION_STR,
                COALESCE(NI_TRAN.TAG_ID, NI_DOC.TAG_ID) AS TAG_ID,
                COALESCE(NI_TRAN.transactionDate, NI_DOC.transactionDate) AS transactionDate,
                COALESCE(NI_TRAN.TRANSACTIONID, NI_DOC.TRANSACTIONID) AS TRANSACTIONID,
                COALESCE(NI_TRAN.METODO_PAGO, NI_DOC.METODO_PAGO) AS METODO_PAGO,
                COALESCE(NI_TRAN.transactionAmount, NI_DOC.transactionAmount) AS transactionAmount
        ) NI

        UNION ALL

        SELECT
            C.CO_EMPR,
            C.NU_DOCU,
            C.CO_ORIG,
            C.CO_DEST,
            C.NU_LIQI,
            ISNULL(NI.ID_TRANSACCION_STR, '''') AS ID_TRANSACCION_STR,
            ISNULL(NI.TAG_ID, '''') AS TAG_ID,
            NI.transactionDate,
            ISNULL(C.CO_VEHI, ''-'') AS CO_VEHI,
            CASE
                WHEN NI.TRANSACTIONID IS NULL THEN ''EFECTIVO''
                ELSE ISNULL(NULLIF(NI.METODO_PAGO, ''''), ''PAGO QR'')
            END AS METODO_PAGO,
            C.IM_TOTA,
            ISNULL(NI.transactionAmount, 0) AS IMPORTE_TRNSACCION,
            C.USUARIO,
            DATEADD(
                SECOND,
                DATEDIFF(
                    SECOND,
                    CAST(''00:00:00'' AS TIME),
                    COALESCE(TRY_CONVERT(TIME(0), NULLIF(C.HO_LIQI, '''')), CAST(''00:00:00'' AS TIME))
                ),
                CAST(C.FE_LIQI AS DATETIME)
            ) AS FECHA_LIQUIDACION,
            C.FE_USUA_CREA
        FROM CARG_BASE C
        LEFT JOIN #NIU NI_TRAN ON NI_TRAN.CompanyCode = C.CO_EMPR AND NI_TRAN.TRANSACTIONID = CAST(C.ID_TRAN AS VARCHAR(50)) AND C.ID_TRAN <> 0
        LEFT JOIN #NIU NI_DOC  ON NI_DOC.CompanyCode = C.CO_EMPR AND NI_DOC.DocumentTravel = C.NU_DOCU AND C.ID_TRAN = 0
        OUTER APPLY (
            SELECT 
                COALESCE(NI_TRAN.ID_TRANSACCION_STR, NI_DOC.ID_TRANSACCION_STR) AS ID_TRANSACCION_STR,
                COALESCE(NI_TRAN.TAG_ID, NI_DOC.TAG_ID) AS TAG_ID,
                COALESCE(NI_TRAN.transactionDate, NI_DOC.transactionDate) AS transactionDate,
                COALESCE(NI_TRAN.TRANSACTIONID, NI_DOC.TRANSACTIONID) AS TRANSACTIONID,
                COALESCE(NI_TRAN.METODO_PAGO, NI_DOC.METODO_PAGO) AS METODO_PAGO,
                COALESCE(NI_TRAN.transactionAmount, NI_DOC.transactionAmount) AS transactionAmount
        ) NI
    )
    SELECT
        CO_EMPR                             AS EMPRESA,
        NU_DOCU                             AS DOCUMENTO,
        CO_ORIG                             AS ORIGEN,
        CO_DEST                             AS DESTINO,
        NU_LIQI                             AS LIQUIDACION,
        ID_TRANSACCION_STR                  AS [ID TRANSACCION],
        transactionDate                     AS [HORA TRANSACCION],
        TAG_ID                              AS [TAG ID],
        CO_VEHI                             AS BUS,
        METODO_PAGO                         AS [METODO PAGO],
        USUARIO,
        FECHA_LIQUIDACION,
        FE_USUA_CREA                        AS HORA_EMISION,
        SUM(IM_TOTA)                        AS [SUMA IMPORTE],
        SUM(IMPORTE_TRNSACCION)             AS [SUMA IMPORTE TRNSACCION],
        SUM(IM_TOTA - IMPORTE_TRNSACCION)   AS [SUMA DIFERENCIA]
    FROM TOTA1
    GROUP BY
        CO_EMPR,
        NU_DOCU,
        CO_ORIG,
        CO_DEST,
        NU_LIQI,
        ID_TRANSACCION_STR,
        transactionDate,
        TAG_ID,
        CO_VEHI,
        METODO_PAGO,
        USUARIO,
        FECHA_LIQUIDACION,
        FE_USUA_CREA
    ORDER BY FECHA_LIQUIDACION DESC, DOCUMENTO;
    ';

    EXEC sp_executesql @SQL, 
        N'@UsuarioParam VARCHAR(50), @VSFE_INICParam DATE, @VSFE_FINAParam DATE', 
        @UsuarioParam = @Usuario, @VSFE_INICParam = @VSFE_INIC, @VSFE_FINAParam = @VSFE_FINA;
END;

