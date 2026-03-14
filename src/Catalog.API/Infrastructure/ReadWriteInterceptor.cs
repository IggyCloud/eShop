using System.Data.Common;
using Microsoft.EntityFrameworkCore.Diagnostics;

namespace eShop.Catalog.API.Infrastructure;

public class ReadWriteInterceptor : DbCommandInterceptor
{
    private readonly string _replicaConnectionString;

    public ReadWriteInterceptor(string replicaConnectionString)
    {
        _replicaConnectionString = replicaConnectionString;
    }

    public override InterceptionResult<DbDataReader> ReaderExecuting(
        DbCommand command, 
        CommandEventData eventData, 
        InterceptionResult<DbDataReader> result)
    {
        if (IsReadOnly(command) && 
            command.Connection is not null && 
            command.Connection.State == System.Data.ConnectionState.Closed &&
            command.Connection.ConnectionString != _replicaConnectionString)
        {
            command.Connection.ConnectionString = _replicaConnectionString;
        }
        return base.ReaderExecuting(command, eventData, result);
    }

    public override ValueTask<InterceptionResult<DbDataReader>> ReaderExecutingAsync(
        DbCommand command, 
        CommandEventData eventData, 
        InterceptionResult<DbDataReader> result, 
        CancellationToken cancellationToken = default)
    {
        if (IsReadOnly(command) && 
            command.Connection is not null && 
            command.Connection.State == System.Data.ConnectionState.Closed &&
            command.Connection.ConnectionString != _replicaConnectionString)
        {
            command.Connection.ConnectionString = _replicaConnectionString;
        }
        return base.ReaderExecutingAsync(command, eventData, result, cancellationToken);
    }

    private static bool IsReadOnly(DbCommand command)
    {
        // Simple heuristic: if it's a SELECT and doesn't involve system tables or specific patterns
        return command.CommandText.TrimStart().StartsWith("SELECT", StringComparison.OrdinalIgnoreCase);
    }
}
