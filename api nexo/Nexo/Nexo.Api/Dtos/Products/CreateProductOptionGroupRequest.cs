namespace Nexo.Api.Dtos.Products
{
    public class CreateProductOptionGroupRequest
    {
        public string Name { get; set; } = string.Empty;
        public bool IsRequired { get; set; }
        public int MinSelections { get; set; }
        public int MaxSelections { get; set; } = 1;
        public int SortOrder { get; set; }
    }
}
