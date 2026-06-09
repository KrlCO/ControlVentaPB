using Control_Ventas_PeruBus.Models.DTOs;
using System.Threading.Tasks;
using System.Collections.Generic;
using System;

namespace Control_Ventas_PeruBus.Services.Interfaces
{
    public interface IVentaRutaService
    {
        Task<IEnumerable<VentaRutaDTO>> ObtenerVentasAsync();
        Task<IEnumerable<VentaRutaDTO>> ObtenerVentasAsync(DateTime? inicio, DateTime? fin);
        Task<IEnumerable<VentaRutaDTO>> ObtenerVentasAsync(string? usuario, string? empresa, string? estado, DateTime? inicio, DateTime? fin, string? liquidacion = null, string? metodoPago = null, DateTime? fechaLiquidacion = null);
        Task<IEnumerable<VentaRutaDTO>> ObtenerVentasDiariasAsync(string usuario);
    }
}
