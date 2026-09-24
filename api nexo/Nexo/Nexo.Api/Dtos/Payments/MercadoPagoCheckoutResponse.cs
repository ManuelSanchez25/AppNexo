namespace Nexo.Api.Dtos.Payments
{
    public class MercadoPagoCheckoutResponse
    {
        public string CheckoutUrl { get; set; } = string.Empty;
        public string PaymentStatus { get; set; } = "pending";
    }
}
