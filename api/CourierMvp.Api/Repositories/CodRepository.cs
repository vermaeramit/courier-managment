using System.Data;
using CourierMvp.Api.Data;
using CourierMvp.Api.Models.Responses;
using Dapper;

namespace CourierMvp.Api.Repositories;

public interface ICodRepository
{
    Task<CodTransactionDto?> RecordCollectionAsync(object parameters, CancellationToken ct);
    Task<CodTransactionDto?> MarkDepositedAsync(int shipmentId, CancellationToken ct);
    Task<IReadOnlyList<CodReconRiderDto>> ReconByRiderAsync(
        DateTime from, DateTime to, int? scopeBranchId, CancellationToken ct);
    Task<IReadOnlyList<CodReconBranchDto>> ReconByBranchAsync(
        DateTime from, DateTime to, int? scopeBranchId, CancellationToken ct);
}

public sealed class CodRepository : ICodRepository
{
    private readonly ISqlConnectionFactory _factory;
    public CodRepository(ISqlConnectionFactory factory) => _factory = factory;

    public async Task<CodTransactionDto?> RecordCollectionAsync(object parameters, CancellationToken ct)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await conn.QuerySingleOrDefaultAsync<CodTransactionDto>(
            "usp_Cod_RecordCollection", parameters, commandType: CommandType.StoredProcedure);
    }

    public async Task<CodTransactionDto?> MarkDepositedAsync(int shipmentId, CancellationToken ct)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await conn.QuerySingleOrDefaultAsync<CodTransactionDto>(
            "usp_Cod_MarkDeposited", new { ShipmentId = shipmentId },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IReadOnlyList<CodReconRiderDto>> ReconByRiderAsync(
        DateTime from, DateTime to, int? scopeBranchId, CancellationToken ct)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var rows = await conn.QueryAsync<CodReconRiderDto>(
            "usp_Cod_ReconciliationByRider",
            new { FromDate = from, ToDate = to, ScopeBranchId = scopeBranchId },
            commandType: CommandType.StoredProcedure);
        return rows.ToList();
    }

    public async Task<IReadOnlyList<CodReconBranchDto>> ReconByBranchAsync(
        DateTime from, DateTime to, int? scopeBranchId, CancellationToken ct)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var rows = await conn.QueryAsync<CodReconBranchDto>(
            "usp_Cod_ReconciliationByBranch",
            new { FromDate = from, ToDate = to, ScopeBranchId = scopeBranchId },
            commandType: CommandType.StoredProcedure);
        return rows.ToList();
    }
}
