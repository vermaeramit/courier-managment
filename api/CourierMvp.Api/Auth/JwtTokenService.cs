using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using CourierMvp.Api.Models.Responses;
using Microsoft.IdentityModel.Tokens;

namespace CourierMvp.Api.Auth;

public interface IJwtTokenService
{
    string CreateToken(UserDto user);
}

public sealed class JwtTokenService : IJwtTokenService
{
    private readonly IConfiguration _config;
    public JwtTokenService(IConfiguration config) => _config = config;

    public string CreateToken(UserDto user)
    {
        var jwt = _config.GetSection("Jwt");
        var signingKey = jwt["SigningKey"]
            ?? throw new InvalidOperationException("Jwt:SigningKey not configured.");

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(signingKey));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new(ClaimTypes.Name, user.Name),
            new(ClaimTypes.Email, user.Email),
            new(ClaimTypes.Role, user.Role),
        };
        if (user.BranchId is int b)
            claims.Add(new Claim("branchId", b.ToString()));

        var expiryMinutes = int.TryParse(jwt["ExpiryMinutes"], out var m) ? m : 720;

        var token = new JwtSecurityToken(
            issuer: jwt["Issuer"],
            audience: jwt["Audience"],
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(expiryMinutes),
            signingCredentials: creds);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}
