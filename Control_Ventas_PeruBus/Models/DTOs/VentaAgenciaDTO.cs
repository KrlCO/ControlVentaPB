using System.ComponentModel.DataAnnotations.Schema;

namespace Control_Ventas_PeruBus.Models.DTOs
{
    public class VentaAgenciaDTO
    {
        [Column("NU_DOCU")] public string NU_DOCU { get; set; } = string.Empty;
        [Column("CO_ESTA_DOCU")] public string CO_ESTA_DOCU { get; set; } = string.Empty;
        [Column("CO_VEHI")] public string CO_VEHI { get; set; } = string.Empty;
        [Column("CO_RUM")] public string CO_RUM { get; set; } = string.Empty;
        [Column("NU_SECU")] public string NU_SECU { get; set; } = string.Empty;
        [Column("TI_SERV")] public string TI_SERV { get; set; } = string.Empty;
        [Column("NU_LIQI")] public string NU_LIQI { get; set; } = string.Empty;
        [Column("FE_LIQI")] public DateTime? FE_LIQI { get; set; }
        [Column("HORA_TRANSACCION")] public string HoraTransaccion { get; set; } = string.Empty;
        [Column("METODO_PAGO")] public string MetodoPago { get; set; } = string.Empty;
        [Column("TRANSACCION")] public string NroTransaccion { get; set; } = string.Empty;
        [Column("IMPORTE")] public decimal IMPORTE { get; set; }
        [Column("IMPORTE_TRANSACCION")] public decimal IMPORTE_TRANSACCION { get; set; }
        [Column("DIFERENCIA")] public decimal DIFERENCIA { get; set; }
        [Column("AÑO")] public int? ANIO { get; set; }
        [Column("MES")] public int? MES { get; set; }
        [Column("FECHA")] public DateTime? FECHA { get; set; }
        [Column("COD_EMPRESA")] public string COD_EMPRESA { get; set; } = string.Empty;
        [Column("EMPRESA")] public string EMPRESA { get; set; } = string.Empty;
        [Column("COD_CLIENTE")] public string COD_CLIENTE { get; set; } = string.Empty;
        [Column("CLIENTE")] public string CLIENTE { get; set; } = string.Empty;
        [Column("COD_AGENCIA")] public string COD_AGENCIA { get; set; } = string.Empty;
        [Column("AGENCIA")] public string AGENCIA { get; set; } = string.Empty;
        [Column("ORIGEN")] public string ORIGEN { get; set; } = string.Empty;
        [Column("DESTINO")] public string DESTINO { get; set; } = string.Empty;
        [Column("FECHA_VIAJE")] public DateTime? FECHA_VIAJE { get; set; }
        [Column("HORA_VIAJE")] public string HORA_VIAJE { get; set; } = string.Empty;
        [Column("ASIENTO")] public string ASIENTO { get; set; } = string.Empty;
        [Column("CAJA")] public string CAJA { get; set; } = string.Empty;
        [Column("COD_USUARIO")] public string COD_USUARIO { get; set; } = string.Empty;
        [Column("USUARIO")] public string USUARIO { get; set; } = string.Empty;
        [Column("HORA_CREACION")] public string HORA_CREACION { get; set; } = string.Empty;
        [Column("ESTADO_LIQUIDACION")] public string ESTADO_LIQUIDACION { get; set; } = string.Empty;
        [Column("COD_USUARIO_LIQUIDACION")] public string COD_USUARIO_LIQUIDACION { get; set; } = string.Empty;
        [Column("USUARIO_LIQUIDACION")] public string USUARIO_LIQUIDACION { get; set; } = string.Empty;
        [Column("CAJA_LIQUIDACION")] public string CAJA_LIQUIDACION { get; set; } = string.Empty;
        [Column("PASE")] public string PASE { get; set; } = string.Empty;
    }
}
