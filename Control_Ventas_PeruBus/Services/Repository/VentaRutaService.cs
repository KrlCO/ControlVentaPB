using Control_Ventas_PeruBus.Data.Interfaces;
using Control_Ventas_PeruBus.Models.DTOs;
using Control_Ventas_PeruBus.Services.Interfaces;
using Microsoft.Extensions.Caching.Memory;
using System.Diagnostics;
using System.Threading;

namespace Control_Ventas_PeruBus.Services.Repository
{
    public class VentaRutaService : IVentaRutaService
    {
        private const string AllCacheKey = "ventaruta:all";
        private static readonly SemaphoreSlim _allCacheLock = new(1, 1);
        private readonly IVentaRutaRepository _repository;
        private readonly IMemoryCache _cache;
        private readonly Microsoft.Extensions.Logging.ILogger<VentaRutaService> _logger;

        public VentaRutaService(IVentaRutaRepository ventaRutaRepository, IMemoryCache cache, Microsoft.Extensions.Logging.ILogger<VentaRutaService> logger)
        {
            _repository = ventaRutaRepository;
            _cache = cache;
            _logger = logger;
        }

        public async Task<IEnumerable<VentaRutaDTO>> ObtenerVentasAsync()
        {
            // Cachea el resultado para evitar re-ejecutar el SP en cada navegación
            if (_cache.TryGetValue(AllCacheKey, out var cachedObj) && cachedObj is IEnumerable<VentaRutaDTO> cached && cached.Any())
                return cached;

            await _allCacheLock.WaitAsync();
            try
            {
                if (_cache.TryGetValue(AllCacheKey, out cachedObj) && cachedObj is IEnumerable<VentaRutaDTO> cachedInsideLock && cachedInsideLock.Any())
                    return cachedInsideLock;

                var ventas = await _repository.GetSaleRouteAsync();

                // Mantener en cache por 20 minutos solo si hay datos
                if (ventas != null && ventas.Any())
                {
                    _cache.Set(AllCacheKey, ventas, new MemoryCacheEntryOptions
                    {
                        AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(20)
                    });
                }

                return ventas ?? Enumerable.Empty<VentaRutaDTO>();
            }
            finally
            {
                _allCacheLock.Release();
            }
        }

        public async Task<IEnumerable<VentaRutaDTO>> ObtenerVentasAsync(DateTime? inicio, DateTime? fin)
        {
            var ventas = await _repository.GetSaleRouteAsync(null, null, null, inicio, fin, null, null, null);
            return ventas ?? Enumerable.Empty<VentaRutaDTO>();
        }

