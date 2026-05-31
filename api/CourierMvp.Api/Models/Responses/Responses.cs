namespace CourierMvp.Api.Models.Responses;

// Response/read DTOs. Dapper materialises proc result sets into these.
// Money is decimal everywhere; timestamps are UTC.

public sealed class UserDto
{
    public int Id { get; set; }
    public int? BranchId { get; set; }
    public string Name { get; set; } = "";
    public string Role { get; set; } = "";
    public string? Phone { get; set; }
    public string Email { get; set; } = "";
    public string Status { get; set; } = "";
    public DateTime CreatedAt { get; set; }
    public string? BranchCode { get; set; }
    public string? BranchName { get; set; }
}

// Internal-only: carries the password hash. Never returned to clients.
public sealed class UserWithHashDto
{
    public int Id { get; set; }
    public int? BranchId { get; set; }
    public string Name { get; set; } = "";
    public string Role { get; set; } = "";
    public string? Phone { get; set; }
    public string Email { get; set; } = "";
    public string PasswordHash { get; set; } = "";
    public string Status { get; set; } = "";
    public DateTime CreatedAt { get; set; }
    public string? BranchCode { get; set; }
    public string? BranchName { get; set; }
}

public sealed class LoginResponse
{
    public string Token { get; set; } = "";
    public UserDto User { get; set; } = new();
}

public sealed class BranchDto
{
    public int Id { get; set; }
    public string Code { get; set; } = "";
    public string Name { get; set; } = "";
    public string City { get; set; } = "";
    public string Pincode { get; set; } = "";
    public int? ManagerId { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
}

public sealed class ServiceabilityDto
{
    public int Id { get; set; }
    public string Pincode { get; set; } = "";
    public int BranchId { get; set; }
    public bool IsServiceable { get; set; }
    public string? BranchCode { get; set; }
    public string? BranchName { get; set; }
}

public sealed class ShipmentDto
{
    public int Id { get; set; }
    public string TrackingId { get; set; } = "";
    public string? InvoiceNumber { get; set; }
    public string? BarcodeValue { get; set; }
    public int OriginBranchId { get; set; }
    public string? OriginBranchCode { get; set; }
    public string? OriginBranchName { get; set; }
    public int DestBranchId { get; set; }
    public string? DestBranchCode { get; set; }
    public string? DestBranchName { get; set; }
    public int? CurrentBranchId { get; set; }
    public string SenderName { get; set; } = "";
    public string SenderPhone { get; set; } = "";
    public string SenderAddress { get; set; } = "";
    public string SenderPincode { get; set; } = "";
    public string ReceiverName { get; set; } = "";
    public string ReceiverPhone { get; set; } = "";
    public string ReceiverAddress { get; set; } = "";
    public string ReceiverPincode { get; set; } = "";
    public decimal Weight { get; set; }
    public string ServiceType { get; set; } = "";
    public string PaymentMode { get; set; } = "";
    public decimal CodAmount { get; set; }
    public string Status { get; set; } = "";
    public int? AssignedRiderId { get; set; }
    public string? AssignedRiderName { get; set; }
    public int CreatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

public sealed class ShipmentListItemDto
{
    public int Id { get; set; }
    public string TrackingId { get; set; } = "";
    public string? InvoiceNumber { get; set; }
    public int OriginBranchId { get; set; }
    public string? OriginBranchCode { get; set; }
    public int DestBranchId { get; set; }
    public string? DestBranchCode { get; set; }
    public string ReceiverName { get; set; } = "";
    public string ReceiverPincode { get; set; } = "";
    public string ServiceType { get; set; } = "";
    public string PaymentMode { get; set; } = "";
    public decimal CodAmount { get; set; }
    public string Status { get; set; } = "";
    public int? AssignedRiderId { get; set; }
    public string? AssignedRiderName { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

public sealed class TrackingEventDto
{
    public string Status { get; set; } = "";
    public string? Remarks { get; set; }
    public decimal? Latitude { get; set; }
    public decimal? Longitude { get; set; }
    public string? BranchName { get; set; }
    public DateTime CreatedAt { get; set; }
}

public sealed class TrackingSummaryDto
{
    public string TrackingId { get; set; } = "";
    public string Status { get; set; } = "";
    public string ServiceType { get; set; } = "";
    public string PaymentMode { get; set; } = "";
    public string? OriginBranchName { get; set; }
    public string? OriginCity { get; set; }
    public string? DestBranchName { get; set; }
    public string? DestCity { get; set; }
    public string ReceiverName { get; set; } = "";
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

public sealed class PublicTrackingDto
{
    public TrackingSummaryDto? Summary { get; set; }
    public List<TrackingEventDto> Events { get; set; } = new();
}

public sealed class RiderStopDto
{
    public int Id { get; set; }
    public string TrackingId { get; set; } = "";
    public string Status { get; set; } = "";
    public string PaymentMode { get; set; } = "";
    public decimal CodAmount { get; set; }
    public string ReceiverName { get; set; } = "";
    public string ReceiverPhone { get; set; } = "";
    public string ReceiverAddress { get; set; } = "";
    public string ReceiverPincode { get; set; } = "";
    public string? DestBranchName { get; set; }
    public decimal? AmountExpected { get; set; }
    public decimal? AmountCollected { get; set; }
    public bool? Deposited { get; set; }
}

public sealed class CodTransactionDto
{
    public int Id { get; set; }
    public int ShipmentId { get; set; }
    public int? RiderId { get; set; }
    public decimal AmountExpected { get; set; }
    public decimal AmountCollected { get; set; }
    public bool Deposited { get; set; }
    public DateTime? CollectedAt { get; set; }
    public DateTime? DepositedAt { get; set; }
}

public sealed class CodReconRiderDto
{
    public int RiderId { get; set; }
    public string RiderName { get; set; } = "";
    public int? BranchId { get; set; }
    public int CodShipments { get; set; }
    public decimal TotalExpected { get; set; }
    public decimal TotalCollected { get; set; }
    public decimal TotalDeposited { get; set; }
    public decimal Outstanding { get; set; }
}

public sealed class CodReconBranchDto
{
    public int BranchId { get; set; }
    public string BranchCode { get; set; } = "";
    public string BranchName { get; set; } = "";
    public int CodShipments { get; set; }
    public decimal TotalExpected { get; set; }
    public decimal TotalCollected { get; set; }
    public decimal TotalDeposited { get; set; }
    public decimal Outstanding { get; set; }
}

public sealed class DashboardDto
{
    public int BookingsToday { get; set; }
    public int DeliveriesToday { get; set; }
    public int PendingShipments { get; set; }
    public decimal CodCollectedToday { get; set; }
}
