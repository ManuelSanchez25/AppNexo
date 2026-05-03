namespace Nexo.Api.Dtos.Products
{
    public class CreateProductRequest
    {
        public string Name { get; set; } = "";
        public string Description { get; set; } = "";
        public decimal Price { get; set; }
        public string Image { get; set; } = ""; // opcional (o lo dejas fuera)
        public bool IsAvailable { get; set; } = true;
    }
}
