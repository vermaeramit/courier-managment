using System.Data;
using CourierMvp.Api.Data;
using CourierMvp.Api.Models.Responses;
using Dapper;

namespace CourierMvp.Api.Repositories;

public interface IDashboardRepository
{
    Task<DashboardDto> DailyCountsAsync(int? scopeBranchId, DateTime? forDate, CancellationToken ct);
}

public sealed class DashboardRepository : IDashboardRepository
{
    private readonly ISqlConnectionFactory _factory;
    public DashboardRepository(ISqlConnectionFactory factory) => _factory = factory;

    public async Task<DashboardDto> DailyCountsAsync(int? scopeBranchId, DateTime? forDate, CancellationToken ct)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var dto = await conn.QuerySingleOrDefaultAsync<DashboardDto>(new CommandDefinition(
            "usp_Dashboard_DailyCounts",
            new { ScopeBranchId = scopeBranchId, ForDate = forDate },
            commandType: CommandType.StoredProcedure, cancellationToken: ct));
        return dto ?? new DashboardDto();
    }
}
