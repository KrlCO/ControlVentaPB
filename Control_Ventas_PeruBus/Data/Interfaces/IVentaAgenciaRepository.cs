using Control_Ventas_PeruBus.Models.DTOs;

namespace Control_Ventas_PeruBus.Data.Interfaces
{
    public interface IVentaAgenciaRepository
    {
        Task<IEnumerable<VentaAgenciaDTO>> GetSalesAgencyAsync(
            DateTime feDocuIni,
            DateTime feDocuFin,
            string? coUsua,
            string? idSeri,
            string coAgen,
            string coEmpr = "01");
    }
}
