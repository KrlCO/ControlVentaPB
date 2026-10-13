using Control_Ventas_PeruBus.Configuration;
using Control_Ventas_PeruBus.Data.Interfaces;
using Control_Ventas_PeruBus.Models.DTOs;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Threading.Tasks;
using System.Diagnostics;
using System.ComponentModel.DataAnnotations.Schema;
using System.Globalization;
using static Control_Ventas_PeruBus.Models.Entities.VentaRuta;

namespace Control_Ventas_PeruBus.Data.Repository
{
    public class VentaRutaRepository : IVentaRutaRepository
    {
        private readonly string _connectionString;
        private readonly string? _ofiventConnectionString;
        private readonly Microsoft.Extensions.Logging.ILogger<VentaRutaRepository> _logger;

        public VentaRutaRepository(IConfiguration configuration, Microsoft.Extensions.Logging.ILogger<VentaRutaRepository> logger)
        {
            _connectionString = configuration.GetConnectionString(DatabaseConfig.DefaultConnectionName)
                ?? throw new InvalidOperationException("conexion perdida con 'konect'");
            _ofiventConnectionString = configuration.GetConnectionString("ofivent");
            _logger = logger;
        }

        public async Task<IEnumerable<VentaRutaDTO>> GetSalesRouteAsync(string usuario)
        {
            SqlMapper.SetTypeMap(typeof(VentaRutaDTO),
                new CustomPropertyTypeMap(typeof(VentaRutaDTO), (type, columnName) =>
                    type.GetProperties().FirstOrDefault(prop =>
                        prop.GetCustomAttributes(false)
                            .OfType<ColumnAttribute>()
                            .Any(attr => attr.Name == columnName) || prop.Name == columnName)
                    ?? type.GetProperty(columnName)
                    ?? throw new InvalidOperationException($"No se encontró mapeo para la columna '{columnName}' en {type.Name}")));

            using var conn = new SqlConnection(_connectionString);
            var sw = Stopwatch.StartNew();
            var result = await conn.QueryAsync<VentaRutaDTO>(
                "sp_usuario_liqi",
                new { iscouser = usuario },
                commandType: CommandType.StoredProcedure,
                commandTimeout: 180);
            sw.Stop();
            var list = result ?? Enumerable.Empty<VentaRutaDTO>();
            _logger.LogInformation("[Repo] SP usuario='{Usuario}' tiempo={Ms}ms filas={Count}", usuario, sw.ElapsedMilliseconds, list.Count());
            return list;
        }
        

        public Task<VentaRutaDTO?> GetSalesforDocumentAsync(string documento)
        {
            throw new NotImplementedException();
        }

        public Task<bool> SaveSaleAsync(VentaRutaDTO venta)
        {
            throw new NotImplementedException();
        }

        public async Task<IEnumerable<VentaRutaDTO>> GetSaleRouteAsync()
        {
            var sql = @"
                SELECT
                    DOCUMENTO,
                    ORIGEN,
                    DESTINO,
                    LIQUIDACION,
                    [ID TRANSACCION] AS ID_TRANSACCION,
                    BUS,
                    [METODO PAGO] AS METODO_PAGO,
                    USUARIO,
                    FECHA_LIQUIDACION,
                    [SUMA IMPORTE] AS SUMA_IMPORTE,
                    [SUMA IMPORTE TRNSACCION] AS SUMA_IMPORTE_TRNSACCION,
                    [SUMA DIFERENCIA] AS SUMA_DIFERENCIA
                FROM dbo.Cache_LiquidacionesRuta_Mensual
                ORDER BY FECHA_LIQUIDACION DESC;";

            using var conn = new SqlConnection(_connectionString);
            return await conn.QueryAsync<VentaRutaDTO>(sql);
        }

