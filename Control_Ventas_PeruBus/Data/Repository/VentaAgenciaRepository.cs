using Control_Ventas_PeruBus.Configuration;
using Control_Ventas_PeruBus.Data.Interfaces;
using Control_Ventas_PeruBus.Models.DTOs;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using System.Data;
using System.Diagnostics;
using System.Globalization;

namespace Control_Ventas_PeruBus.Data.Repository
{
    public class VentaAgenciaRepository : IVentaAgenciaRepository
    {
        private readonly string? _agenciaConnectionString;
        private readonly string _connectionString;
        private readonly string? _ofiventConnectionString;
        private readonly Microsoft.Extensions.Logging.ILogger<VentaAgenciaRepository> _logger;

        public VentaAgenciaRepository(IConfiguration configuration, Microsoft.Extensions.Logging.ILogger<VentaAgenciaRepository> logger)
        {
            _agenciaConnectionString = configuration.GetConnectionString("agencia");
            _connectionString = configuration.GetConnectionString(DatabaseConfig.DefaultConnectionName)
                ?? throw new InvalidOperationException("Missing connection string 'konect'");
            _ofiventConnectionString = configuration.GetConnectionString("ofivent");
            _logger = logger;
        }

        public async Task<IEnumerable<VentaAgenciaDTO>> GetSalesAgencyAsync(
            DateTime feDocuIni,
            DateTime feDocuFin,
            string? coUsua,
            string? idSeri,
            string coAgen,
            string coEmpr = "01")
        {
            if (string.IsNullOrWhiteSpace(coAgen))
                throw new ArgumentException("La agencia es obligatoria.", nameof(coAgen));

            var parameters = new
            {
                FE_DOCU_INI = feDocuIni.Date,
                FE_DOCU_FIN = feDocuFin.Date,
                CO_USUA = string.IsNullOrWhiteSpace(coUsua) ? null : coUsua.Trim().ToUpperInvariant(),
                ID_SERI = string.IsNullOrWhiteSpace(idSeri) ? null : idSeri.Trim().ToUpperInvariant(),
                CO_AGEN = coAgen.Trim().ToUpperInvariant(),
                CO_EMPR = string.IsNullOrWhiteSpace(coEmpr) ? "01" : coEmpr.Trim()
            };

            var candidates = new List<(string Name, string Conn)>
            {
                ("agencia", _agenciaConnectionString ?? string.Empty),
                ("ofivent", _ofiventConnectionString ?? string.Empty),
                ("konect", _connectionString)
            }
            .Where(x => !string.IsNullOrWhiteSpace(x.Conn))
            .GroupBy(x => x.Conn, StringComparer.OrdinalIgnoreCase)
            .Select(g => g.First())
            .ToList();

            Exception? lastException = null;
            foreach (var candidate in candidates)
            {
                try
                {
                    return await ExecuteAgencyQueryAsync(candidate.Conn, candidate.Name, parameters, feDocuIni, feDocuFin, coUsua, coAgen, coEmpr);
                }
                catch (Exception ex)
                {
                    lastException = ex;
                    _logger.LogError(
                        ex,
                        "[Repo Agencia] Error ejecutando SP_CONTROL_VENTAS_AGENCIA_Q01 en '{ConnectionName}' usuario='{Usuario}' agencia='{Agencia}' empresa='{Empresa}' rango='{Inicio:yyyy-MM-dd}'-'{Fin:yyyy-MM-dd}'",
                        candidate.Name,
                        coUsua ?? "<null>",
                        coAgen,
                        coEmpr,
                        feDocuIni,
                        feDocuFin);
                }
            }

            throw new InvalidOperationException("No fue posible ejecutar SP_CONTROL_VENTAS_AGENCIA_Q01 en las conexiones configuradas.", lastException);
        }

