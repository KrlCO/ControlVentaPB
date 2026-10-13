using System;

namespace Control_Ventas_PeruBus.Configuration
{
    public static class RutaOperacionWindow
    {
        public static DateTime GetWindowEnd(DateTime? now = null)
        {
            var baseDate = (now ?? DateTime.Now).Date;
            return baseDate.AddDays(1);
        }

        public static DateTime GetWindowStart(DateTime? now = null)
        {
            var baseDate = (now ?? DateTime.Now).Date;
            return baseDate.AddDays(-1);
        }

        public static bool Contains(DateTime? value, DateTime? now = null)
        {
            if (!value.HasValue)
                return false;

            var end = GetWindowEnd(now);
            var start = GetWindowStart(now);
            return value.Value >= start && value.Value < end;
        }
    }
}
