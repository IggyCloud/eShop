# Use the official .NET SDK image to build the project
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copy the project file and restore dependencies
COPY ["src/Catalog.API/Catalog.API.csproj", "src/Catalog.API/"]
# Copy all the other files
COPY . .
RUN dotnet restore "src/Catalog.API/Catalog.API.csproj"

# Build and publish the application
WORKDIR "/src/src/Catalog.API"
RUN dotnet publish "Catalog.API.csproj" -c Release -o /app/publish

# Use the official ASP.NET runtime image for the final image
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "Catalog.API.dll"]
