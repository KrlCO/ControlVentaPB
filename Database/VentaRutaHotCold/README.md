Arquitectura Hot / Cold para `Control Venta Ruta`

- `Hot`: `dbo.Cache_LiquidacionesRuta_Hot`
- `Cold`: `dbo.Cache_LiquidacionesRuta_Mensual` (sinonimo ya usado por la app)
- Motor local esperado: `SISDOCU2` en `172.19.0.57`
- Fuente remota: `OFIVENT.dbo.SP_CONTROL_VENTA_RUTA_Q01` via linked server

Objetivo:

- La vista por defecto consulta `Hot` para los ultimos 7 a 10 dias.
- El boton de mes y las busquedas antiguas consultan `Cold`.
- `Cold` mantiene el mes actual y el mes anterior.
- `Hot` se refresca cada 15 minutos.
- `Cold` se refresca cada 1 hora.

Archivos:

- `01_hot_table.sql`: crea la tabla fisica Hot e indices.
- `02_hot_cold_jobs_template.sql`: plantilla base para los jobs de carga Hot y Cold.

Nota:

- Los nombres del linked server, permisos de `RPC OUT` y credenciales deben validarse en el servidor SQL antes de ejecutar los jobs.
