using System.Collections.Generic;
using System.Globalization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using OpenTelemetry.Exporter;
using OpenTelemetry.Logs;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using Pyroscope.OpenTelemetry;

namespace eShop.ServiceDefaults;

public static partial class Extensions
{
    public static IHostApplicationBuilder AddServiceDefaults(this IHostApplicationBuilder builder)
    {
        builder.AddBasicServiceDefaults();

        builder.Services.AddServiceDiscovery();

        builder.Services.ConfigureHttpClientDefaults(http =>
        {
            // Turn on resilience by default
            http.AddStandardResilienceHandler();

            // Turn on service discovery by default
            http.AddServiceDiscovery();
        });

        return builder;
    }

    /// <summary>
    /// Adds the services except for making outgoing HTTP calls.
    /// </summary>
    /// <remarks>
    /// This allows for things like Polly to be trimmed out of the app if it isn't used.
    /// </remarks>
    public static IHostApplicationBuilder AddBasicServiceDefaults(this IHostApplicationBuilder builder)
    {
        // Default health checks assume the event bus and self health checks
        builder.AddDefaultHealthChecks();

        builder.ConfigureOpenTelemetry();

        return builder;
    }

    public static IHostApplicationBuilder ConfigureOpenTelemetry(this IHostApplicationBuilder builder)
    {
        var serviceName = ResolveServiceName(builder);
        var perfMode = IsPerfMode(builder.Configuration);

        if (!perfMode)
        {
            ConfigurePyroscopeEnvironment(builder, serviceName);
        }

        if (!perfMode)
        {
            builder.Logging.AddOpenTelemetry(logging =>
            {
                logging.IncludeFormattedMessage = false;
                logging.IncludeScopes = false;
                logging.ParseStateValues = true;
            });
        }

        builder.Services.AddOpenTelemetry()
            .ConfigureResource(resource =>
            {
                resource.AddService(serviceName: serviceName, serviceVersion: ResolveServiceVersion())
                    .AddAttributes(new[]
                    {
                        new KeyValuePair<string, object>("deployment.environment", builder.Environment.EnvironmentName ?? "Production"),
                        new KeyValuePair<string, object>("telemetry.distro.name", "eshop"),
                        new KeyValuePair<string, object>("telemetry.distro.version", typeof(Extensions).Assembly.GetName().Version?.ToString() ?? "1.0.0"),
                        new KeyValuePair<string, object>("telemetry.mode", perfMode ? "perf" : "standard"),
                    });
            })
            .WithMetrics(metrics =>
            {
                metrics.AddAspNetCoreInstrumentation()
                    .AddRuntimeInstrumentation();

                if (!perfMode)
                {
                    metrics.AddHttpClientInstrumentation()
                        .AddMeter("Experimental.Microsoft.Extensions.AI");
                }

                metrics.AddPrometheusExporter();
            })
            .WithTracing(tracing =>
            {
                tracing.SetSampler(new TraceIdRatioBasedSampler(ResolveTraceSampleRatio(builder.Configuration, perfMode)));

                tracing.AddAspNetCoreInstrumentation(options =>
                    {
                        options.RecordException = true;
                        options.Filter = context => !IsNoiseEndpoint(context);
                    })
                    .AddSource("Experimental.Microsoft.Extensions.AI");

                if (!perfMode)
                {
                    tracing.AddEntityFrameworkCoreInstrumentation(options =>
                        {
                            options.SetDbStatementForText = false;
                            options.SetDbStatementForStoredProcedure = false;
                        })
                        .AddGrpcClientInstrumentation()
                        .AddHttpClientInstrumentation()
                        .AddSource("Npgsql");

                    // Link spans with Pyroscope profiles when profiler is present
                    tracing.AddProcessor(new PyroscopeSpanProcessor());
                }
            });

        builder.AddOpenTelemetryExporters();

        return builder;
    }

    private static IHostApplicationBuilder AddOpenTelemetryExporters(this IHostApplicationBuilder builder)
    {
        var endpoint = builder.Configuration["OpenTelemetry:Otlp:Endpoint"]
            ?? builder.Configuration["OTEL_EXPORTER_OTLP_ENDPOINT"];

        if (string.IsNullOrWhiteSpace(endpoint))
        {
            return builder;
        }

        var protocol = builder.Configuration["OpenTelemetry:Otlp:Protocol"]
            ?? builder.Configuration["OTEL_EXPORTER_OTLP_PROTOCOL"];

        var headers = builder.Configuration["OpenTelemetry:Otlp:Headers"];

        void ConfigureExporter(OtlpExporterOptions options)
        {
            if (Uri.TryCreate(endpoint, UriKind.Absolute, out var uri))
            {
                options.Endpoint = uri;
            }

            options.Protocol = ParseProtocol(protocol);
            if (!string.IsNullOrWhiteSpace(headers))
            {
                options.Headers = headers!;
            }
        }

        builder.Services.Configure<OpenTelemetryLoggerOptions>(logging =>
            logging.AddOtlpExporter(ConfigureExporter));

        builder.Services.ConfigureOpenTelemetryMeterProvider(metrics =>
            metrics.AddOtlpExporter(ConfigureExporter));

        builder.Services.ConfigureOpenTelemetryTracerProvider(tracing =>
            tracing.AddOtlpExporter(ConfigureExporter));

        return builder;
    }

