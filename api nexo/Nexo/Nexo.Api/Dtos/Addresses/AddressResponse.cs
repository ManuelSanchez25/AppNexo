namespace Nexo.Api.Dtos.Addresses
{
    public class AddressResponse
    {
        public int Id { get; set; }
        public string Label { get; set; } = string.Empty;
        public string RecipientName { get; set; } = string.Empty;
        public string Phone { get; set; } = string.Empty;
        public string Street { get; set; } = string.Empty;
        public string ExteriorNumber { get; set; } = string.Empty;
        public string InteriorNumber { get; set; } = string.Empty;
        public string Neighborhood { get; set; } = string.Empty;
        public string City { get; set; } = string.Empty;
        public string State { get; set; } = string.Empty;
        public string PostalCode { get; set; } = string.Empty;
        public string References { get; set; } = string.Empty;
        public decimal? Latitude { get; set; }
        public decimal? Longitude { get; set; }
        public bool IsDefault { get; set; }
        public DateTime CreatedAt { get; set; }
        public string FullAddress { get; set; } = string.Empty;
    }
}