        public async Task<IEnumerable<VentaRutaDTO>> ObtenerVentasAsync(string? usuario, string? empresa, string? estado, DateTime? inicio, DateTime? fin, string? liquidacion = null, string? metodoPago = null, DateTime? fechaLiquidacion = null)
        {
            // Intenta obtener del cache si no hay filtros
            var sinFiltros = string.IsNullOrWhiteSpace(usuario) && string.IsNullOrWhiteSpace(empresa) && string.IsNullOrWhiteSpace(estado) && inicio is null && fin is null;
            _logger.LogInformation("[Service] ObtenerVentasAsync usuario='{Usuario}', empresa='{Empresa}', estado='{Estado}', inicio='{Inicio}', fin='{Fin}', sinFiltros={SinFiltros}", usuario ?? "<null>", empresa ?? "<null>", estado ?? "<null>", inicio?.ToString("yyyy-MM-dd") ?? "<null>", fin?.ToString("yyyy-MM-dd") ?? "<null>", sinFiltros);
            if (sinFiltros && _cache.TryGetValue(AllCacheKey, out var cachedObj) && cachedObj is IEnumerable<VentaRutaDTO> cached && cached.Any())
            {
                _logger.LogInformation("[Service] Se devuelve desde cache: {Count} filas", cached.Count());
                return cached;
            }

            IEnumerable<VentaRutaDTO>? ventas;
            if (sinFiltros)
            {
                await _allCacheLock.WaitAsync();
                try
                {
                    if (_cache.TryGetValue(AllCacheKey, out cachedObj) && cachedObj is IEnumerable<VentaRutaDTO> cachedInsideLock && cachedInsideLock.Any())
                    {
                        _logger.LogInformation("[Service] Se devuelve desde cache tras espera: {Count} filas", cachedInsideLock.Count());
                        ventas = cachedInsideLock;
                    }
                    else
                    {
                        var swLock = Stopwatch.StartNew();
                        ventas = await _repository.GetSaleRouteAsync(usuario, null, estado, inicio, fin, null, null, null);
                        swLock.Stop();
                        _logger.LogInformation("[Service] SELECT tiempo={Ms}ms", swLock.ElapsedMilliseconds);

                        if (ventas != null && ventas.Any())
                        {
                            _cache.Set(AllCacheKey, ventas, new MemoryCacheEntryOptions
                            {
                                AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(20)
                            });
                        }
                    }
                }
                finally
                {
                    _allCacheLock.Release();
                }
            }
            else
            {
                var sw = Stopwatch.StartNew();
                ventas = await _repository.GetSaleRouteAsync(usuario, null, estado, inicio, fin, null, null, null);
                sw.Stop();
                _logger.LogInformation("[Service] SELECT tiempo={Ms}ms", sw.ElapsedMilliseconds);
            }

            var query = ventas ?? Enumerable.Empty<VentaRutaDTO>();
            _logger.LogInformation("[Service] Base recibida: {Count} filas", query.Count());
            if (!string.IsNullOrWhiteSpace(empresa))
            {
                var empArg = (empresa.Trim());
                var candidates = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { empArg };
                if (empArg == "01" || empArg == "1") { candidates.Add("01"); candidates.Add("1"); candidates.Add("PERU BUS"); }
                if (empArg == "39") { candidates.Add("39"); candidates.Add("EXPRESO SUR BUS"); }
                query = query.Where(x => candidates.Contains((x.EMPRESA ?? string.Empty).Trim()));
                _logger.LogInformation("[Service] Tras filtro empresa: {Count} filas", query.Count());
            }
            if (!string.IsNullOrWhiteSpace(liquidacion))
            {
                var parts = SplitDigits(liquidacion);
                var corrNz = parts.corr.TrimStart('0');
                query = query.Where(x =>
                {
                    var p = SplitDigits(x.LIQUIDACION ?? string.Empty);
                    var corrDbNz = p.corr.TrimStart('0');
                    return p.serie == parts.serie && (p.corr == parts.corr || corrDbNz == corrNz);
                });
                _logger.LogInformation("[Service] Tras filtro liquidacion: {Count} filas", query.Count());
            }
            var metodoPagoNormalizado = NormalizarMetodoPago(metodoPago);
            if (string.Equals(metodoPagoNormalizado, "TODOS", StringComparison.OrdinalIgnoreCase))
            {
                _logger.LogInformation("[Service] Sin filtro metodoPago: {Count} filas", query.Count());
            }
            else if (string.Equals(metodoPagoNormalizado, "SOLO EFECTIVO", StringComparison.OrdinalIgnoreCase))
            {
                query = query.Where(x => !EsMetodoNoEfectivo(x.METODO_PAGO));
                _logger.LogInformation("[Service] Tras filtro metodoPago agrupado (SOLO EFECTIVO): {Count} filas", query.Count());
            }
            else if (string.Equals(metodoPagoNormalizado, "NO EFECTIVO", StringComparison.OrdinalIgnoreCase))
            {
                query = query.Where(x => EsMetodoNoEfectivo(x.METODO_PAGO));
                _logger.LogInformation("[Service] Tras filtro metodoPago agrupado (NO EFECTIVO): {Count} filas", query.Count());
            }
            else
            {
                query = query.Where(x => string.Equals((x.METODO_PAGO ?? string.Empty).Trim(), metodoPagoNormalizado, StringComparison.OrdinalIgnoreCase));
                _logger.LogInformation("[Service] Tras filtro metodoPago: {Count} filas", query.Count());
            }
            if (fechaLiquidacion.HasValue)
            {
                var start = fechaLiquidacion.Value.Date;
                var end = start.AddDays(1);
                query = query.Where(x =>
                {
                    var d = x.FECHA_LIQUIDACION;
                    if (!d.HasValue) return false;
                    var v = d.Value;
                    return v >= start && v < end;
                });
                _logger.LogInformation("[Service] Tras filtro fecha: {Count} filas", query.Count());
            }

            var list = query
                .OrderByDescending(x => x.FECHA_LIQUIDACION ?? DateTime.MinValue)
                .ToList();
            _logger.LogInformation("[Service] Resultado del repositorio: {Count} filas", list.Count());
            return list;
        }

        public async Task<IEnumerable<VentaRutaDTO>> ObtenerVentasDiariasAsync(string usuario)
        {
            var sw = Stopwatch.StartNew();
            var ventas = await _repository.GetSalesRouteDailyAsync(usuario.Trim());
            sw.Stop();
            _logger.LogInformation("[Service] SP diario tiempo={Ms}ms", sw.ElapsedMilliseconds);

            var list = (ventas ?? Enumerable.Empty<VentaRutaDTO>())
                .OrderByDescending(x => x.FECHA_LIQUIDACION ?? DateTime.MinValue)
                .ToList();
            _logger.LogInformation("[Service] Resultado diario: {Count} filas", list.Count());
            return list;
        }

        private static (string serie, string corr) SplitDigits(string s)
        {
            var d = System.Text.RegularExpressions.Regex.Replace(s ?? string.Empty, "[^0-9]", string.Empty);
            var serie = d.Length >= 4 ? d.Substring(0, 4) : d;
            var corr = d.Length > 4 ? d.Substring(4) : string.Empty;
            return (serie, corr);
        }

        private static string? NormalizarMetodoPago(string? metodoPago)
        {
            var normalized = (metodoPago ?? string.Empty).Trim().ToUpperInvariant();
            if (string.IsNullOrWhiteSpace(normalized) || normalized == "QR")
                return "NO EFECTIVO";
            if (normalized == "EFE" || normalized == "EFECTIVO")
                return "SOLO EFECTIVO";
            if (normalized == "TODO" || normalized == "TODOS")
                return "TODOS";
            return normalized;
        }

        private static bool EsMetodoEfectivoRegistrado(string? metodoPago)
        {
            var normalized = (metodoPago ?? string.Empty).Trim().ToUpperInvariant();
            return normalized == "EFECTIVO" || normalized == "EFE";
        }

        private static bool EsMetodoNoEfectivo(string? metodoPago)
        {
            var normalized = (metodoPago ?? string.Empty).Trim().ToUpperInvariant();
            return !string.IsNullOrWhiteSpace(normalized) && !EsMetodoEfectivoRegistrado(normalized);
        }
    }
}