        public async Task<IEnumerable<VentaRutaDTO>> GetSalesRouteDailyAsync(string usuario)
        {
            var connStr = _ofiventConnectionString ?? _connectionString;
            using var conn = new SqlConnection(connStr);
            var sw = Stopwatch.StartNew();
            var rows = await conn.QueryAsync(
                "SP_CONTROL_VENTA_RUTA_Q01_DIA",
                new { Usuario = usuario?.Trim() },
                commandType: CommandType.StoredProcedure,
                commandTimeout: 180);
            sw.Stop();
            var list = new List<VentaRutaDTO>();
            foreach (var row in rows)
            {
                var dict = (IDictionary<string, object>)row;
                DateTime? fecha = null;
                if (dict.TryGetValue("FECHA_LIQUIDACION", out var f))
                {
                    switch (f)
                    {
                        case DateTime dt:
                            fecha = dt;
                            break;
                        case string s when !string.IsNullOrWhiteSpace(s):
                            if (DateTime.TryParseExact(s, "yyyy-MM-dd HHmmss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var d1))
                                fecha = d1;
                            else if (DateTime.TryParseExact(s, "yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var d2))
                                fecha = d2;
                            else if (DateTime.TryParseExact(s, "yyyy-MM-dd HH:mm:ss.fff", CultureInfo.InvariantCulture, DateTimeStyles.None, out var d2f))
                                fecha = d2f;
                            else if (DateTime.TryParseExact(s, "dd/MM/yyyy HH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var d3))
                                fecha = d3;
                            else if (DateTime.TryParseExact(s, "dd/MM/yyyy HH:mm", CultureInfo.InvariantCulture, DateTimeStyles.None, out var d4))
                                fecha = d4;
                            else if (DateTime.TryParseExact(s, "yyyyMMdd HH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var d5))
                                fecha = d5;
                            else if (DateTime.TryParseExact(s, "yyyyMMdd HHmmss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var d6))
                                fecha = d6;
                            else if (DateTime.TryParseExact(s, "dd-MM-yyyy HH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var d7))
                                fecha = d7;
                            else if (DateTime.TryParseExact(s, "yyyy-MM-ddTHH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var d8))
                                fecha = d8;
                            else if (DateTime.TryParseExact(s, "yyyy-MM-ddTHH:mm:ss.fff", CultureInfo.InvariantCulture, DateTimeStyles.None, out var d8f))
                                fecha = d8f;
                            else if (DateTime.TryParseExact(s, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var d9))
                                fecha = d9;
                            else if (DateTime.TryParseExact(s, "dd/MM/yyyy", CultureInfo.InvariantCulture, DateTimeStyles.None, out var d10))
                                fecha = d10;
                            else if (DateTime.TryParseExact(s, "yyyyMMdd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var d11))
                                fecha = d11;
                            else if (DateTime.TryParse(s, CultureInfo.InvariantCulture, DateTimeStyles.AllowWhiteSpaces, out var d12))
                                fecha = d12;
                            break;
                    }
                }

                DateTime? horaTrans = null;
                if (dict.TryGetValue("HORA_TRANSACCION", out var htv) || dict.TryGetValue("HORA TRANSACCION", out htv))
                {
                    switch (htv)
                    {
                        case DateTime dth:
                            horaTrans = dth;
                            break;
                        case string sh when !string.IsNullOrWhiteSpace(sh):
                            if (DateTime.TryParseExact(sh, "yyyy-MM-dd HHmmss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var h1))
                                horaTrans = h1;
                            else if (DateTime.TryParseExact(sh, "yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var h2))
                                horaTrans = h2;
                            else if (DateTime.TryParseExact(sh, "yyyy-MM-dd HH:mm:ss.fff", CultureInfo.InvariantCulture, DateTimeStyles.None, out var h2f))
                                horaTrans = h2f;
                            else if (DateTime.TryParseExact(sh, "dd/MM/yyyy HH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var h3))
                                horaTrans = h3;
                            else if (DateTime.TryParseExact(sh, "dd/MM/yyyy HH:mm", CultureInfo.InvariantCulture, DateTimeStyles.None, out var h4))
                                horaTrans = h4;
                            else if (DateTime.TryParseExact(sh, "yyyyMMdd HH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var h5))
                                horaTrans = h5;
                            else if (DateTime.TryParseExact(sh, "yyyyMMdd HHmmss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var h6))
                                horaTrans = h6;
                            else if (DateTime.TryParseExact(sh, "dd-MM-yyyy HH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var h7))
                                horaTrans = h7;
                            else if (DateTime.TryParseExact(sh, "yyyy-MM-ddTHH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var h8))
                                horaTrans = h8;
                            else if (DateTime.TryParseExact(sh, "yyyy-MM-ddTHH:mm:ss.fff", CultureInfo.InvariantCulture, DateTimeStyles.None, out var h8f))
                                horaTrans = h8f;
                            else if (DateTime.TryParse(sh, CultureInfo.InvariantCulture, DateTimeStyles.AllowWhiteSpaces, out var h9))
                                horaTrans = h9;
                            break;
                    }
                }

                DateTime? horaEmision = null;
                if (dict.TryGetValue("HORA_EMISION", out var hev) || dict.TryGetValue("HORA EMISION", out hev))
                {
                    switch (hev)
                    {
                        case DateTime dte:
                            horaEmision = dte;
                            break;
                        case string she when !string.IsNullOrWhiteSpace(she):
                            if (DateTime.TryParseExact(she, "yyyy-MM-dd HHmmss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var e1))
                                horaEmision = e1;
                            else if (DateTime.TryParseExact(she, "yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var e2))
                                horaEmision = e2;
                            else if (DateTime.TryParseExact(she, "yyyy-MM-dd HH:mm:ss.fff", CultureInfo.InvariantCulture, DateTimeStyles.None, out var e2f))
                                horaEmision = e2f;
                            else if (DateTime.TryParseExact(she, "dd/MM/yyyy HH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var e3))
                                horaEmision = e3;
                            else if (DateTime.TryParseExact(she, "dd/MM/yyyy HH:mm", CultureInfo.InvariantCulture, DateTimeStyles.None, out var e4))
                                horaEmision = e4;
                            else if (DateTime.TryParseExact(she, "yyyyMMdd HH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var e5))
                                horaEmision = e5;
                            else if (DateTime.TryParseExact(she, "yyyyMMdd HHmmss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var e6))
                                horaEmision = e6;
                            else if (DateTime.TryParseExact(she, "dd-MM-yyyy HH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var e7))
                                horaEmision = e7;
                            else if (DateTime.TryParseExact(she, "yyyy-MM-ddTHH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var e8))
                                horaEmision = e8;
                            else if (DateTime.TryParseExact(she, "yyyy-MM-ddTHH:mm:ss.fff", CultureInfo.InvariantCulture, DateTimeStyles.None, out var e8f))
                                horaEmision = e8f;
                            else if (DateTime.TryParse(she, CultureInfo.InvariantCulture, DateTimeStyles.AllowWhiteSpaces, out var e9))
                                horaEmision = e9;
                            break;
                    }
                }

                decimal ToDec(string key)
                {
                    var s = dict.TryGetValue(key, out var v) ? v?.ToString() ?? "0" : "0";
                    if (decimal.TryParse(s, NumberStyles.Number | NumberStyles.AllowDecimalPoint | NumberStyles.AllowThousands, CultureInfo.InvariantCulture, out var dd)) return dd;
                    if (decimal.TryParse(s, out dd)) return dd;
                    return 0m;
                }

                var dto = new VentaRutaDTO
                {
                    EMPRESA = dict.TryGetValue("EMPRESA", out var empresaVal) ? empresaVal?.ToString() ?? string.Empty : string.Empty,
                    DOCUMENTO = dict.TryGetValue("DOCUMENTO", out var doc) ? doc?.ToString() ?? string.Empty : string.Empty,
                    ORIGEN = dict.TryGetValue("ORIGEN", out var orig) ? orig?.ToString() ?? string.Empty : string.Empty,
                    DESTINO = dict.TryGetValue("DESTINO", out var dest) ? dest?.ToString() ?? string.Empty : string.Empty,
                    LIQUIDACION = dict.TryGetValue("LIQUIDACION", out var liq) ? liq?.ToString() ?? string.Empty : string.Empty,
                    ID_TRANSACCION = dict.TryGetValue("ID TRANSACCION", out var idt) ? idt?.ToString() ?? string.Empty : string.Empty,
                    TAG_ID = dict.TryGetValue("TAG ID", out var tag) ? tag?.ToString() ?? string.Empty : (dict.TryGetValue("TAG_ID", out var tag2) ? tag2?.ToString() ?? string.Empty : string.Empty),
                    BUS = dict.TryGetValue("BUS", out var bus) ? bus?.ToString() ?? string.Empty : string.Empty,
                    METODO_PAGO = dict.TryGetValue("METODO PAGO", out var mp) ? mp?.ToString() ?? string.Empty : string.Empty,
                    USUARIO = dict.TryGetValue("USUARIO", out var usr) ? usr?.ToString() ?? string.Empty : string.Empty,
                    FECHA_LIQUIDACION = fecha,
                    FECHA_PROCESO = dict.TryGetValue("FECHA_PROCESO", out var fp) && fp is DateTime fpd ? fpd : (DateTime?)null,
                    HORA_EMISION = horaEmision,
                    HORA_TRANSACCION = horaTrans,
                    SUMA_IMPORTE = ToDec("SUMA IMPORTE"),
                    SUMA_IMPORTE_TRNSACCION = ToDec("SUMA IMPORTE TRNSACCION"),
                    SUMA_DIFERENCIA = ToDec("SUMA DIFERENCIA")
                };
                list.Add(dto);
            }
            list = list
                .Where(x => RutaOperacionWindow.Contains(x.FECHA_LIQUIDACION ?? x.HORA_EMISION ?? x.HORA_TRANSACCION))
                .ToList();
            _logger.LogInformation("[Repo] SP diario usuario='{Usuario}' tiempo={Ms}ms filas={Count} (conn={Conn})", usuario, sw.ElapsedMilliseconds, list.Count, connStr);
            return list;
        }

        public async Task<IEnumerable<VentaRutaDTO>> GetSaleRouteAsync(string? usuario, string? empresa, string? estado, DateTime? fechainicio, DateTime? fechafin, string? liquidacion, string? metodoPago, DateTime? fechaLiquidacion)
        {
            var sql = @"
                SELECT
                    IdCache,
                    EMPRESA,
                    DOCUMENTO,
                    ORIGEN,
                    DESTINO,
                    LIQUIDACION,
                    [ID TRANSACCION] AS ID_TRANSACCION,
                    BUS,
                    [METODO PAGO] AS METODO_PAGO,
                    USUARIO,
                    FECHA_LIQUIDACION,
                    FECHA_PROCESO,
                    HORA_EMISION,
                    HORA_TRANSACCION,
                    [SUMA IMPORTE] AS SUMA_IMPORTE,
                    [SUMA IMPORTE TRNSACCION] AS SUMA_IMPORTE_TRNSACCION,
                    [SUMA DIFERENCIA] AS SUMA_DIFERENCIA
                FROM dbo.Cache_LiquidacionesRuta_Mensual";

            var conditions = new List<string>();
            var param = new DynamicParameters();

            if (!string.IsNullOrWhiteSpace(usuario))
            {
                // Comparacion directa y parametro varchar para que SQL Server pueda usar
                // un indice por USUARIO. La columna es varchar y la intercalacion no
                // distingue mayusculas; un parametro nvarchar obligaria a recorrer la tabla.
                conditions.Add("USUARIO = @Usuario");
                param.Add("Usuario", usuario.Trim(), DbType.AnsiString, size: 50);
            }


            if (!string.IsNullOrWhiteSpace(liquidacion))
            {
                conditions.Add("RTRIM(LTRIM(LIQUIDACION)) = @Liquidacion");
                param.Add("Liquidacion", liquidacion.Trim());
            }

            if (!string.IsNullOrWhiteSpace(metodoPago))
            {
                conditions.Add("UPPER(RTRIM(LTRIM([METODO PAGO]))) = UPPER(@MetodoPago)");
                param.Add("MetodoPago", metodoPago.Trim());
            }

            if (fechaLiquidacion.HasValue)
            {
                conditions.Add("CAST(FECHA_LIQUIDACION AS DATE) = @FechaLiquidacion");
                param.Add("FechaLiquidacion", fechaLiquidacion.Value.Date);
            }

            if (fechainicio.HasValue)
            {
                conditions.Add("FECHA_LIQUIDACION >= @FechaInicio");
                param.Add("FechaInicio", fechainicio.Value);
            }

            if (fechafin.HasValue)
            {
                conditions.Add("FECHA_LIQUIDACION <= @FechaFin");
                param.Add("FechaFin", fechafin.Value);
            }

            if (conditions.Count > 0)
                sql += " WHERE " + string.Join(" AND ", conditions);

            sql += " ORDER BY FECHA_LIQUIDACION DESC, HORA_EMISION DESC, DOCUMENTO DESC;";

            using var conn = new SqlConnection(_connectionString);
            var rows = await conn.QueryAsync(sql, param, commandType: CommandType.Text, commandTimeout: 180);
            var list = new List<VentaRutaDTO>();
            foreach (var row in rows)
            {
                var dict = (IDictionary<string, object>)row;
                DateTime? fecha = null;
                if (dict.TryGetValue("FECHA_LIQUIDACION", out var f))
                {
                    switch (f)
                    {
                        case DateTime dt:
                            fecha = dt;
                            break;
                        case string s when !string.IsNullOrWhiteSpace(s):
                            if (DateTime.TryParseExact(s, "yyyy-MM-dd HHmmss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var dtx))
                                fecha = dtx;
                            else if (DateTime.TryParseExact(s, "yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var dtx2))
                                fecha = dtx2;
                            else if (DateTime.TryParse(s, CultureInfo.InvariantCulture, DateTimeStyles.AllowWhiteSpaces, out var dty))
                                fecha = dty;
                            break;
                    }
                }
                DateTime? fechaProceso = null;
                if (dict.TryGetValue("FECHA_PROCESO", out var fpv))
                {
                    switch (fpv)
                    {
                        case DateTime dtp:
                            fechaProceso = dtp;
                            break;
                        case string sp when !string.IsNullOrWhiteSpace(sp):
                            if (DateTime.TryParseExact(sp, "yyyy-MM-dd HHmmss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var p1))
                                fechaProceso = p1;
                            else if (DateTime.TryParseExact(sp, "yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var p2))
                                fechaProceso = p2;
                            else if (DateTime.TryParseExact(sp, "yyyy-MM-dd HH:mm:ss.fff", CultureInfo.InvariantCulture, DateTimeStyles.None, out var p2f))
                                fechaProceso = p2f;
                            else if (DateTime.TryParseExact(sp, "dd/MM/yyyy HH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var p3))
                                fechaProceso = p3;
                            else if (DateTime.TryParseExact(sp, "dd/MM/yyyy HH:mm", CultureInfo.InvariantCulture, DateTimeStyles.None, out var p4))
                                fechaProceso = p4;
                            else if (DateTime.TryParseExact(sp, "yyyyMMdd HH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var p5))
                                fechaProceso = p5;
                            else if (DateTime.TryParseExact(sp, "yyyyMMdd HHmmss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var p6))
                                fechaProceso = p6;
                            else if (DateTime.TryParseExact(sp, "dd-MM-yyyy HH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var p7))
                                fechaProceso = p7;
                            else if (DateTime.TryParseExact(sp, "yyyy-MM-ddTHH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var p8))
                                fechaProceso = p8;
                            else if (DateTime.TryParseExact(sp, "yyyy-MM-ddTHH:mm:ss.fff", CultureInfo.InvariantCulture, DateTimeStyles.None, out var p8f))
                                fechaProceso = p8f;
                            else if (DateTime.TryParseExact(sp, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var p9))
                                fechaProceso = p9;
                            else if (DateTime.TryParseExact(sp, "dd/MM/yyyy", CultureInfo.InvariantCulture, DateTimeStyles.None, out var p10))
                                fechaProceso = p10;
                            else if (DateTime.TryParseExact(sp, "yyyyMMdd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var p11))
                                fechaProceso = p11;
                            else if (DateTime.TryParse(sp, CultureInfo.InvariantCulture, DateTimeStyles.AllowWhiteSpaces, out var p12))
                                fechaProceso = p12;
                            break;
                    }
                }
                DateTime? horaTrans = null;
                if (dict.TryGetValue("HORA_TRANSACCION", out var htv))
                {
                    switch (htv)
                    {
                        case DateTime dth:
                            horaTrans = dth;
                            break;
                        case string sh when !string.IsNullOrWhiteSpace(sh):
                            if (DateTime.TryParseExact(sh, "yyyy-MM-dd HHmmss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var h1))
                                horaTrans = h1;
                            else if (DateTime.TryParseExact(sh, "yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var h2))
                                horaTrans = h2;
                            else if (DateTime.TryParseExact(sh, "yyyy-MM-dd HH:mm:ss.fff", CultureInfo.InvariantCulture, DateTimeStyles.None, out var h2f))
                                horaTrans = h2f;
                            else if (DateTime.TryParseExact(sh, "dd/MM/yyyy HH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var h3))
                                horaTrans = h3;
                            else if (DateTime.TryParseExact(sh, "dd/MM/yyyy HH:mm", CultureInfo.InvariantCulture, DateTimeStyles.None, out var h4))
                                horaTrans = h4;
                            else if (DateTime.TryParseExact(sh, "yyyyMMdd HH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var h5))
                                horaTrans = h5;
                            else if (DateTime.TryParseExact(sh, "yyyyMMdd HHmmss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var h6))
                                horaTrans = h6;
                            else if (DateTime.TryParseExact(sh, "dd-MM-yyyy HH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var h7))
                                horaTrans = h7;
                            else if (DateTime.TryParseExact(sh, "yyyy-MM-ddTHH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var h8))
                                horaTrans = h8;
                            else if (DateTime.TryParseExact(sh, "yyyy-MM-ddTHH:mm:ss.fff", CultureInfo.InvariantCulture, DateTimeStyles.None, out var h8f))
                                horaTrans = h8f;
                            else if (DateTime.TryParse(sh, CultureInfo.InvariantCulture, DateTimeStyles.AllowWhiteSpaces, out var h9))
                                horaTrans = h9;
                            break;
                    }
                }
                DateTime? horaEmision = null;
                if (dict.TryGetValue("HORA_EMISION", out var hev))
                {
                    switch (hev)
                    {
                        case DateTime dte:
                            horaEmision = dte;
                            break;
                        case string she when !string.IsNullOrWhiteSpace(she):
                            if (DateTime.TryParseExact(she, "yyyy-MM-dd HHmmss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var e1))
                                horaEmision = e1;
                            else if (DateTime.TryParseExact(she, "yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var e2))
                                horaEmision = e2;
                            else if (DateTime.TryParseExact(she, "yyyy-MM-dd HH:mm:ss.fff", CultureInfo.InvariantCulture, DateTimeStyles.None, out var e2f))
                                horaEmision = e2f;
                            else if (DateTime.TryParseExact(she, "dd/MM/yyyy HH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var e3))
                                horaEmision = e3;
                            else if (DateTime.TryParseExact(she, "dd/MM/yyyy HH:mm", CultureInfo.InvariantCulture, DateTimeStyles.None, out var e4))
                                horaEmision = e4;
                            else if (DateTime.TryParseExact(she, "yyyyMMdd HH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var e5))
                                horaEmision = e5;
                            else if (DateTime.TryParseExact(she, "yyyyMMdd HHmmss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var e6))
                                horaEmision = e6;
                            else if (DateTime.TryParseExact(she, "dd-MM-yyyy HH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var e7))
                                horaEmision = e7;
                            else if (DateTime.TryParseExact(she, "yyyy-MM-ddTHH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var e8))
                                horaEmision = e8;
                            else if (DateTime.TryParseExact(she, "yyyy-MM-ddTHH:mm:ss.fff", CultureInfo.InvariantCulture, DateTimeStyles.None, out var e8f))
                                horaEmision = e8f;
                            else if (DateTime.TryParse(she, CultureInfo.InvariantCulture, DateTimeStyles.AllowWhiteSpaces, out var e9))
                                horaEmision = e9;
                            break;
                    }
                }

                decimal ToDec(string key)
                {
                    var s = dict.TryGetValue(key, out var v) ? v?.ToString() ?? "0" : "0";
                    if (decimal.TryParse(s, NumberStyles.Number | NumberStyles.AllowDecimalPoint | NumberStyles.AllowThousands, CultureInfo.InvariantCulture, out var dd)) return dd;
                    if (decimal.TryParse(s, out dd)) return dd;
                    return 0m;
                }

                var dto = new VentaRutaDTO
                {
                    IdCache = dict.TryGetValue("IdCache", out var idc) && int.TryParse(idc?.ToString(), out var idcInt) ? idcInt : 0,
                    EMPRESA = dict.TryGetValue("EMPRESA", out var empresaOut) ? empresaOut?.ToString() ?? string.Empty : string.Empty,
                    DOCUMENTO = dict.TryGetValue("DOCUMENTO", out var doc) ? doc?.ToString() ?? string.Empty : string.Empty,
                    ORIGEN = dict.TryGetValue("ORIGEN", out var orig) ? orig?.ToString() ?? string.Empty : string.Empty,
                    DESTINO = dict.TryGetValue("DESTINO", out var dest) ? dest?.ToString() ?? string.Empty : string.Empty,
                    LIQUIDACION = dict.TryGetValue("LIQUIDACION", out var liq) ? liq?.ToString() ?? string.Empty : string.Empty,
                    ID_TRANSACCION = dict.TryGetValue("ID_TRANSACCION", out var idt) ? idt?.ToString() ?? string.Empty : (dict.TryGetValue("ID TRANSACCION", out var idt2) ? idt2?.ToString() ?? string.Empty : string.Empty),
                    TAG_ID = dict.TryGetValue("TAG_ID", out var tagid) ? tagid?.ToString() ?? string.Empty : (dict.TryGetValue("TAG ID", out var tagid2) ? tagid2?.ToString() ?? string.Empty : string.Empty),
                    BUS = dict.TryGetValue("BUS", out var bus) ? bus?.ToString() ?? string.Empty : string.Empty,
                    METODO_PAGO = dict.TryGetValue("METODO_PAGO", out var mpVal) ? mpVal?.ToString() ?? string.Empty : (dict.TryGetValue("METODO PAGO", out var mp2Val) ? mp2Val?.ToString() ?? string.Empty : string.Empty),
                    USUARIO = dict.TryGetValue("USUARIO", out var usr) ? usr?.ToString() ?? string.Empty : string.Empty,
                    FECHA_LIQUIDACION = fecha,
                    FECHA_PROCESO = fechaProceso,
                    HORA_EMISION = horaEmision,
                    HORA_TRANSACCION = horaTrans,
                    SUMA_IMPORTE = ToDec("SUMA_IMPORTE"),
                    SUMA_IMPORTE_TRNSACCION = ToDec("SUMA_IMPORTE_TRNSACCION"),
                    SUMA_DIFERENCIA = ToDec("SUMA_DIFERENCIA")
                };
                list.Add(dto);
            }
            return list;
        }

    }
}
