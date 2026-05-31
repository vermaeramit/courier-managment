using CourierMvp.Api.Auth;
using CourierMvp.Api.Common;
using CourierMvp.Api.Models.Requests;
using CourierMvp.Api.Models.Responses;
using CourierMvp.Api.Notifications;
using CourierMvp.Api.Repositories;

namespace CourierMvp.Api.Services;

public interface IShipmentService
{
    Task<ShipmentDto> CreateAsync(CurrentUser caller, CreateShipmentRequest req, CancellationToken ct);
    Task<ShipmentDto> GetByIdAsync(CurrentUser caller, int id, CancellationToken ct);
    Task<PublicTrackingDto> TrackAsync(string trackingId, CancellationToken ct);
    Task<ShipmentDto> UpdateStatusAsync(CurrentUser caller, UpdateStatusRequest req, CancellationToken ct);
    Task<IReadOnlyList<ShipmentListItemDto>> ListAsync(
        CurrentUser caller, string? status, DateTime? from, DateTime? to, CancellationToken ct);
    Task<ShipmentDto> HandoffAsync(CurrentUser caller, HandoffRequest req, CancellationToken ct);
    Task<ShipmentDto> AssignRiderAsync(CurrentUser caller, AssignRiderRequest req, CancellationToken ct);
    Task<IReadOnlyList<RiderStopDto>> RiderStopsAsync(
        CurrentUser caller, int riderId, DateTime? forDate, CancellationToken ct);
    Task<ShipmentDto> SubmitPodAsync(CurrentUser caller, PodSubmitRequest req, CancellationToken ct);
    Task<string> IssueOtpAsync(CurrentUser caller, int shipmentId, CancellationToken ct);
}

public sealed class ShipmentService : IShipmentService
{
    private readonly IShipmentRepository _repo;
    private readonly INotificationQueue _push;        // best-effort rider push
    private readonly ICustomerNotifier _sms;          // stub SMS/WhatsApp to customers
    private readonly ILogger<ShipmentService> _log;

    public ShipmentService(
        IShipmentRepository repo, INotificationQueue push,
        ICustomerNotifier sms, ILogger<ShipmentService> log)
    {
        _repo = repo;
        _push = push;
        _sms = sms;
        _log = log;
    }

    public async Task<ShipmentDto> CreateAsync(CurrentUser caller, CreateShipmentRequest req, CancellationToken ct)
    {
        // Non-admin always books from their own branch as origin.
        var originBranchId = caller.IsAdmin ? req.OriginBranchId : (caller.BranchId ?? req.OriginBranchId);

        var created = await _repo.CreateAsync(new
        {
            OriginBranchId = originBranchId,
            req.DestBranchId,
            req.SenderName, req.SenderPhone, req.SenderAddress, req.SenderPincode,
            req.ReceiverName, req.ReceiverPhone, req.ReceiverAddress, req.ReceiverPincode,
            req.Weight, req.ServiceType, req.PaymentMode, req.CodAmount,
            CreatedBy = caller.Id
        }, ct);

        if (created is null) throw new AppException("Failed to create shipment.");

        // Best-effort customer notification (stub).
        await _sms.SendStatusUpdateAsync(created.ReceiverPhone, created.TrackingId, created.Status, ct: ct);
        return created;
    }

    public async Task<ShipmentDto> GetByIdAsync(CurrentUser caller, int id, CancellationToken ct)
        // Branch-scoped: a non-admin only resolves shipments touching their branch
        // (the proc filters them out otherwise), closing the by-id IDOR.
        => await _repo.GetByIdAsync(id, caller.ScopeBranchId, ct)
           ?? throw new AppException("Shipment not found.");

    public Task<PublicTrackingDto> TrackAsync(string trackingId, CancellationToken ct)
        => _repo.GetByTrackingAsync(trackingId, ct);

    public async Task<ShipmentDto> UpdateStatusAsync(CurrentUser caller, UpdateStatusRequest req, CancellationToken ct)
    {
        var branchId = req.BranchId ?? caller.BranchId;
        // Riders are additionally constrained to shipments assigned to them.
        var riderScopeId = caller.Role == Roles.Rider ? caller.Id : (int?)null;
        var updated = await _repo.UpdateStatusAsync(new
        {
            req.ShipmentId,
            req.Status,
            BranchId = branchId,
            // For a rider caller, stamp the event with their own id regardless of the request body.
            RiderId = caller.Role == Roles.Rider ? caller.Id : req.RiderId,
            req.Latitude,
            req.Longitude,
            req.Remarks,
            ScopeBranchId = caller.ScopeBranchId,
            RiderScopeId = riderScopeId
        }, ct);

        if (updated is null) throw new AppException("Shipment not found.");

        NotifyStatusChange(updated);
        return updated;
    }

