using System;

namespace Control_Ventas_PeruBus.Configuration
{
    public static class RutaOperacionWindow
    {
        public const int DailyWindowHours = 36;

        public static DateTime GetWindowEnd(DateTime? now = null) => now ?? DateTime.Now;

        public static DateTime GetWindowStart(DateTime? now = null) => GetWindowEnd(now).AddHours(-DailyWindowHours);

        public static bool Contains(DateTime? value, DateTime? now = null)
        {
            if (!value.HasValue)
                return false;

            var end = GetWindowEnd(now);
            var start = end.AddHours(-DailyWindowHours);
            return value.Value >= start && value.Value <= end;
        }
    }
}
