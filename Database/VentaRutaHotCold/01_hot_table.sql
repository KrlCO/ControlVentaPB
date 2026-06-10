USE [SISDOCU2];
GO

IF OBJECT_ID('dbo.Cache_LiquidacionesRuta_Hot', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Cache_LiquidacionesRuta_Hot
    (
        IdCache                    INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        EMPRESA                    VARCHAR(10)  NULL,
        DOCUMENTO                  VARCHAR(50)  NULL,
        ORIGEN                     VARCHAR(10)  NULL,
        DESTINO                    VARCHAR(10)  NULL,
        LIQUIDACION                VARCHAR(50)  NULL,
        [ID TRANSACCION]           VARCHAR(50)  NULL,
        [TAG ID]                   VARCHAR(100) NULL,
        HORA_TRANSACCION           DATETIME     NULL,
        BUS                        VARCHAR(20)  NULL,
        [METODO PAGO]              VARCHAR(30)  NULL,
        USUARIO                    VARCHAR(50)  NULL,
        FECHA_LIQUIDACION          DATETIME     NULL,
        FECHA_PROCESO              DATETIME     NULL,
        [SUMA IMPORTE]             DECIMAL(18,2) NULL,
        [SUMA IMPORTE TRNSACCION]  DECIMAL(18,2) NULL,
        [SUMA DIFERENCIA]          DECIMAL(18,2) NULL
    );
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_Cache_LiquidacionesRuta_Hot_UsuarioFecha'
      AND object_id = OBJECT_ID('dbo.Cache_LiquidacionesRuta_Hot')
)
BEGIN
    CREATE INDEX IX_Cache_LiquidacionesRuta_Hot_UsuarioFecha
        ON dbo.Cache_LiquidacionesRuta_Hot (USUARIO, FECHA_LIQUIDACION DESC)
        INCLUDE (EMPRESA, LIQUIDACION, [METODO PAGO], [SUMA IMPORTE], [SUMA IMPORTE TRNSACCION], [SUMA DIFERENCIA], FECHA_PROCESO, HORA_TRANSACCION);
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_Cache_LiquidacionesRuta_Hot_Liquidacion'
      AND object_id = OBJECT_ID('dbo.Cache_LiquidacionesRuta_Hot')
)
BEGIN
    CREATE INDEX IX_Cache_LiquidacionesRuta_Hot_Liquidacion
        ON dbo.Cache_LiquidacionesRuta_Hot (LIQUIDACION)
        INCLUDE (USUARIO, EMPRESA, FECHA_LIQUIDACION, [METODO PAGO]);
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_Cache_LiquidacionesRuta_Hot_FechaProceso'
      AND object_id = OBJECT_ID('dbo.Cache_LiquidacionesRuta_Hot')
)
BEGIN
    CREATE INDEX IX_Cache_LiquidacionesRuta_Hot_FechaProceso
        ON dbo.Cache_LiquidacionesRuta_Hot (FECHA_PROCESO DESC);
END
GO
