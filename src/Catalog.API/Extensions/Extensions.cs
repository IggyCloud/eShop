using eShop.Catalog.API.Services;
using Microsoft.EntityFrameworkCore;
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
        var primaryConnectionString = configuration.GetConnectionString("catalogdb");
        // var replicaConnectionString = configuration.GetConnectionString("catalogdb_replica");

        // If a replica connection string is provided, configure the read/write splitting interceptor.
        // if (!string.IsNullOrEmpty(replicaConnectionString))
        // {
        //     builder.Services.AddSingleton(_ => new ReadWriteInterceptor(replicaConnectionString));
        // }

        // Enable DbContext pooling for high concurrent load performance
        builder.Services.AddDbContextPool<CatalogContext>((serviceProvider, options) =>
        {
            options.UseNpgsql(primaryConnectionString, npgsqlOptions =>
            {
                npgsqlOptions.UseVector();
                npgsqlOptions.EnableRetryOnFailure(3, TimeSpan.FromSeconds(2), null);
                npgsqlOptions.CommandTimeout(30);
            });
            options.UseQueryTrackingBehavior(QueryTrackingBehavior.NoTracking);

            // Add the read/write splitting interceptor if it's available.
            // var readWriteInterceptor = serviceProvider.GetService<ReadWriteInterceptor>();
            // if (readWriteInterceptor is not null)
            // {
            //     options.AddInterceptors(readWriteInterceptor);
            // }
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
