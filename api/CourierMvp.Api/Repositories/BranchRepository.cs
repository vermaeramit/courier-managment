using System.Data;
using CourierMvp.Api.Data;
using CourierMvp.Api.Models.Responses;
using Dapper;

namespace CourierMvp.Api.Repositories;

public interface IBranchRepository
{
    Task<IReadOnlyList<BranchDto>> ListAsync(bool onlyActive, CancellationToken ct);
    Task<BranchDto?> GetByIdAsync(int id, CancellationToken ct);
    Task<BranchDto?> CreateAsync(object parameters, CancellationToken ct);
    Task<BranchDto?> UpdateAsync(object parameters, CancellationToken ct);
    Task<ServiceabilityDto?> CheckServiceableAsync(string pincode, CancellationToken ct);
}

public sealed class BranchRepository : IBranchRepository
{
    private readonly ISqlConnectionFactory _factory;
    public BranchRepository(ISqlConnectionFactory factory) => _factory = factory;

    public async Task<IReadOnlyList<BranchDto>> ListAsync(bool onlyActive, CancellationToken ct)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var rows = await conn.QueryAsync<BranchDto>(
            "usp_Branch_List", new { OnlyActive = onlyActive },
            commandType: CommandType.StoredProcedure);
        return rows.ToList();
    }

    public async Task<BranchDto?> GetByIdAsync(int id, CancellationToken ct)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await conn.QuerySingleOrDefaultAsync<BranchDto>(
            "usp_Branch_GetById", new { Id = id }, commandType: CommandType.StoredProcedure);
    }

    public async Task<BranchDto?> CreateAsync(object parameters, CancellationToken ct)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await conn.QuerySingleOrDefaultAsync<BranchDto>(
            "usp_Branch_Create", parameters, commandType: CommandType.StoredProcedure);
    }

    public async Task<BranchDto?> UpdateAsync(object parameters, CancellationToken ct)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await conn.QuerySingleOrDefaultAsync<BranchDto>(
            "usp_Branch_Update", parameters, commandType: CommandType.StoredProcedure);
    }

    public async Task<ServiceabilityDto?> CheckServiceableAsync(string pincode, CancellationToken ct)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await conn.QuerySingleOrDefaultAsync<ServiceabilityDto>(
            "usp_Pincode_CheckServiceable", new { Pincode = pincode },
            commandType: CommandType.StoredProcedure);
    }
}
