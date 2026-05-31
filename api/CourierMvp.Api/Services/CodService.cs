using CourierMvp.Api.Auth;
using CourierMvp.Api.Common;
using CourierMvp.Api.Models.Requests;
using CourierMvp.Api.Models.Responses;
using CourierMvp.Api.Repositories;

namespace CourierMvp.Api.Services;

public interface ICodService
{
    Task<CodTransactionDto> RecordCollectionAsync(CurrentUser caller, RecordCodRequest req, CancellationToken ct);
    Task<CodTransactionDto> MarkDepositedAsync(CurrentUser caller, int shipmentId, CancellationToken ct);
    Task<IReadOnlyList<CodReconRiderDto>> ReconByRiderAsync(
        CurrentUser caller, DateTime from, DateTime to, CancellationToken ct);
    Task<IReadOnlyList<CodReconBranchDto>> ReconByBranchAsync(
        CurrentUser caller, DateTime from, DateTime to, CancellationToken ct);
}

public sealed class CodService : ICodService
{
    private readonly ICodRepository _repo;
    public CodService(ICodRepository repo) => _repo = repo;

    public async Task<CodTransactionDto> RecordCollectionAsync(
        CurrentUser caller, RecordCodRequest req, CancellationToken ct)
    {
        var riderId = caller.Role == Roles.Rider ? caller.Id : req.RiderId;
        var row = await _repo.RecordCollectionAsync(new
        {
            req.ShipmentId,
            RiderId = riderId,
            req.AmountCollected,
            ScopeBranchId = caller.ScopeBranchId
        }, ct);
        return row ?? throw new AppException("COD record not found for shipment.");
    }

    public async Task<CodTransactionDto> MarkDepositedAsync(CurrentUser caller, int shipmentId, CancellationToken ct)
        => await _repo.MarkDepositedAsync(shipmentId, caller.ScopeBranchId, ct)
           ?? throw new AppException("COD record not found for shipment.");

    public Task<IReadOnlyList<CodReconRiderDto>> ReconByRiderAsync(
        CurrentUser caller, DateTime from, DateTime to, CancellationToken ct)
        // Branch scoping: admin sees all riders, manager only their branch's riders.
        => _repo.ReconByRiderAsync(from, to, caller.ScopeBranchId, ct);

    public Task<IReadOnlyList<CodReconBranchDto>> ReconByBranchAsync(
        CurrentUser caller, DateTime from, DateTime to, CancellationToken ct)
        => _repo.ReconByBranchAsync(from, to, caller.ScopeBranchId, ct);
}
