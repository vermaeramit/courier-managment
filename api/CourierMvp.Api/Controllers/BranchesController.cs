using CourierMvp.Api.Auth;
using CourierMvp.Api.Models.Requests;
using CourierMvp.Api.Models.Responses;
using CourierMvp.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CourierMvp.Api.Controllers;

[Route("api/[controller]")]
[Authorize]
public sealed class BranchesController : ApiControllerBase
{
    private readonly IBranchService _service;
    public BranchesController(IBranchService service) => _service = service;

    // Any authenticated user may read the branch list (needed for booking dropdowns).
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<BranchDto>>> List(
        [FromQuery] bool onlyActive = false, CancellationToken ct = default)
        => Ok(await _service.ListAsync(onlyActive, ct));

    [Authorize(Roles = Roles.Admin)]
    [HttpPost]
    public async Task<ActionResult<BranchDto>> Create(CreateBranchRequest req, CancellationToken ct)
        => Ok(await _service.CreateAsync(req, ct));

    [Authorize(Roles = Roles.Admin)]
    [HttpPut("{id:int}")]
    public async Task<ActionResult<BranchDto>> Update(int id, UpdateBranchRequest req, CancellationToken ct)
        => Ok(await _service.UpdateAsync(req with { Id = id }, ct));

    // Pincode serviceability check used by the booking form.
    [HttpGet("serviceability/{pincode}")]
    public async Task<ActionResult<object>> CheckServiceable(string pincode, CancellationToken ct)
    {
        var result = await _service.CheckServiceableAsync(pincode, ct);
        return Ok(new { serviceable = result is not null, branch = result });
    }
}
