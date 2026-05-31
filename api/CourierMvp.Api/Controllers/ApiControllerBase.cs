using CourierMvp.Api.Auth;
using Microsoft.AspNetCore.Mvc;

namespace CourierMvp.Api.Controllers;

// NOTE: no [Route] here on purpose. Each concrete controller declares its own route
// template so a controller with a custom route (e.g. CodController) never ends up with
// two conflicting templates via attribute inheritance.
[ApiController]
[Produces("application/json")]
public abstract class ApiControllerBase : ControllerBase
{
    protected CurrentUser CurrentUser => CurrentUser.FromPrincipal(User)
        ?? throw new UnauthorizedAccessException("No authenticated user.");
}
