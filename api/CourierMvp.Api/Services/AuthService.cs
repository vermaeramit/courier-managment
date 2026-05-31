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

        var result = _hasher.VerifyHashedPassword(user.Email, user.PasswordHash, req.Password);
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

    // PBKDF2 via ASP.NET Core Identity's PasswordHasher. We key on email purely as the
    // "user" salt input expected by the API; verification uses the same convention.
    public string HashPassword(string plaintext) => _hasher.HashPassword(string.Empty, plaintext);
}
