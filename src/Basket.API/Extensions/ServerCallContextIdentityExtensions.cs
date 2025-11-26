#nullable enable

namespace eShop.Basket.API.Extensions;

internal static class ServerCallContextIdentityExtensions
{
    public static string? GetUserIdentity(this ServerCallContext context) 
    {
        var httpContext = context.GetHttpContext();
        var services = httpContext.RequestServices;
        var disableAuth = false;

        if (services == null)
        {
            return httpContext.User.FindFirst("sub")?.Value;
        }

        var config = services.GetService<IConfiguration>();
        disableAuth = config?.GetValue<bool>("DisableAuth") ?? false;
        
        if (disableAuth)
        {
            // Return a default user ID when authentication is disabled
            return "demo-user-123";
        }
        
        return httpContext.User.FindFirst("sub")?.Value;
    }
    
    public static string? GetUserName(this ServerCallContext context) 
    {
        var httpContext = context.GetHttpContext();
        var services = httpContext.RequestServices;
        var disableAuth = false;

        if (services == null)
        {
            return httpContext.User.FindFirst(x => x.Type == ClaimTypes.Name)?.Value;
        }

        var config = services.GetService<IConfiguration>();
        disableAuth = config?.GetValue<bool>("DisableAuth") ?? false;
        
        if (disableAuth)
        {
            // Return a default user name when authentication is disabled
            return "Demo User";
        }
        
        return httpContext.User.FindFirst(x => x.Type == ClaimTypes.Name)?.Value;
    }
}
