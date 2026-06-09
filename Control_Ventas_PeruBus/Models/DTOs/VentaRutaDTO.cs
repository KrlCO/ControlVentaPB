using System.ComponentModel.DataAnnotations.Schema;

namespace Control_Ventas_PeruBus.Models.DTOs
{
    public class VentaRutaDTO
    {
        [Column("IdCache")] public int IdCache { get; set; }
        [Column("EMPRESA")] public string EMPRESA { get; set; } = string.Empty;
        public string DOCUMENTO { get; set; } = string.Empty;
        public string ORIGEN { get; set; } = string.Empty;
        public string DESTINO { get; set; } = string.Empty;
        public string LIQUIDACION { get; set; } = string.Empty;
        [Column("ID TRANSACCION")] public string ID_TRANSACCION { get; set; } = string.Empty;
        [Column("TAG ID")] public string TAG_ID { get; set; } = string.Empty;
        public string BUS { get; set; } = string.Empty;
        [Column("METODO PAGO")] public string METODO_PAGO { get; set; } = string.Empty;
        public string USUARIO { get; set; } = string.Empty;
        public DateTime? FECHA_LIQUIDACION { get; set; }
        [Column("FECHA_PROCESO")] public DateTime? FECHA_PROCESO { get; set; }
        [Column("HORA_TRANSACCION")] public DateTime? HORA_TRANSACCION { get; set; }
        [Column("SUMA IMPORTE")] public decimal SUMA_IMPORTE { get; set; }
        [Column("SUMA IMPORTE TRNSACCION")] public decimal SUMA_IMPORTE_TRNSACCION { get; set; }
        [Column("SUMA DIFERENCIA")] public decimal SUMA_DIFERENCIA { get; set; }
    }
}
