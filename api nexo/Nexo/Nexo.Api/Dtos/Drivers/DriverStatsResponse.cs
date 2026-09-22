namespace Nexo.Api.Dtos.Drivers
{
    public class DriverStatsResponse
    {
        public int AvailableOrders { get; set; }
        public int ActiveOrders { get; set; }
        public int AcceptedOrders { get; set; }
        public int DeliveredOrders { get; set; }
        public int DeliveredToday { get; set; }
        public decimal TodayEarnings { get; set; }
        public decimal TotalEarnings { get; set; }
    }
}
