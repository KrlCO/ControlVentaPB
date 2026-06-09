using Control_Ventas_PeruBus.Data.Interfaces;
using Control_Ventas_PeruBus.Models.DTOs;
using Control_Ventas_PeruBus.Services.Interfaces;
using System.Diagnostics;

namespace Control_Ventas_PeruBus.Services.Repository
{
    public class VentaAgenciaService : IVentaAgenciaService
    {
        private readonly IVentaAgenciaRepository _repository;
        private readonly Microsoft.Extensions.Logging.ILogger<VentaAgenciaService> _logger;

        public VentaAgenciaService(IVentaAgenciaRepository repository, Microsoft.Extensions.Logging.ILogger<VentaAgenciaService> logger)
        {
            _repository = repository;
            _logger = logger;
        }

        public async Task<IEnumerable<VentaAgenciaDTO>> ObtenerVentasAsync(
            DateTime feDocuIni,
            DateTime feDocuFin,
            string? coUsua,
            string? idSeri,
            string coAgen,
            string metodoPago = "TODOS",
            string coEmpr = "01")
        {
            var sw = Stopwatch.StartNew();
            var ventas = await _repository.GetSalesAgencyAsync(feDocuIni, feDocuFin, coUsua, idSeri, coAgen, coEmpr);
            sw.Stop();

            var filtroMetodoPago = (metodoPago ?? "TODOS").Trim().ToUpperInvariant();

            var list = (ventas ?? Enumerable.Empty<VentaAgenciaDTO>())
                .Where(x =>
                {
                    var metodo = (x.MetodoPago ?? string.Empty).Trim().ToUpperInvariant();
                    return filtroMetodoPago switch
                    {
                        "EFECTIVO" => metodo == "EFECTIVO",
                        "NO_EFECTIVO" => metodo != "EFECTIVO",
                        _ => true
                    };
                })
                .OrderByDescending(x => x.FECHA ?? DateTime.MinValue)
                .ThenBy(x => x.NU_DOCU)
                .ToList();

            _logger.LogInformation(
                "[Service Agencia] usuario='{Usuario}' agencia='{Agencia}' empresa='{Empresa}' metodoPago='{MetodoPago}' tiempo={Ms}ms filas={Count}",
                coUsua ?? "<null>",
                coAgen,
                coEmpr,
                filtroMetodoPago,
                sw.ElapsedMilliseconds,
                list.Count);

            return list;
        }
    }
}
