using CourierMvp.Api.Auth;
using CourierMvp.Api.Models.Requests;
using CourierMvp.Api.Models.Responses;
using CourierMvp.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CourierMvp.Api.Controllers;

[Authorize]
[Route("api/cod")]
public sealed class CodController : ApiControllerBase
{
    private readonly ICodService _service;
    public CodController(ICodService service) => _service = service;

    // Record collected cash (rider, or staff on behalf of a rider).
    [HttpPost("record")]
    public async Task<ActionResult<CodTransactionDto>> Record(RecordCodRequest req, CancellationToken ct)
        => Ok(await _service.RecordCollectionAsync(CurrentUser, req, ct));

    // Mark collected cash deposited to the branch.
    [Authorize(Roles = $"{Roles.Admin},{Roles.BranchManager}")]
    [HttpPost("{shipmentId:int}/deposit")]
    public async Task<ActionResult<CodTransactionDto>> Deposit(int shipmentId, CancellationToken ct)
        => Ok(await _service.MarkDepositedAsync(shipmentId, ct));

    // Reconciliation per rider for a date range.
    [Authorize(Roles = $"{Roles.Admin},{Roles.BranchManager}")]
    [HttpGet("reconciliation/by-rider")]
    public async Task<ActionResult<IReadOnlyList<CodReconRiderDto>>> ReconByRider(
        [FromQuery] DateTime from, [FromQuery] DateTime to, CancellationToken ct)
        => Ok(await _service.ReconByRiderAsync(CurrentUser, from, to, ct));

    // Reconciliation per branch for a date range.
    [Authorize(Roles = $"{Roles.Admin},{Roles.BranchManager}")]
    [HttpGet("reconciliation/by-branch")]
    public async Task<ActionResult<IReadOnlyList<CodReconBranchDto>>> ReconByBranch(
        [FromQuery] DateTime from, [FromQuery] DateTime to, CancellationToken ct)
        => Ok(await _service.ReconByBranchAsync(CurrentUser, from, to, ct));
}
