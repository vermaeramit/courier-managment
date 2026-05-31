using System.Security.Claims;

namespace CourierMvp.Api.Auth;

/// <summary>
/// Strongly-typed view of the authenticated principal, resolved per request.
/// Branch scoping uses <see cref="ScopeBranchId"/>: null for Admin (no filter),
/// the user's own BranchId otherwise.
/// </summary>
public sealed class CurrentUser
{
    public int Id { get; }
    public string Role { get; }
    public int? BranchId { get; }
    public bool IsAdmin => Role == Roles.Admin;

    public CurrentUser(int id, string role, int? branchId)
    {
        Id = id;
        Role = role;
        BranchId = branchId;
    }

    /// <summary>Null = admin (see everything). Otherwise the caller's branch.</summary>
    public int? ScopeBranchId => IsAdmin ? null : BranchId;

    public static CurrentUser? FromPrincipal(ClaimsPrincipal principal)
    {
        var idClaim = principal.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!int.TryParse(idClaim, out var id)) return null;

        var role = principal.FindFirstValue(ClaimTypes.Role) ?? "";
        var branchClaim = principal.FindFirstValue("branchId");
        int? branchId = int.TryParse(branchClaim, out var b) ? b : null;

        return new CurrentUser(id, role, branchId);
    }
}

public static class Roles
{
    public const string Admin = "Admin";
    public const string BranchManager = "BranchManager";
    public const string Rider = "Rider";
}
