using CourierMvp.Api.Auth;
using CourierMvp.Api.Models.Responses;
using CourierMvp.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CourierMvp.Api.Controllers;

[Route("api/[controller]")]
[Authorize]
public sealed class RiderController : ApiControllerBase
{
    private readonly IShipmentService _service;
    public RiderController(IShipmentService service) => _service = service;

    /// <summary>
    /// The calling rider's daily stop list. Managers/admin may pass ?riderId= to view a rider.
    /// </summary>
    [HttpGet("stops")]
    public async Task<ActionResult<IReadOnlyList<RiderStopDto>>> MyStops(
        [FromQuery] int? riderId, [FromQuery] DateTime? forDate, CancellationToken ct)
    {
        var targetRider = CurrentUser.Role == Roles.Rider ? CurrentUser.Id : (riderId ?? CurrentUser.Id);
        return Ok(await _service.RiderStopsAsync(targetRider, forDate, ct));
    }
}
