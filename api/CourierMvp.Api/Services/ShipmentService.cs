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
    Task<ShipmentDto> GetByIdAsync(int id, CancellationToken ct);
    Task<PublicTrackingDto> TrackAsync(string trackingId, CancellationToken ct);
    Task<ShipmentDto> UpdateStatusAsync(CurrentUser caller, UpdateStatusRequest req, CancellationToken ct);
    Task<IReadOnlyList<ShipmentListItemDto>> ListAsync(
        CurrentUser caller, string? status, DateTime? from, DateTime? to, CancellationToken ct);
    Task<ShipmentDto> HandoffAsync(CurrentUser caller, HandoffRequest req, CancellationToken ct);
    Task<ShipmentDto> AssignRiderAsync(CurrentUser caller, AssignRiderRequest req, CancellationToken ct);
    Task<IReadOnlyList<RiderStopDto>> RiderStopsAsync(int riderId, DateTime? forDate, CancellationToken ct);
    Task<ShipmentDto> SubmitPodAsync(CurrentUser caller, PodSubmitRequest req, CancellationToken ct);
    Task<string> IssueOtpAsync(int shipmentId, CancellationToken ct);
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

    public async Task<ShipmentDto> GetByIdAsync(int id, CancellationToken ct)
        => await _repo.GetByIdAsync(id, ct) ?? throw new AppException("Shipment not found.");

    public Task<PublicTrackingDto> TrackAsync(string trackingId, CancellationToken ct)
        => _repo.GetByTrackingAsync(trackingId, ct);

    public async Task<ShipmentDto> UpdateStatusAsync(CurrentUser caller, UpdateStatusRequest req, CancellationToken ct)
    {
        var branchId = req.BranchId ?? caller.BranchId;
        var updated = await _repo.UpdateStatusAsync(new
        {
            req.ShipmentId,
            req.Status,
            BranchId = branchId,
            req.RiderId,
            req.Latitude,
            req.Longitude,
            req.Remarks
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
        var updated = await _repo.HandoffAsync(req, ct)
            ?? throw new AppException("Shipment not found.");
        NotifyStatusChange(updated);
        return updated;
    }

    public async Task<ShipmentDto> AssignRiderAsync(CurrentUser caller, AssignRiderRequest req, CancellationToken ct)
    {
        var updated = await _repo.AssignRiderAsync(req, ct)
            ?? throw new AppException("Shipment not found.");

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

    public Task<IReadOnlyList<RiderStopDto>> RiderStopsAsync(int riderId, DateTime? forDate, CancellationToken ct)
        => _repo.RiderDailyStopsAsync(riderId, forDate, ct);

    public async Task<ShipmentDto> SubmitPodAsync(CurrentUser caller, PodSubmitRequest req, CancellationToken ct)
    {
        // Rider id is taken from the authenticated caller when they are a rider.
        var riderId = caller.Role == Roles.Rider ? caller.Id : req.RiderId;
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
            req.Remarks
        }, ct);

        if (updated is null) throw new AppException("Shipment not found.");

        NotifyStatusChange(updated);
        return updated;
    }

    public async Task<string> IssueOtpAsync(int shipmentId, CancellationToken ct)
    {
        // 6-digit OTP. Sent to receiver via the (stub) SMS channel.
        var otp = Random.Shared.Next(100000, 999999).ToString();
        await _repo.IssueOtpAsync(shipmentId, otp, ct);

        var shipment = await _repo.GetByIdAsync(shipmentId, ct);
        if (shipment is not null)
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
