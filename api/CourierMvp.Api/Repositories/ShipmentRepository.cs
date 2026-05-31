using System.Data;
using CourierMvp.Api.Data;
using CourierMvp.Api.Models.Responses;
using Dapper;

namespace CourierMvp.Api.Repositories;

public interface IShipmentRepository
{
    Task<ShipmentDto?> CreateAsync(object parameters, CancellationToken ct);
    Task<ShipmentDto?> GetByIdAsync(int id, CancellationToken ct);
    Task<PublicTrackingDto> GetByTrackingAsync(string trackingId, CancellationToken ct);
    Task<ShipmentDto?> UpdateStatusAsync(object parameters, CancellationToken ct);
    Task<IReadOnlyList<ShipmentListItemDto>> ListAsync(
        int? scopeBranchId, string? status, DateTime? from, DateTime? to, CancellationToken ct);
    Task<ShipmentDto?> HandoffAsync(object parameters, CancellationToken ct);
    Task<ShipmentDto?> AssignRiderAsync(object parameters, CancellationToken ct);
    Task<IReadOnlyList<RiderStopDto>> RiderDailyStopsAsync(int riderId, DateTime? forDate, CancellationToken ct);
    Task<ShipmentDto?> SubmitPodAsync(object parameters, CancellationToken ct);
    Task IssueOtpAsync(int shipmentId, string otp, CancellationToken ct);
}

public sealed class ShipmentRepository : IShipmentRepository
{
    private readonly ISqlConnectionFactory _factory;
    public ShipmentRepository(ISqlConnectionFactory factory) => _factory = factory;

    public async Task<ShipmentDto?> CreateAsync(object parameters, CancellationToken ct)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await conn.QuerySingleOrDefaultAsync<ShipmentDto>(
            "usp_Shipment_Create", parameters, commandType: CommandType.StoredProcedure);
    }

    public async Task<ShipmentDto?> GetByIdAsync(int id, CancellationToken ct)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await conn.QuerySingleOrDefaultAsync<ShipmentDto>(
            "usp_Shipment_GetById", new { Id = id }, commandType: CommandType.StoredProcedure);
    }

    public async Task<PublicTrackingDto> GetByTrackingAsync(string trackingId, CancellationToken ct)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        // Proc returns two result sets: [0] summary, [1] events.
        using var multi = await conn.QueryMultipleAsync(
            "usp_Shipment_GetByTracking", new { TrackingId = trackingId },
            commandType: CommandType.StoredProcedure);

        var summary = await multi.ReadSingleOrDefaultAsync<TrackingSummaryDto>();
        var events = (await multi.ReadAsync<TrackingEventDto>()).ToList();
        return new PublicTrackingDto { Summary = summary, Events = events };
    }

    public async Task<ShipmentDto?> UpdateStatusAsync(object parameters, CancellationToken ct)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await conn.QuerySingleOrDefaultAsync<ShipmentDto>(
            "usp_Shipment_UpdateStatus", parameters, commandType: CommandType.StoredProcedure);
    }

    public async Task<IReadOnlyList<ShipmentListItemDto>> ListAsync(
        int? scopeBranchId, string? status, DateTime? from, DateTime? to, CancellationToken ct)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var rows = await conn.QueryAsync<ShipmentListItemDto>(
            "usp_Shipment_List",
            new { ScopeBranchId = scopeBranchId, Status = status, FromDate = from, ToDate = to },
            commandType: CommandType.StoredProcedure);
        return rows.ToList();
    }

    public async Task<ShipmentDto?> HandoffAsync(object parameters, CancellationToken ct)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await conn.QuerySingleOrDefaultAsync<ShipmentDto>(
            "usp_Shipment_Handoff", parameters, commandType: CommandType.StoredProcedure);
    }

    public async Task<ShipmentDto?> AssignRiderAsync(object parameters, CancellationToken ct)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await conn.QuerySingleOrDefaultAsync<ShipmentDto>(
            "usp_Shipment_AssignRider", parameters, commandType: CommandType.StoredProcedure);
    }

    public async Task<IReadOnlyList<RiderStopDto>> RiderDailyStopsAsync(
        int riderId, DateTime? forDate, CancellationToken ct)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var rows = await conn.QueryAsync<RiderStopDto>(
            "usp_Rider_DailyStops", new { RiderId = riderId, ForDate = forDate },
            commandType: CommandType.StoredProcedure);
        return rows.ToList();
    }

    public async Task<ShipmentDto?> SubmitPodAsync(object parameters, CancellationToken ct)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await conn.QuerySingleOrDefaultAsync<ShipmentDto>(
            "usp_Pod_Submit", parameters, commandType: CommandType.StoredProcedure);
    }

    public async Task IssueOtpAsync(int shipmentId, string otp, CancellationToken ct)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await conn.ExecuteAsync(
            "usp_Pod_IssueOtp", new { ShipmentId = shipmentId, Otp = otp },
            commandType: CommandType.StoredProcedure);
    }
}
