using eShop.Basket.API.Grpc;
using eShop.WebApp.Services.OrderStatus.IntegrationEvents;
using eShop.WebAppComponents.Services;
using Microsoft.AspNetCore.Components.Authorization;
using Microsoft.Extensions.AI;
using System.Security.Claims;

public static class NoAuthExtensions
{
    public static void AddApplicationServicesNoAuth(this IHostApplicationBuilder builder)
    {
        builder.AddRabbitMqEventBus("EventBus")
               .AddEventBusSubscriptions();

        builder.Services.AddHttpForwarderWithServiceDiscovery();

        // Application services
        builder.Services.AddScoped<BasketState>();
        builder.Services.AddScoped<LogOutService>();
        builder.Services.AddSingleton<BasketService>();
        builder.Services.AddSingleton<OrderStatusNotificationService>();
        builder.Services.AddSingleton<IProductImageUrlProvider, ProductImageUrlProvider>();
        builder.AddAIServices();

        // HTTP and GRPC client registrations - no auth
        builder.Services.AddGrpcClient<Basket.BasketClient>(o => o.Address = new("http://basket-api"));

        builder.Services.AddHttpClient<CatalogService>(o => o.BaseAddress = new("http://catalog-api"))
            .AddApiVersion(2.0);

        builder.Services.AddHttpClient<OrderingService>(o => o.BaseAddress = new("http://ordering-api"))
            .AddApiVersion(1.0);
    }

    public static void AddNoAuthServices(this IHostApplicationBuilder builder)
    {
        // Mock authentication - always authenticated user
        builder.Services.AddScoped<AuthenticationStateProvider, MockAuthenticationStateProvider>();
        builder.Services.AddCascadingAuthenticationState();
        builder.Services.AddAuthorization();
    }

    private static void AddAIServices(this IHostApplicationBuilder builder)
    {
        ChatClientBuilder? chatClientBuilder = null;
        if (builder.Configuration["OllamaEnabled"] is string ollamaEnabled && bool.Parse(ollamaEnabled))
        {
            chatClientBuilder = builder.AddOllamaApiClient("chat")
                .AddChatClient();
        }
        else if (!string.IsNullOrWhiteSpace(builder.Configuration.GetConnectionString("chatModel")))
        {
            chatClientBuilder = builder.AddOpenAIClientFromConfiguration("chatModel")
                .AddChatClient();
        }

        chatClientBuilder?.UseFunctionInvocation();
    }
}

public class MockAuthenticationStateProvider : AuthenticationStateProvider
{
    public override Task<AuthenticationState> GetAuthenticationStateAsync()
    {
        var identity = new ClaimsIdentity(new[]
        {
            new Claim(ClaimTypes.NameIdentifier, "test-user"),
            new Claim(ClaimTypes.Name, "Test User"),
            new Claim("sub", "test-user")
        }, "mock");

        return Task.FromResult(new AuthenticationState(new ClaimsPrincipal(identity)));
    }
}