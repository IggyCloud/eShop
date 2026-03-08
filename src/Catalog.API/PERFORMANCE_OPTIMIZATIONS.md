# Catalog.API Performance Optimizations

This document outlines the performance optimizations applied to the `Catalog.API` service to maximize its throughput (Requests Per Second).

## System.Text.Json Source Generation

The primary optimization is the adoption of the `System.Text.Json` source generator for all JSON serialization and deserialization tasks within the API.

### The Problem: Default Behavior (Reflection)

By default, ASP.NET Core uses `System.Text.Json` with **runtime reflection**. When an HTTP request is received or a response is sent, the serializer inspects the C# objects (`CatalogItem`, etc.) at runtime to figure out how to convert them to and from JSON.

This process involves:
- Inspecting object types and properties using reflection.
- Caching this metadata for future use.
- Dynamically generating the required serialization logic on the fly.

While this is flexible, the reflection-based approach carries significant performance overhead, especially in high-throughput scenarios. It uses more CPU cycles and allocates more memory than is necessary. For a service where the goal is maximum RPS, this default behavior is a bottleneck.

### The Solution: Compile-Time Source Generation

The modern, high-performance solution is to use the `System.Text.Json` **source generator**. This moves the work of analyzing the data models from runtime to **compile-time**.

Here's how it works:
1.  We define a `JsonSerializerContext` class that lists all the types the API will serialize (`[JsonSerializable(typeof(CatalogItem))]`).
2.  During compilation, the source generator creates highly optimized serialization and deserialization logic specifically for those types.
3.  At runtime, the API uses this pre-generated code, completely bypassing the expensive reflection process.

### Benefits
-   **Reduced CPU Overhead**: Eliminates the need for runtime reflection and metadata caching.
-   **Lower Memory Usage**: Less memory is allocated for caching and dynamic generation.
-   **Faster Startup**: The application does less work when it first starts up.
-   **Improved Throughput (RPS)**: This is the key outcome. Faster serialization means the server can process more requests in the same amount of time, directly increasing the RPS the API can handle.
-   **Ahead-of-Time (AOT) Compatibility**: This is a best practice for creating AOT-compiled and trim-friendly applications.

By implementing source generation, we are telling the compiler to do the heavy lifting ahead of time, ensuring the `Catalog.API` is as fast and efficient as possible when handling requests.
