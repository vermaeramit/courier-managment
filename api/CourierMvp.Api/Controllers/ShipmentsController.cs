using CourierMvp.Api.Auth;
using CourierMvp.Api.Models.Requests;
using CourierMvp.Api.Models.Responses;
using CourierMvp.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CourierMvp.Api.Controllers;

[Route("api/[controller]")]
[Authorize]
public sealed class ShipmentsController : ApiControllerBase
{
    private readonly IShipmentService _service;
    private readonly IHostEnvironment _env;
    public ShipmentsController(IShipmentService service, IHostEnvironment env)
    {
        _service = service;
        _env = env;
    }

    // Booking (admin / branch manager).
    [Authorize(Roles = $"{Roles.Admin},{Roles.BranchManager}")]
    [HttpPost]
    public async Task<ActionResult<ShipmentDto>> Create(CreateShipmentRequest req, CancellationToken ct)
        => Ok(await _service.CreateAsync(CurrentUser, req, ct));

    // Branch-scoped list with status + date filters.
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<ShipmentListItemDto>>> List(
        [FromQuery] string? status,
        [FromQuery] DateTime? from,
        [FromQuery] DateTime? to,
        CancellationToken ct)
        => Ok(await _service.ListAsync(CurrentUser, status, from, to, ct));

    [HttpGet("{id:int}")]
    public async Task<ActionResult<ShipmentDto>> Get(int id, CancellationToken ct)
        => Ok(await _service.GetByIdAsync(CurrentUser, id, ct));

    // Status update + append tracking event.
    [HttpPost("{id:int}/status")]
    public async Task<ActionResult<ShipmentDto>> UpdateStatus(
        int id, UpdateStatusRequest req, CancellationToken ct)
        => Ok(await _service.UpdateStatusAsync(CurrentUser, req with { ShipmentId = id }, ct));

    // Handoff origin -> destination branch.
    [Authorize(Roles = $"{Roles.Admin},{Roles.BranchManager}")]
    [HttpPost("{id:int}/handoff")]
    public async Task<ActionResult<ShipmentDto>> Handoff(
        int id, HandoffRequest req, CancellationToken ct)
        => Ok(await _service.HandoffAsync(CurrentUser, req with { ShipmentId = id }, ct));

    // Manual rider assignment.
    [Authorize(Roles = $"{Roles.Admin},{Roles.BranchManager}")]
    [HttpPost("{id:int}/assign-rider")]
    public async Task<ActionResult<ShipmentDto>> AssignRider(
        int id, AssignRiderRequest req, CancellationToken ct)
        => Ok(await _service.AssignRiderAsync(CurrentUser, req with { ShipmentId = id }, ct));

    // Issue a delivery OTP (sent to receiver via SMS stub).
    [HttpPost("{id:int}/issue-otp")]
    public async Task<ActionResult<object>> IssueOtp(int id, CancellationToken ct)
    {
        var otp = await _service.IssueOtpAsync(CurrentUser, id, ct);
        // The OTP is delivered to the receiver out-of-band. It is echoed in the
        // response ONLY in Development, never in any other environment.
        return _env.IsDevelopment()
            ? Ok(new { shipmentId = id, otpIssued = true, devOtp = otp })
            : Ok(new { shipmentId = id, otpIssued = true });
    }

    // Proof of delivery (photo + optional OTP) + COD collection. Riders use this.
    [Authorize(Roles = $"{Roles.Admin},{Roles.BranchManager},{Roles.Rider}")]
    [HttpPost("{id:int}/pod")]
    public async Task<ActionResult<ShipmentDto>> SubmitPod(
        int id, PodSubmitRequest req, CancellationToken ct)
        => Ok(await _service.SubmitPodAsync(CurrentUser, req with { ShipmentId = id }, ct));
}
