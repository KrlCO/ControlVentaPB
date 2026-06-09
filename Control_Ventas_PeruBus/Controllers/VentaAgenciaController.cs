using ClosedXML.Excel;
using Control_Ventas_PeruBus.Models.DTOs;
using Control_Ventas_PeruBus.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;

namespace Control_Ventas_PeruBus.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class VentaAgenciaController : ControllerBase
    {
        private readonly IVentaAgenciaService _ventaAgenciaService;

        public VentaAgenciaController(IVentaAgenciaService ventaAgenciaService)
        {
            _ventaAgenciaService = ventaAgenciaService;
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<VentaAgenciaDTO>>> Get(
            [FromQuery] DateTime feDocuIni,
            [FromQuery] DateTime feDocuFin,
            [FromQuery] string? coUsua,
            [FromQuery] string? idSeri,
            [FromQuery] string coAgen,
            [FromQuery] string metodoPago = "TODOS",
            [FromQuery] string coEmpr = "01")
        {
            var ventas = await _ventaAgenciaService.ObtenerVentasAsync(feDocuIni, feDocuFin, coUsua, idSeri, coAgen, metodoPago, coEmpr);

            if (ventas == null || !ventas.Any())
                return NotFound(new { mensaje = "No se encontraron ventas de agencia en el periodo seleccionado." });

            return Ok(ventas);
        }

        [HttpGet("export")]
        public async Task<IActionResult> Export(
            [FromQuery] DateTime feDocuIni,
            [FromQuery] DateTime feDocuFin,
            [FromQuery] string? coUsua,
            [FromQuery] string? idSeri,
            [FromQuery] string coAgen,
            [FromQuery] string metodoPago = "TODOS",
            [FromQuery] string coEmpr = "01")
        {
            var list = (await _ventaAgenciaService.ObtenerVentasAsync(feDocuIni, feDocuFin, coUsua, idSeri, coAgen, metodoPago, coEmpr)).ToList();

            using var wb = new XLWorkbook();
            var ws = wb.AddWorksheet("VentasAgencia");
            var empresaNombre = coEmpr?.Trim() == "39" ? "EXPRESO SUR BUS" : "PERU BUS";

            ws.Cell(1, 1).Value = $"Empresa: {empresaNombre}";
            ws.Cell(2, 1).Value = $"Agencia: {coAgen}";
            ws.Cell(3, 1).Value = $"Usuario: {coUsua ?? "TODOS"}";
            ws.Cell(4, 1).Value = $"Rango: {feDocuIni:yyyy-MM-dd} al {feDocuFin:yyyy-MM-dd}";
            ws.Cell(5, 1).Value = $"Metodo pago: {metodoPago}";
            ws.Cell(6, 1).Value = $"Generado: {DateTime.Now:yyyy-MM-dd HH:mm}";
            for (var i = 1; i <= 6; i++)
                ws.Row(i).Style.Font.Bold = true;

            var headers = new[]
            {
                "NU_DOCU", "ORIGEN", "DESTINO", "NU_LIQI", "FE_LIQI",
                "HORA_TRANSACCION", "HORA_CREACION", "METODOPAGO", "IDTRANSACCION",
                "IMPORTE", "IMPORTE_TRANSACCION", "DIFERENCIA",
                "FECHA_VIAJE", "CAJA", "COD_USUARIO"
            };

            for (int i = 0; i < headers.Length; i++)
                ws.Cell(8, i + 1).Value = headers[i];
            ws.Row(8).Style.Font.Bold = true;

            var row = 9;
            foreach (var v in list)
            {
                ws.Cell(row, 1).Value = v.NU_DOCU;
                ws.Cell(row, 2).Value = v.ORIGEN;
                ws.Cell(row, 3).Value = v.DESTINO;
                ws.Cell(row, 4).Value = v.NU_LIQI;
                ws.Cell(row, 5).Value = v.FE_LIQI;
                ws.Cell(row, 6).Value = v.HoraTransaccion;
                ws.Cell(row, 7).Value = v.HORA_CREACION;
                ws.Cell(row, 8).Value = v.MetodoPago;
                ws.Cell(row, 9).Value = v.NroTransaccion;
                ws.Cell(row, 10).Value = v.IMPORTE;
                ws.Cell(row, 11).Value = v.IMPORTE_TRANSACCION;
                ws.Cell(row, 12).Value = v.DIFERENCIA;
                ws.Cell(row, 13).Value = v.FECHA_VIAJE;
                ws.Cell(row, 14).Value = v.CAJA;
                ws.Cell(row, 15).Value = v.COD_USUARIO;
                row++;
            }

            ws.Cell(row, 8).Value = "Totales";
            ws.Cell(row, 9).Value = list.Sum(x => x.IMPORTE);
            ws.Cell(row, 10).Value = list.Sum(x => x.IMPORTE_TRANSACCION);
            ws.Cell(row, 11).Value = list.Sum(x => x.DIFERENCIA);
            ws.Row(row).Style.Font.Bold = true;

            ws.Column(4).Style.DateFormat.Format = "yyyy-mm-dd";
            ws.Column(9).Style.NumberFormat.Format = "#,##0.00";
            ws.Column(10).Style.NumberFormat.Format = "#,##0.00";
            ws.Column(11).Style.NumberFormat.Format = "#,##0.00";
            ws.Column(13).Style.DateFormat.Format = "yyyy-mm-dd";
            ws.Columns().AdjustToContents();

            using var ms = new MemoryStream();
            wb.SaveAs(ms);
            return File(
                ms.ToArray(),
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                $"ventas_agencia_{DateTime.Now:yyyyMMdd_HHmm}.xlsx");
        }
    }
}
