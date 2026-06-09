using Control_Ventas_PeruBus.Models.DTOs;

namespace Control_Ventas_PeruBus.Services.Interfaces
{
    public interface IVentaAgenciaService
    {
        Task<IEnumerable<VentaAgenciaDTO>> ObtenerVentasAsync(
            DateTime feDocuIni,
            DateTime feDocuFin,
            string? coUsua,
            string? idSeri,
            string coAgen,
            string metodoPago = "TODOS",
            string coEmpr = "01");
    }
}
