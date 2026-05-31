using CourierMvp.Api.Auth;
using CourierMvp.Api.Common;
using CourierMvp.Api.Models.Requests;
using CourierMvp.Api.Models.Responses;
using CourierMvp.Api.Repositories;
using Microsoft.AspNetCore.Identity;

namespace CourierMvp.Api.Services;

public interface IAuthService
{
    Task<LoginResponse> LoginAsync(LoginRequest req, CancellationToken ct);
    string HashPassword(string plaintext); // exposed for user creation + dev tooling
}

public sealed class AuthService : IAuthService
{
    private readonly IUserRepository _users;
    private readonly IJwtTokenService _jwt;
    private readonly PasswordHasher<string> _hasher = new();

    public AuthService(IUserRepository users, IJwtTokenService jwt)
    {
        _users = users;
        _jwt = jwt;
    }

    public async Task<LoginResponse> LoginAsync(LoginRequest req, CancellationToken ct)
    {
        var user = await _users.GetByEmailAsync(req.Email, ct);
        if (user is null || user.Status != "Active")
            throw new AppException("Invalid credentials.");

        // The TUser argument is ignored by the default PasswordHasher (the salt is
        // random and embedded in the hash), so we pass the same value used when
        // hashing — string.Empty — to keep the two call sites consistent.
        var result = _hasher.VerifyHashedPassword(string.Empty, user.PasswordHash, req.Password);
        if (result == PasswordVerificationResult.Failed)
            throw new AppException("Invalid credentials.");

        var dto = new UserDto
        {
            Id = user.Id, BranchId = user.BranchId, Name = user.Name, Role = user.Role,
            Phone = user.Phone, Email = user.Email, Status = user.Status,
            CreatedAt = user.CreatedAt, BranchCode = user.BranchCode, BranchName = user.BranchName
        };

        return new LoginResponse { Token = _jwt.CreateToken(dto), User = dto };
    }

    // PBKDF2 via ASP.NET Core Identity's PasswordHasher. The TUser argument is
    // unused by the default hasher (PBKDF2 uses a random salt embedded in the
    // output), so we pass string.Empty here and at the verification call site.
    public string HashPassword(string plaintext) => _hasher.HashPassword(string.Empty, plaintext);
}
