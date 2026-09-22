namespace Nexo.Api.Dtos.Push
{
    public class RegisterPushDeviceRequest
    {
        public string Token { get; set; } = string.Empty;
        public string Platform { get; set; } = string.Empty;
    }
}
