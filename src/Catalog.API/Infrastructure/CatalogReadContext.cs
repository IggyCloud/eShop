using eShop.Catalog.API.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace eShop.Catalog.API.Infrastructure;

public class CatalogReadContext : CatalogContext
{
    public CatalogReadContext(DbContextOptions<CatalogReadContext> options, IConfiguration configuration) 
        : base(options, configuration)
    {
    }
}
