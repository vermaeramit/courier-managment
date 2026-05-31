using CourierMvp.Api.Auth;
using CourierMvp.Api.Common;
using CourierMvp.Api.Models.Requests;
using CourierMvp.Api.Models.Responses;
using CourierMvp.Api.Repositories;

namespace CourierMvp.Api.Services;

public interface IUserService
{
    Task<IReadOnlyList<UserDto>> ListAsync(CurrentUser caller, string? role, CancellationToken ct);
    Task<UserDto> CreateAsync(CurrentUser caller, CreateUserRequest req, CancellationToken ct);
    Task<UserDto> UpdateAsync(CurrentUser caller, UpdateUserRequest req, CancellationToken ct);
}

public sealed class UserService : IUserService
{
    private readonly IUserRepository _repo;
    private readonly IAuthService _auth;

    public UserService(IUserRepository repo, IAuthService auth)
    {
        _repo = repo;
        _auth = auth;
    }

    public Task<IReadOnlyList<UserDto>> ListAsync(CurrentUser caller, string? role, CancellationToken ct)
        // Branch scoping enforced here: admin passes null (no filter), others their branch.
        => _repo.ListAsync(caller.ScopeBranchId, role, ct);

    public async Task<UserDto> CreateAsync(CurrentUser caller, CreateUserRequest req, CancellationToken ct)
    {
        // A branch manager may only create users within their own branch and not Admins.
        var branchId = req.BranchId;
        if (!caller.IsAdmin)
        {
            if (req.Role == Roles.Admin)
                throw new AppException("Only an admin can create admin users.");
            branchId = caller.BranchId; // force own branch
        }

        var hash = _auth.HashPassword(req.Password);
        var created = await _repo.CreateAsync(new
        {
            BranchId = branchId,
            req.Name,
            req.Role,
            req.Phone,
            req.Email,
            PasswordHash = hash,
            req.Status
        }, ct);

        return created ?? throw new AppException("Failed to create user.");
    }

    public async Task<UserDto> UpdateAsync(CurrentUser caller, UpdateUserRequest req, CancellationToken ct)
    {
        var branchId = caller.IsAdmin ? req.BranchId : caller.BranchId;
        var updated = await _repo.UpdateAsync(new
        {
            req.Id,
            BranchId = branchId,
            req.Name,
            req.Role,
            req.Phone,
            req.Status
        }, ct);

        return updated ?? throw new AppException("User not found.");
    }
}
