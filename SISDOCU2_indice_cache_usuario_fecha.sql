USE [SISDOCU2]
GO
/* ============================================================================
   Indice para la consulta del modulo Control Venta Ruta
   Servidor : 172.19.0.57   BD : SISDOCU2
   Tabla    : dbo.Cache_LiquidacionesRuta_Mensual_A  (hoy es un heap, sin indice agrupado)

   El modulo consulta por USUARIO y un rango de FECHA_LIQUIDACION (30 dias).
   Sin este indice recorre la tabla completa (unas 240,000 paginas) en cada busqueda.
   Con el indice agrupado, las filas de un usuario quedan juntas y ordenadas por
   fecha, y la consulta lee solo su rango.

   Requiere la version del modulo que filtra con  USUARIO = @Usuario  (parametro
   varchar). Con la consulta anterior, UPPER(RTRIM(LTRIM(USUARIO))), no se usa.

   ONLINE = ON: no bloquea al job de cache ni a los usuarios mientras se crea.
   Conviene lanzarlo justo despues de una corrida de
   JOB_Actualizar_Cache_LiquidacionesRuta_Mensual.

   ROLLBACK (la tabla vuelve a ser un heap):
     DROP INDEX CX_Cache_LiqRuta_Usuario_Fecha
     ON dbo.Cache_LiquidacionesRuta_Mensual_A WITH (ONLINE = ON);
   ============================================================================ */
CREATE CLUSTERED INDEX CX_Cache_LiqRuta_Usuario_Fecha
ON dbo.Cache_LiquidacionesRuta_Mensual_A (USUARIO, FECHA_LIQUIDACION, IdCache)
WITH (ONLINE = ON);
GO
