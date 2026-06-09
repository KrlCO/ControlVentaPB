namespace Control_Ventas_PeruBus.Models.Entities
{
    public class VentaRuta
    {
        public class LiquidacionRuta
        {
            public string DOCUMENTO { get; set; } = string.Empty;
            public string ORIGEN { get; set; } = string.Empty;
            public string DESTINO { get; set; } = string.Empty;
            public string LIQUIDACION { get; set; } = string.Empty;
            public string ID_TRANSACCION { get; set; } = string.Empty;
            public string BUS { get; set; } = string.Empty;
            public string METODO_PAGO { get; set; } = string.Empty;
            public string USUARIO { get; set; } = string.Empty;
            public DateTime? FECHA_LIQUIDACION { get; set; }
            public decimal SUMA_IMPORTE { get; set; }
            public decimal SUMA_IMPORTE_TRNSACCION { get; set; }
            public decimal SUMA_DIFERENCIA { get; set; }
        }



    }
}