    public Task<IReadOnlyList<ShipmentListItemDto>> ListAsync(
        CurrentUser caller, string? status, DateTime? from, DateTime? to, CancellationToken ct)
        // Branch scoping: admin -> null (all), others -> their branch.
        => _repo.ListAsync(caller.ScopeBranchId, status, from, to, ct);

    public async Task<ShipmentDto> HandoffAsync(CurrentUser caller, HandoffRequest req, CancellationToken ct)
    {
        var updated = await _repo.HandoffAsync(new
        {
            req.ShipmentId,
            req.ToBranchId,
            req.Status,
            req.Remarks,
            ScopeBranchId = caller.ScopeBranchId
        }, ct) ?? throw new AppException("Shipment not found.");
        NotifyStatusChange(updated);
        return updated;
    }

    public async Task<ShipmentDto> AssignRiderAsync(CurrentUser caller, AssignRiderRequest req, CancellationToken ct)
    {
        var updated = await _repo.AssignRiderAsync(new
        {
            req.ShipmentId,
            req.RiderId,
            ScopeBranchId = caller.ScopeBranchId
        }, ct) ?? throw new AppException("Shipment not found.");

        // Tell the rider they have a new assignment (best-effort).
        if (updated.AssignedRiderId is int riderId)
        {
            _push.Enqueue(new PushJob(
                riderId,
                "New assignment",
                $"Shipment {updated.TrackingId} assigned to you.",
                new Dictionary<string, string>
                {
                    ["shipmentId"] = updated.Id.ToString(),
                    ["trackingId"] = updated.TrackingId,
                    ["type"] = "assignment"
                }));
        }
        return updated;
    }

    public Task<IReadOnlyList<RiderStopDto>> RiderStopsAsync(
        CurrentUser caller, int riderId, DateTime? forDate, CancellationToken ct)
        // Non-admin callers can only view stops for a rider in their own branch.
        => _repo.RiderDailyStopsAsync(riderId, forDate, caller.ScopeBranchId, ct);

    public async Task<ShipmentDto> SubmitPodAsync(CurrentUser caller, PodSubmitRequest req, CancellationToken ct)
    {
        // Rider id is taken from the authenticated caller when they are a rider.
        var riderId = caller.Role == Roles.Rider ? caller.Id : req.RiderId;
        var riderScopeId = caller.Role == Roles.Rider ? caller.Id : (int?)null;
        var updated = await _repo.SubmitPodAsync(new
        {
            req.ShipmentId,
            req.Type,
            req.PhotoUrl,
            req.Otp,
            RiderId = riderId,
            req.Latitude,
            req.Longitude,
            req.CodCollected,
            req.Remarks,
            ScopeBranchId = caller.ScopeBranchId,
            RiderScopeId = riderScopeId
        }, ct);

        if (updated is null) throw new AppException("Shipment not found.");

        NotifyStatusChange(updated);
        return updated;
    }

    public async Task<string> IssueOtpAsync(CurrentUser caller, int shipmentId, CancellationToken ct)
    {
        // Resolve the shipment within the caller's branch scope first — this both
        // authorizes the action and gives us the receiver phone. (Also closes the
        // IDOR where any role could issue an OTP for any shipment id.)
        var shipment = await _repo.GetByIdAsync(shipmentId, caller.ScopeBranchId, ct)
            ?? throw new AppException("Shipment not found.");

        // Cryptographically-strong 6-digit OTP (RandomNumberGenerator, not Random).
        var otp = System.Security.Cryptography.RandomNumberGenerator
            .GetInt32(0, 1_000_000).ToString("D6");
        await _repo.IssueOtpAsync(shipmentId, otp, ct);

        // Sent to the receiver out-of-band via the (stub) SMS channel only.
        await _sms.SendStatusUpdateAsync(
            shipment.ReceiverPhone, shipment.TrackingId,
            $"Delivery OTP: {otp}", ct: ct);

        return otp;
    }

    // Notifications never block / roll back the write. Push -> background queue;
    // customer SMS -> stub. Both are wrapped so a failure here can't bubble up.
    private void NotifyStatusChange(ShipmentDto s)
    {
        try
        {
            if (s.AssignedRiderId is int riderId)
            {
                _push.Enqueue(new PushJob(
                    riderId,
                    "Shipment updated",
                    $"{s.TrackingId} is now {s.Status}.",
                    new Dictionary<string, string>
                    {
                        ["shipmentId"] = s.Id.ToString(),
                        ["trackingId"] = s.TrackingId,
                        ["status"] = s.Status,
                        ["type"] = "status"
                    }));
            }

            // Fire-and-forget customer SMS stub (do not await on the write path).
            _ = _sms.SendStatusUpdateAsync(s.ReceiverPhone, s.TrackingId, s.Status);
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "Non-fatal: notification dispatch failed for shipment {Id}.", s.Id);
        }
    }
}