    public static IHostApplicationBuilder AddDefaultHealthChecks(this IHostApplicationBuilder builder)
    {
        builder.Services.AddHealthChecks()
            // Add a default liveness check to ensure app is responsive
            .AddCheck("self", () => HealthCheckResult.Healthy(), ["live"]);

        return builder;
    }

    public static WebApplication MapDefaultEndpoints(this WebApplication app)
    {
        // Enable Prometheus metrics endpoint for monitoring
        app.MapPrometheusScrapingEndpoint();

        // Adding health checks endpoints to applications in non-development environments has security implications.
        // See https://aka.ms/dotnet/aspire/healthchecks for details before enabling these endpoints in non-development environments.
        if (app.Environment.IsDevelopment())
        {
            // All health checks must pass for app to be considered ready to accept traffic after starting
            app.MapHealthChecks("/health");

            // Only health checks tagged with the "live" tag must pass for app to be considered alive
            app.MapHealthChecks("/alive", new HealthCheckOptions
            {
                Predicate = r => r.Tags.Contains("live")
            });
        }

        return app;
    }

    private static string ResolveServiceName(IHostApplicationBuilder builder)
        => builder.Configuration["Telemetry:ServiceName"]
            ?? builder.Configuration["OTEL_SERVICE_NAME"]
            ?? builder.Environment.ApplicationName
            ?? "eshop-service";

    private static string ResolveServiceVersion()
        => typeof(Extensions).Assembly.GetName().Version?.ToString() ?? "1.0.0";

    private static double ResolveTraceSampleRatio(IConfiguration configuration, bool perfMode)
    {
        var configuredValue = configuration["OpenTelemetry:TraceSampleRatio"]
            ?? configuration["OTEL_TRACE_SAMPLE_RATIO"];

        if (double.TryParse(configuredValue, NumberStyles.Float, CultureInfo.InvariantCulture, out var ratio))
        {
            ratio = Math.Clamp(ratio, 0d, 1d);
            if (perfMode && ratio > 0.01d)
            {
                ratio = 0.01d;
            }
            return ratio;
        }

        return perfMode ? 0.01d : 0.05d;
    }

    private static bool IsNoiseEndpoint(HttpContext context)
    {
        var path = context.Request.Path;
        return path.StartsWithSegments("/health", StringComparison.OrdinalIgnoreCase) ||
               path.StartsWithSegments("/alive", StringComparison.OrdinalIgnoreCase);
    }

    private static OtlpExportProtocol ParseProtocol(string? value)
        => string.Equals(value, "http/protobuf", StringComparison.OrdinalIgnoreCase)
            ? OtlpExportProtocol.HttpProtobuf
            : OtlpExportProtocol.Grpc;

    private static void ConfigurePyroscopeEnvironment(IHostApplicationBuilder builder, string serviceName)
    {
        var section = builder.Configuration.GetSection("Pyroscope");
        if (!section.Exists())
        {
            return;
        }

        SetIfMissing("PYROSCOPE_SERVER_ADDRESS", section["Server"]);
        SetIfMissing("PYROSCOPE_APPLICATION_NAME", section["ApplicationName"] ?? $"eshop.{serviceName}");
        SetIfMissing("PYROSCOPE_API_KEY", section["ApiKey"]);
        SetIfMissing("PYROSCOPE_UPLOAD_INTERVAL", section["UploadIntervalSeconds"]);
        SetIfMissing("PYROSCOPE_SAMPLING_RATE", section["SampleRate"]);

        static void SetIfMissing(string key, string? value)
        {
            if (string.IsNullOrWhiteSpace(value))
            {
                return;
            }

            if (!string.IsNullOrEmpty(Environment.GetEnvironmentVariable(key)))
            {
                return;
            }

            Environment.SetEnvironmentVariable(key, value);
        }
    }

    private static bool IsPerfMode(IConfiguration configuration)
        => configuration.GetValue<bool?>("Telemetry:PerfMode")
            ?? configuration.GetValue<bool?>("Telemetry:PerformanceMode")
            ?? configuration.GetValue<bool?>("PerfMode")
            ?? configuration.GetValue<bool?>("PERF_MODE")
            ?? false;
}


