using Asp.Versioning.Builder;
using eShop.Catalog.API.Infrastructure;
using Microsoft.EntityFrameworkCore;
using System.Reflection;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();
builder.AddApplicationServices();
builder.Services.AddProblemDetails();

var withApiVersioning = builder.Services.AddApiVersioning();

builder.AddDefaultOpenApi(withApiVersioning);

var app = builder.Build();

app.MapDefaultEndpoints();

app.UseStatusCodePages();

app.MapCatalogApi();

await ApplyMigrationsWithRetryAsync(app);

app.UseDefaultOpenApi();
await app.RunAsync();

static async Task ApplyMigrationsWithRetryAsync(WebApplication app)
{
    const int maxRetries = 10;
    using var scope = app.Services.CreateScope();
    var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();
    var db = scope.ServiceProvider.GetRequiredService<CatalogContext>();

    for (var attempt = 1; attempt <= maxRetries; attempt++)
    {
        try
        {
            await db.Database.MigrateAsync();
            logger.LogInformation("Database migrations applied.");
            return;
        }
        catch (Exception ex) when (attempt < maxRetries)
        {
            var delay = TimeSpan.FromSeconds(2 * attempt);
            logger.LogWarning(ex, "Database unavailable, retrying migration ({Attempt}/{Max}) after {Delay}s", attempt, maxRetries, delay.TotalSeconds);
            await Task.Delay(delay);
        }
    }

    logger.LogError("Database migrations failed after {MaxRetries} attempts.", maxRetries);
    throw new InvalidOperationException("Unable to apply database migrations after retries.");
}
