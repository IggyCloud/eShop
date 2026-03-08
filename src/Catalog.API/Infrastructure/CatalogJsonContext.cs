using System.Text.Json.Serialization;
using eShop.Catalog.API.Model;

namespace eShop.Catalog.API.Infrastructure;

[JsonSerializable(typeof(PaginatedItems<CatalogItem>))]
[JsonSerializable(typeof(CatalogItem))]
[JsonSerializable(typeof(CatalogBrand))]
[JsonSerializable(typeof(CatalogType))]
[JsonSerializable(typeof(IEnumerable<CatalogItem>))]
[JsonSerializable(typeof(IEnumerable<CatalogBrand>))]
[JsonSerializable(typeof(IEnumerable<CatalogType>))]
[JsonSourceGenerationOptions(
    PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase,
    WriteIndented = false,
    DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull)]
public partial class CatalogJsonContext : JsonSerializerContext
{
}
