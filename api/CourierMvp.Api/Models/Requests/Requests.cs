namespace CourierMvp.Api.Models.Requests;

// Request DTOs. Property names match stored-proc @parameters (minus @) so Dapper
// maps them automatically when passed straight through with CommandType.StoredProcedure.
// Note: properties the *caller* must not set (e.g. CreatedBy, scope ids) are added by
// the service layer from the authenticated principal, not bound from the request body.

public sealed record LoginRequest(string Email, string Password);

public sealed record CreateUserRequest(
    int? BranchId,
    string Name,
    string Role,
    string? Phone,
    string Email,
    string Password,        // plaintext in; service hashes -> PasswordHash for the proc
    string Status = "Active");

public sealed record UpdateUserRequest(
    int Id,
    int? BranchId,
    string Name,
    string Role,
    string? Phone,
    string Status);

public sealed record CreateBranchRequest(
    string Code,
    string Name,
    string City,
    string Pincode,
    int? ManagerId,
    bool IsActive = true);

public sealed record UpdateBranchRequest(
    int Id,
    string Name,
    string City,
    string Pincode,
    int? ManagerId,
    bool IsActive);

public sealed record CreateShipmentRequest(
    int OriginBranchId,
    int DestBranchId,
    string SenderName,
    string SenderPhone,
    string SenderAddress,
    string SenderPincode,
    string ReceiverName,
    string ReceiverPhone,
    string ReceiverAddress,
    string ReceiverPincode,
    decimal Weight,
    string ServiceType,
    string PaymentMode,
    decimal CodAmount = 0m);

public sealed record UpdateStatusRequest(
    int ShipmentId,
    string Status,
    int? BranchId,
    int? RiderId,
    decimal? Latitude,
    decimal? Longitude,
    string? Remarks);

public sealed record HandoffRequest(
    int ShipmentId,
    int ToBranchId,
    string Status = "InTransit",
    string? Remarks = null);

public sealed record AssignRiderRequest(int ShipmentId, int RiderId);

public sealed record PodSubmitRequest(
    int ShipmentId,
    string Type,            // Photo | OTP | Signature
    string? PhotoUrl,
    string? Otp,
    int RiderId,
    decimal? Latitude,
    decimal? Longitude,
    decimal? CodCollected,
    string? Remarks);

public sealed record RecordCodRequest(int ShipmentId, int RiderId, decimal AmountCollected);

public sealed record DateRangeRequest(DateTime FromDate, DateTime ToDate);
