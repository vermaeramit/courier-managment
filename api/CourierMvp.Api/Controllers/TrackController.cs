using CourierMvp.Api.Models.Responses;
using CourierMvp.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CourierMvp.Api.Controllers;

/// <summary>
/// Public, unauthenticated tracking. Powers the customer tracking link.
/// </summary>
[ApiController]
[Route("api/[controller]")]
[AllowAnonymous]
public sealed class TrackController : ControllerBase
{
    private readonly IShipmentService _service;
    public TrackController(IShipmentService service) => _service = service;

    [HttpGet("{trackingId}")]
    public async Task<ActionResult<PublicTrackingDto>> Track(string trackingId, CancellationToken ct)
    {
        var result = await _service.TrackAsync(trackingId, ct);
        if (result.Summary is null)
            return NotFound(new { message = "Tracking ID not found." });
        return Ok(result);
    }
}