        private async Task<IEnumerable<VentaAgenciaDTO>> ExecuteAgencyQueryAsync(
            string connStr,
            string connectionName,
            object parameters,
            DateTime feDocuIni,
            DateTime feDocuFin,
            string? coUsua,
            string coAgen,
            string coEmpr)
        {
            using var conn = new SqlConnection(connStr);
            var sw = Stopwatch.StartNew();
            var rows = await conn.QueryAsync(
                "SP_CONTROL_VENTAS_AGENCIA_Q01",
                parameters,
                commandType: CommandType.StoredProcedure,
                commandTimeout: 180);
            sw.Stop();

            var list = new List<VentaAgenciaDTO>();
            foreach (var row in rows)
            {
                var dict = (IDictionary<string, object>)row;
                var dto = new VentaAgenciaDTO
                {
                    NU_DOCU = GetString(dict, "NU_DOCU"),
                    CO_ESTA_DOCU = GetString(dict, "CO_ESTA_DOCU"),
                    CO_VEHI = GetString(dict, "CO_VEHI"),
                    CO_RUM = GetString(dict, "CO_RUM"),
                    NU_SECU = GetString(dict, "NU_SECU"),
                    TI_SERV = GetString(dict, "TI_SERV"),
                    NU_LIQI = GetString(dict, "NU_LIQI"),
                    FE_LIQI = GetDateTime(dict, "FE_LIQI"),
                    HoraTransaccion = GetTimeString(dict, "HORA_TRANSACCION", "HoraTransaccion"),
                    MetodoPago = GetString(dict, "METODO_PAGO", "MetodoPago"),
                    NroTransaccion = GetString(dict, "TRANSACCION", "NroTransaccion"),
                    IMPORTE = GetDecimal(dict, "IMPORTE"),
                    IMPORTE_TRANSACCION = GetDecimal(dict, "IMPORTE_TRANSACCION"),
                    DIFERENCIA = GetDecimal(dict, "DIFERENCIA"),
                    ANIO = GetNullableInt(dict, "AÑO", "ANIO"),
                    MES = GetNullableInt(dict, "MES"),
                    FECHA = GetDateTime(dict, "FECHA"),
                    COD_EMPRESA = GetString(dict, "COD_EMPRESA"),
                    EMPRESA = GetString(dict, "EMPRESA"),
                    COD_CLIENTE = GetString(dict, "COD_CLIENTE"),
                    CLIENTE = GetString(dict, "CLIENTE"),
                    COD_AGENCIA = GetString(dict, "COD_AGENCIA"),
                    AGENCIA = GetString(dict, "AGENCIA"),
                    ORIGEN = GetString(dict, "ORIGEN"),
                    DESTINO = GetString(dict, "DESTINO"),
                    FECHA_VIAJE = GetDateTime(dict, "FECHA_VIAJE"),
                    HORA_VIAJE = GetTimeString(dict, "HORA_VIAJE"),
                    ASIENTO = GetString(dict, "ASIENTO"),
                    CAJA = GetString(dict, "CAJA"),
                    COD_USUARIO = GetString(dict, "COD_USUARIO"),
                    USUARIO = GetString(dict, "USUARIO"),
                    HORA_CREACION = GetTimeString(dict, "HORA_CREACION"),
                    ESTADO_LIQUIDACION = GetString(dict, "ESTADO_LIQUIDACION"),
                    COD_USUARIO_LIQUIDACION = GetString(dict, "COD_USUARIO_LIQUIDACION"),
                    USUARIO_LIQUIDACION = GetString(dict, "USUARIO_LIQUIDACION"),
                    CAJA_LIQUIDACION = GetString(dict, "CAJA_LIQUIDACION"),
                    PASE = GetString(dict, "PASE")
                };
                list.Add(dto);
            }

            _logger.LogInformation(
                "[Repo Agencia] SP en '{ConnectionName}' usuario='{Usuario}' agencia='{Agencia}' empresa='{Empresa}' rango='{Inicio:yyyy-MM-dd}'-'{Fin:yyyy-MM-dd}' tiempo={Ms}ms filas={Count}",
                connectionName,
                coUsua ?? "<null>",
                coAgen,
                coEmpr,
                feDocuIni,
                feDocuFin,
                sw.ElapsedMilliseconds,
                list.Count);

            return list;
        }

        private static string GetString(IDictionary<string, object> dict, params string[] keys)
        {
            foreach (var key in keys)
            {
                if (!dict.TryGetValue(key, out var value) || value is null || value is DBNull)
                    continue;

                return value switch
                {
                    TimeSpan ts => ts.ToString(@"hh\:mm\:ss"),
                    DateTime dt => dt.ToString("yyyy-MM-dd HH:mm:ss"),
                    _ => value.ToString() ?? string.Empty
                };
            }

            return string.Empty;
        }

        private static string GetTimeString(IDictionary<string, object> dict, params string[] keys)
        {
            foreach (var key in keys)
            {
                if (!dict.TryGetValue(key, out var value) || value is null || value is DBNull)
                    continue;

                return value switch
                {
                    TimeSpan ts => ts.ToString(@"hh\:mm\:ss"),
                    DateTime dt => dt.ToString("HH:mm:ss"),
                    _ => value.ToString() ?? string.Empty
                };
            }

            return string.Empty;
        }

        private static DateTime? GetDateTime(IDictionary<string, object> dict, params string[] keys)
        {
            foreach (var key in keys)
            {
                if (!dict.TryGetValue(key, out var value) || value is null || value is DBNull)
                    continue;

                switch (value)
                {
                    case DateTime dt:
                        return dt;
                    case DateTimeOffset dto:
                        return dto.DateTime;
                    case string s when !string.IsNullOrWhiteSpace(s):
                        if (DateTime.TryParse(s, CultureInfo.InvariantCulture, DateTimeStyles.AllowWhiteSpaces, out var parsed))
                            return parsed;
                        if (DateTime.TryParse(s, CultureInfo.CurrentCulture, DateTimeStyles.AllowWhiteSpaces, out parsed))
                            return parsed;
                        break;
                }
            }

            return null;
        }

        private static int? GetNullableInt(IDictionary<string, object> dict, params string[] keys)
        {
            foreach (var key in keys)
            {
                if (!dict.TryGetValue(key, out var value) || value is null || value is DBNull)
                    continue;

                switch (value)
                {
                    case int i:
                        return i;
                    case long l when l <= int.MaxValue && l >= int.MinValue:
                        return (int)l;
                    case short s:
                        return s;
                    case decimal d when d <= int.MaxValue && d >= int.MinValue:
                        return (int)d;
                    default:
                        if (int.TryParse(value.ToString(), out var parsed))
                            return parsed;
                        break;
                }
            }

            return null;
        }

        private static decimal GetDecimal(IDictionary<string, object> dict, params string[] keys)
        {
            foreach (var key in keys)
            {
                if (!dict.TryGetValue(key, out var value) || value is null || value is DBNull)
                    continue;

                switch (value)
                {
                    case decimal d:
                        return d;
                    case double db:
                        return (decimal)db;
                    case float f:
                        return (decimal)f;
                    case int i:
                        return i;
                    case long l:
                        return l;
                    default:
                        var raw = value.ToString() ?? "0";
                        if (decimal.TryParse(raw, NumberStyles.Any, CultureInfo.InvariantCulture, out var parsed))
                            return parsed;
                        if (decimal.TryParse(raw, NumberStyles.Any, CultureInfo.CurrentCulture, out parsed))
                            return parsed;
                        break;
                }
            }

            return 0m;
        }
    }
}
