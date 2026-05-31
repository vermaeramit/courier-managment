using System.Data;
using Microsoft.Data.SqlClient;

namespace CourierMvp.Api.Data;

public sealed class SqlConnectionFactory : ISqlConnectionFactory
{
    private readonly string _connectionString;

    public SqlConnectionFactory(IConfiguration config)
    {
        // Connection string comes from configuration/environment, never hardcoded.
        _connectionString = config.GetConnectionString("CourierDb")
            ?? throw new InvalidOperationException("ConnectionStrings:CourierDb is not configured.");
    }

    public async Task<IDbConnection> CreateOpenConnectionAsync(CancellationToken ct = default)
    {
        var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync(ct);
        return conn;
    }
}
