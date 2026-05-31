using CourierMvp.Api.Models.Responses;
using CourierMvp.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CourierMvp.Api.Controllers;

[Route("api/[controller]")]
[Authorize]
public sealed class DashboardController : ApiControllerBase
{
    private readonly IDashboardService _service;
    public DashboardController(IDashboardService service) => _service = service;

    // Daily counts: branch-scoped for managers, HQ rollup for admin.
    [HttpGet]
    public async Task<ActionResult<DashboardDto>> Get([FromQuery] DateTime? forDate, CancellationToken ct)
        => Ok(await _service.DailyCountsAsync(CurrentUser, forDate, ct));
}
