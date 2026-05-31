using System.Data;

namespace CourierMvp.Api.Data;

/// <summary>
/// Abstraction over SQL connection creation so repositories stay pure data access
/// (one open connection per call). Implementations return an *open* connection.
/// </summary>
public interface ISqlConnectionFactory
{
    Task<IDbConnection> CreateOpenConnectionAsync(CancellationToken ct = default);
}
