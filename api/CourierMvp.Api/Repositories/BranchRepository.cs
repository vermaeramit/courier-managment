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

    private static CommandDefinition Cmd(string proc, object? parameters, CancellationToken ct)
        => new(proc, parameters, commandType: CommandType.StoredProcedure, cancellationToken: ct);

    public async Task<IReadOnlyList<BranchDto>> ListAsync(bool onlyActive, CancellationToken ct)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var rows = await conn.QueryAsync<BranchDto>(Cmd("usp_Branch_List", new { OnlyActive = onlyActive }, ct));
        return rows.ToList();
    }

    public async Task<BranchDto?> GetByIdAsync(int id, CancellationToken ct)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await conn.QuerySingleOrDefaultAsync<BranchDto>(Cmd("usp_Branch_GetById", new { Id = id }, ct));
    }

    public async Task<BranchDto?> CreateAsync(object parameters, CancellationToken ct)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await conn.QuerySingleOrDefaultAsync<BranchDto>(Cmd("usp_Branch_Create", parameters, ct));
    }

    public async Task<BranchDto?> UpdateAsync(object parameters, CancellationToken ct)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await conn.QuerySingleOrDefaultAsync<BranchDto>(Cmd("usp_Branch_Update", parameters, ct));
    }

    public async Task<ServiceabilityDto?> CheckServiceableAsync(string pincode, CancellationToken ct)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await conn.QuerySingleOrDefaultAsync<ServiceabilityDto>(
            Cmd("usp_Pincode_CheckServiceable", new { Pincode = pincode }, ct));
    }
}
