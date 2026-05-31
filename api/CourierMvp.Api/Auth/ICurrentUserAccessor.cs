using Microsoft.AspNetCore.Http;

namespace CourierMvp.Api.Auth;

public interface ICurrentUserAccessor
{
    CurrentUser? User { get; }
    CurrentUser Require();   // throws if unauthenticated
}

public sealed class CurrentUserAccessor : ICurrentUserAccessor
{
    private readonly IHttpContextAccessor _http;
    public CurrentUserAccessor(IHttpContextAccessor http) => _http = http;

    public CurrentUser? User
    {
        get
        {
            var principal = _http.HttpContext?.User;
            return principal is null ? null : CurrentUser.FromPrincipal(principal);
        }
    }

    public CurrentUser Require()
        => User ?? throw new UnauthorizedAccessException("No authenticated user.");
}
