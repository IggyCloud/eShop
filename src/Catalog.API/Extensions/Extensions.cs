using eShop.Catalog.API.Services;
using eShop.Catalog.API.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Npgsql;
// using MR.EntityFrameworkCore.Sentries;

public static class Extensions
{
    public static void AddApplicationServices(this IHostApplicationBuilder builder)
    {
        // Avoid loading full database config and migrations if startup
        // is being invoked from build-time OpenAPI generation
        if (builder.Environment.IsBuild())
        {
            builder.Services.AddDbContext<CatalogContext>();
            return;
        }

        var configuration = builder.Configuration;
        var primaryConnectionString = configuration.GetConnectionString("catalogdb") ?? throw new InvalidOperationException("ConnectionString 'catalogdb' not found.");
        var replicaConnectionString = configuration.GetConnectionString("catalogdb_replica") ?? primaryConnectionString;

        // Register NpgsqlDataSources with Vector support
        builder.Services.AddNpgsqlDataSource(primaryConnectionString, npgsqlBuilder => npgsqlBuilder.UseVector());
        builder.Services.AddNpgsqlDataSource(replicaConnectionString, npgsqlBuilder => npgsqlBuilder.UseVector(), serviceKey: "replica");

        // Enable Primary DbContext pooling (Writes)
        builder.Services.AddDbContextPool<CatalogContext>((sp, options) =>
        {
            options.UseNpgsql(sp.GetRequiredService<NpgsqlDataSource>(), npgsqlOptions =>
            {
                npgsqlOptions.EnableRetryOnFailure(3, TimeSpan.FromSeconds(2), null);
                npgsqlOptions.CommandTimeout(30);
            });
            options.ConfigureWarnings(w => w.Ignore(Microsoft.EntityFrameworkCore.Diagnostics.RelationalEventId.PendingModelChangesWarning));
        }, poolSize: 100);

        // Enable Replica DbContext pooling (Reads)
        builder.Services.AddDbContextPool<CatalogReadContext>((sp, options) =>
        {
            options.UseNpgsql(sp.GetRequiredKeyedService<NpgsqlDataSource>("replica"), npgsqlOptions =>
            {
                npgsqlOptions.EnableRetryOnFailure(3, TimeSpan.FromSeconds(2), null);
                npgsqlOptions.CommandTimeout(30);
            });
            options.UseQueryTrackingBehavior(QueryTrackingBehavior.NoTracking);
            options.ConfigureWarnings(w => w.Ignore(Microsoft.EntityFrameworkCore.Diagnostics.RelationalEventId.PendingModelChangesWarning));
        }, poolSize: 300);

        // REVIEW: This is done for development ease but shouldn't be here in production
        builder.Services.AddMigration<CatalogContext, CatalogContextSeed>();

        // Add the integration services that consume the DbContext
        builder.Services.AddTransient<IIntegrationEventLogService, IntegrationEventLogService<CatalogContext>>();

        builder.Services.AddTransient<ICatalogIntegrationEventService, CatalogIntegrationEventService>();

        builder.AddRabbitMqEventBus("eventbus")
               .AddSubscription<OrderStatusChangedToAwaitingValidationIntegrationEvent, OrderStatusChangedToAwaitingValidationIntegrationEventHandler>()
               .AddSubscription<OrderStatusChangedToPaidIntegrationEvent, OrderStatusChangedToPaidIntegrationEventHandler>();

        builder.Services.AddOptions<CatalogOptions>()
            .BindConfiguration(nameof(CatalogOptions));

        if (builder.Configuration["OllamaEnabled"] is string ollamaEnabled && bool.Parse(ollamaEnabled))
        {
            builder.AddOllamaApiClient("embedding")
                .AddEmbeddingGenerator();
        }
        else if (!string.IsNullOrWhiteSpace(builder.Configuration.GetConnectionString("textEmbeddingModel")))
        {
            builder.AddOpenAIClientFromConfiguration("textEmbeddingModel")
                .AddEmbeddingGenerator();
        }

        builder.Services.AddScoped<ICatalogAI, CatalogAI>();
    }
}
