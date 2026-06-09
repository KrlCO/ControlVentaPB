using Control_Ventas_PeruBus.Models.Entities;
using Control_Ventas_PeruBus.Models.DTOs;

namespace Control_Ventas_PeruBus.Data.Interfaces
{
    public interface IVentaRutaRepository
    {
        Task<IEnumerable<VentaRutaDTO>> GetSaleRouteAsync();
        Task<IEnumerable<VentaRutaDTO>> GetSalesRouteAsync(string usuario);
        Task<IEnumerable<VentaRutaDTO>> GetSalesRouteDailyAsync(string usuario);
        Task<IEnumerable<VentaRutaDTO>> GetSaleRouteAsync(string? usuario, string? empresa, string? estado, DateTime? fechainicio, DateTime? fechafin, string? liquidacion, string? metodoPago, DateTime? fechaLiquidacion);
        Task<VentaRutaDTO?> GetSalesforDocumentAsync(string documento);
        Task<bool> SaveSaleAsync(VentaRutaDTO venta);

    }
}
