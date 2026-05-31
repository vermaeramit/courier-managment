using System.Data;
using CourierMvp.Api.Data;
using CourierMvp.Api.Models.Responses;
using Dapper;

namespace CourierMvp.Api.Repositories;

public interface IUserRepository
{
    Task<UserWithHashDto?> GetByEmailAsync(string email, CancellationToken ct);
    Task<UserDto?> GetByIdAsync(int id, CancellationToken ct);
    Task<IReadOnlyList<UserDto>> ListAsync(int? scopeBranchId, string? role, CancellationToken ct);
    Task<UserDto?> CreateAsync(object parameters, CancellationToken ct);
    Task<UserDto?> UpdateAsync(object parameters, CancellationToken ct);
}

public sealed class UserRepository : IUserRepository
{
    private readonly ISqlConnectionFactory _factory;
    public UserRepository(ISqlConnectionFactory factory) => _factory = factory;

    private static CommandDefinition Cmd(string proc, object? parameters, CancellationToken ct)
        => new(proc, parameters, commandType: CommandType.StoredProcedure, cancellationToken: ct);

    public async Task<UserWithHashDto?> GetByEmailAsync(string email, CancellationToken ct)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await conn.QuerySingleOrDefaultAsync<UserWithHashDto>(Cmd("usp_User_GetByEmail", new { Email = email }, ct));
    }

    public async Task<UserDto?> GetByIdAsync(int id, CancellationToken ct)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await conn.QuerySingleOrDefaultAsync<UserDto>(Cmd("usp_User_GetById", new { Id = id }, ct));
    }

    public async Task<IReadOnlyList<UserDto>> ListAsync(int? scopeBranchId, string? role, CancellationToken ct)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var rows = await conn.QueryAsync<UserDto>(
            Cmd("usp_User_List", new { ScopeBranchId = scopeBranchId, Role = role }, ct));
        return rows.ToList();
    }

    public async Task<UserDto?> CreateAsync(object parameters, CancellationToken ct)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await conn.QuerySingleOrDefaultAsync<UserDto>(Cmd("usp_User_Create", parameters, ct));
    }

    public async Task<UserDto?> UpdateAsync(object parameters, CancellationToken ct)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await conn.QuerySingleOrDefaultAsync<UserDto>(Cmd("usp_User_Update", parameters, ct));
    }
}
