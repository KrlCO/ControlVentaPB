using Microsoft.AspNetCore.Mvc;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System;
using Control_Ventas_PeruBus.Configuration;
using Control_Ventas_PeruBus.Models.DTOs;
using Control_Ventas_PeruBus.Services.Interfaces;
using ClosedXML.Excel;
using Microsoft.Data.SqlClient;

namespace Control_Ventas_PeruBus.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class VentaRutaController : ControllerBase
    {
        private readonly IVentaRutaService _ventaRutaService;
        private readonly IConfiguration _configuration;

        public VentaRutaController(IVentaRutaService ventaRutaService, IConfiguration configuration)
        {
            _ventaRutaService = ventaRutaService;
            _configuration = configuration;
        }

        // GET: api/ventaruta?usuario=u1&empresa=PERUBUS&estado=Activo&inicio=2025-01-01&fin=2025-01-31
        [HttpGet]
        public async Task<ActionResult<IEnumerable<VentaRutaDTO>>> Get([FromQuery] string? usuario, [FromQuery] string? empresa, [FromQuery] string? estado, [FromQuery] DateTime? inicio, [FromQuery] DateTime? fin, [FromQuery] string? liquidacion, [FromQuery] string? metodoPago, [FromQuery] DateTime? fechaLiquidacion)
        {
            var ventas = await _ventaRutaService.ObtenerVentasAsync(usuario, empresa, estado, inicio, fin, liquidacion, metodoPago, fechaLiquidacion);

            if (ventas == null || !ventas.Any())
                return NotFound(new { mensaje = "No se encontraron ventas en el periodo actual." });

            return Ok(ventas);
        }

        // GET: api/ventaruta/export?usuario=...&liquidacion=...&metodoPago=...&fechaLiquidacion=YYYY-MM-DD
        [HttpGet("export")]
        public async Task<IActionResult> Export([FromQuery] string? usuario, [FromQuery] string? empresa, [FromQuery] string? estado, [FromQuery] DateTime? inicio, [FromQuery] DateTime? fin, [FromQuery] string? liquidacion, [FromQuery] string? metodoPago, [FromQuery] DateTime? fechaLiquidacion, [FromQuery] bool diario = false)
        {
            List<VentaRutaDTO> list;
            if (diario)
            {
                var baseList = await _ventaRutaService.ObtenerVentasDiariasAsync(usuario ?? string.Empty);
                IEnumerable<VentaRutaDTO> query = baseList ?? Enumerable.Empty<VentaRutaDTO>();
                if (!string.IsNullOrWhiteSpace(empresa))
                    query = query.Where(x => (x.EMPRESA ?? string.Empty).Trim() == empresa.Trim());
                if (!string.IsNullOrWhiteSpace(liquidacion))
                    query = query.Where(x => (x.LIQUIDACION ?? string.Empty).Trim() == liquidacion.Trim());
                var metodoPagoNormalizado = NormalizarMetodoPago(metodoPago);
                if (string.Equals(metodoPagoNormalizado, "SOLO EFECTIVO", StringComparison.OrdinalIgnoreCase))
                    query = query.Where(x => !EsMetodoNoEfectivo(x.METODO_PAGO));
                else if (string.Equals(metodoPagoNormalizado, "NO EFECTIVO", StringComparison.OrdinalIgnoreCase))
                    query = query.Where(x => EsMetodoNoEfectivo(x.METODO_PAGO));
                else if (!string.Equals(metodoPagoNormalizado, "TODOS", StringComparison.OrdinalIgnoreCase))
                    query = query.Where(x => string.Equals((x.METODO_PAGO ?? string.Empty).Trim(), metodoPagoNormalizado, StringComparison.OrdinalIgnoreCase));
                if (fechaLiquidacion.HasValue)
                {
                    var d = fechaLiquidacion.Value.Date;
                    query = query.Where(x => (x.FECHA_LIQUIDACION?.Date ?? x.FECHA_PROCESO?.Date ?? DateTime.MinValue.Date) == d);
                }
                else
                {
                    query = query.Where(x => RutaOperacionWindow.Contains(x.FECHA_LIQUIDACION ?? x.FECHA_PROCESO ?? x.HORA_TRANSACCION));
                }
                list = query.OrderByDescending(x => x.FECHA_LIQUIDACION ?? DateTime.MinValue).ToList();
            }
            else
            {
                var ventas = await _ventaRutaService.ObtenerVentasAsync(usuario, empresa, estado, inicio, fin, liquidacion, metodoPago, fechaLiquidacion);
                list = ventas?.ToList() ?? new List<VentaRutaDTO>();
            }

            using var wb = new ClosedXML.Excel.XLWorkbook();
            var ws = wb.AddWorksheet("VentasRuta");
            var empresaNombre = (empresa?.Trim()) switch { "39" => "EXPRESO SUR BUS", _ => "PERU BUS" };
            var windowEnd = RutaOperacionWindow.GetWindowEnd();
            var windowStart = RutaOperacionWindow.GetWindowStart(windowEnd);
            var headers = new[] { "DOCUMENTO", "ORIGEN", "DESTINO", "LIQUIDACION", "FECHA LIQUIDACION", "METODO PAGO", "SUMA IMPORTE", "SUMA IMPORTE TRNSACCION", "SUMA DIFERENCIA", "BUS", "ID TRANSACCION", "HORA TRANSACCION" };
            const int titleRow = 1;
            const int headerRow = 7;
            const int dataStartRow = 8;

            ws.Range(titleRow, 1, titleRow, headers.Length).Merge();
            ws.Cell(titleRow, 1).Value = "REPORTE CONTROL VENTA RUTA";
            ws.Cell(titleRow, 1).Style.Font.Bold = true;
            ws.Cell(titleRow, 1).Style.Font.FontSize = 16;
            ws.Cell(titleRow, 1).Style.Font.FontColor = XLColor.White;
            ws.Cell(titleRow, 1).Style.Fill.BackgroundColor = XLColor.FromHtml("#1F4E78");
            ws.Cell(titleRow, 1).Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Center;

            ws.Cell(2, 1).Value = "Usuario";
            ws.Cell(2, 2).Value = usuario ?? string.Empty;
            ws.Cell(3, 1).Value = "Fecha y hora";
            ws.Cell(3, 2).Value = DateTime.Now;
            ws.Cell(4, 1).Value = "Empresa";
            ws.Cell(4, 2).Value = empresaNombre;
            ws.Cell(5, 1).Value = "Fecha liquidación";
            ws.Cell(5, 2).Value = fechaLiquidacion?.ToString("yyyy-MM-dd")
                ?? (diario ? $"{windowStart:yyyy-MM-dd HH:mm} - {windowEnd:yyyy-MM-dd HH:mm}" : "Todas");

            ws.Range(2, 1, 5, 1).Style.Font.Bold = true;
            ws.Range(2, 1, 5, 1).Style.Fill.BackgroundColor = XLColor.FromHtml("#D9EAF7");
            ws.Range(2, 1, 5, 2).Style.Border.OutsideBorder = XLBorderStyleValues.Thin;
            ws.Range(2, 1, 5, 2).Style.Border.InsideBorder = XLBorderStyleValues.Thin;
            ws.Cell(3, 2).Style.DateFormat.Format = "yyyy-MM-dd HH:mm";

            for (int i = 0; i < headers.Length; i++) ws.Cell(headerRow, i + 1).Value = headers[i];
            ws.Row(headerRow).Style.Font.Bold = true;

            int row = dataStartRow;
            foreach (var v in list)
            {
                ws.Cell(row, 1).Value = v.DOCUMENTO;
                ws.Cell(row, 2).Value = v.ORIGEN;
                ws.Cell(row, 3).Value = v.DESTINO;
                ws.Cell(row, 4).Value = v.LIQUIDACION;
                ws.Cell(row, 5).Value = v.FECHA_LIQUIDACION ?? v.FECHA_PROCESO;
                ws.Cell(row, 6).Value = v.METODO_PAGO;
                ws.Cell(row, 7).Value = v.SUMA_IMPORTE;
                ws.Cell(row, 8).Value = v.SUMA_IMPORTE_TRNSACCION;
                ws.Cell(row, 9).Value = v.SUMA_DIFERENCIA;
                ws.Cell(row, 10).Value = v.BUS;
                ws.Cell(row, 11).Value = v.ID_TRANSACCION;
                ws.Cell(row, 12).Value = v.HORA_TRANSACCION;
                row++;
            }

            var totalImporte = list.Sum(x => x.SUMA_IMPORTE);
            var totalTransaccion = list.Sum(x => x.SUMA_IMPORTE_TRNSACCION);
            var totalDiferencia = list.Sum(x => x.SUMA_DIFERENCIA);
            ws.Cell(row, 6).Value = "Totales";
            ws.Cell(row, 7).Value = totalImporte;
            ws.Cell(row, 8).Value = totalTransaccion;
            ws.Cell(row, 9).Value = totalDiferencia;
            ws.Row(row).Style.Font.Bold = true;
            ws.Row(row).Style.Fill.BackgroundColor = XLColor.FromHtml("#FFF2CC");
            ws.Range(row, 6, row, 9).Style.Border.TopBorder = XLBorderStyleValues.Medium;

            var dataLastRow = row - 1;
            if (dataLastRow >= dataStartRow)
            {
                var table = ws.Range(headerRow, 1, dataLastRow, headers.Length).CreateTable("VentasRutaTable");
                table.Theme = XLTableTheme.TableStyleMedium2;
                table.ShowAutoFilter = true;
            }
            else
            {
                ws.Range(headerRow, 1, headerRow, headers.Length).SetAutoFilter();
                ws.Row(headerRow).Style.Fill.BackgroundColor = XLColor.FromHtml("#D9E1F2");
            }

            ws.Columns().AdjustToContents();
            ws.SheetView.FreezeRows(headerRow);
            ws.Column(5).Style.DateFormat.Format = "yyyy-MM-dd HH:mm";
            ws.Column(7).Style.NumberFormat.Format = "#,##0.00";
            ws.Column(8).Style.NumberFormat.Format = "#,##0.00";
            ws.Column(9).Style.NumberFormat.Format = "#,##0.00";
            ws.Column(12).Style.DateFormat.Format = "hh:mm";
            ws.Columns(7, 9).Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Right;

            using var ms = new MemoryStream();
            wb.SaveAs(ms);
            var bytes = ms.ToArray();
            var fileName = $"ventas_ruta_{DateTime.Now:yyyyMMdd_HHmm}.xlsx";
            return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", fileName);
        }

        // GET: api/ventaruta/diagnostics
        [HttpGet("diagnostics")]
        public async Task<IActionResult> Diagnostics()
        {
            var ventas = await _ventaRutaService.ObtenerVentasAsync();
            var count = ventas?.Count() ?? 0;
            var cs = _configuration.GetConnectionString("konect");
            var csb = new SqlConnectionStringBuilder(cs);

            return Ok(new
            {
                server = csb.DataSource,
                database = csb.InitialCatalog,
                rowCount = count
            });
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
