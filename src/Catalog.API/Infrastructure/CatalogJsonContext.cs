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
[JsonSerializable(typeof(List<CatalogItem>))]
[JsonSerializable(typeof(List<CatalogBrand>))]
[JsonSerializable(typeof(List<CatalogType>))]
[JsonSerializable(typeof(int[]))]
[JsonSerializable(typeof(byte[]))]
[JsonSerializable(typeof(bool))]
[JsonSerializable(typeof(int))]
[JsonSerializable(typeof(long))]
[JsonSourceGenerationOptions(
    PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase,
    WriteIndented = false,
    DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull)]
public partial class CatalogJsonContext : JsonSerializerContext
{
}
