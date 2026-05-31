using System.ComponentModel.DataAnnotations;

namespace CourierMvp.Api.Models.Requests;

// Request DTOs. Property names match stored-proc @parameters (minus @) so Dapper
// maps them automatically when passed straight through with CommandType.StoredProcedure.
// Note: properties the *caller* must not set (e.g. CreatedBy, scope ids) are added by
// the service layer from the authenticated principal, not bound from the request body.
//
// DataAnnotations are validated automatically by [ApiController] before the action
// runs (a violation returns 400 ValidationProblemDetails), so invalid input never
// reaches the service/proc layer.

public sealed record LoginRequest(
    [Required, EmailAddress, StringLength(150)] string Email,
    [Required, StringLength(200, MinimumLength = 1)] string Password);

public sealed record CreateUserRequest(
    int? BranchId,
    [Required, StringLength(150)] string Name,
    [Required, RegularExpression("^(Admin|BranchManager|Rider)$")] string Role,
    [Phone, StringLength(20)] string? Phone,
    [Required, EmailAddress, StringLength(150)] string Email,
    [Required, StringLength(200, MinimumLength = 6)] string Password,  // plaintext in; service hashes
    [RegularExpression("^(Active|Inactive)$")] string Status = "Active");

public sealed record UpdateUserRequest(
    [Range(1, int.MaxValue)] int Id,
    int? BranchId,
    [Required, StringLength(150)] string Name,
    [Required, RegularExpression("^(Admin|BranchManager|Rider)$")] string Role,
    [Phone, StringLength(20)] string? Phone,
    [Required, RegularExpression("^(Active|Inactive)$")] string Status);

public sealed record CreateBranchRequest(
    [Required, StringLength(10)] string Code,
    [Required, StringLength(150)] string Name,
    [Required, StringLength(100)] string City,
    [Required, RegularExpression(@"^\d{6}$", ErrorMessage = "Pincode must be 6 digits.")] string Pincode,
    int? ManagerId,
    bool IsActive = true);

public sealed record UpdateBranchRequest(
    [Range(1, int.MaxValue)] int Id,
    [Required, StringLength(150)] string Name,
    [Required, StringLength(100)] string City,
    [Required, RegularExpression(@"^\d{6}$", ErrorMessage = "Pincode must be 6 digits.")] string Pincode,
    int? ManagerId,
    bool IsActive);

public sealed record CreateShipmentRequest(
    [Range(1, int.MaxValue)] int OriginBranchId,
    [Range(1, int.MaxValue)] int DestBranchId,
    [Required, StringLength(150)] string SenderName,
    [Required, Phone, StringLength(20)] string SenderPhone,
    [Required, StringLength(400)] string SenderAddress,
    [Required, RegularExpression(@"^\d{6}$", ErrorMessage = "Pincode must be 6 digits.")] string SenderPincode,
    [Required, StringLength(150)] string ReceiverName,
    [Required, Phone, StringLength(20)] string ReceiverPhone,
    [Required, StringLength(400)] string ReceiverAddress,
    [Required, RegularExpression(@"^\d{6}$", ErrorMessage = "Pincode must be 6 digits.")] string ReceiverPincode,
    [Range(0, 100000)] decimal Weight,
    [Required, RegularExpression("^(Standard|Express|SameDay)$")] string ServiceType,
    [Required, RegularExpression("^(Prepaid|COD)$")] string PaymentMode,
    [Range(0, 1000000)] decimal CodAmount = 0m);

public sealed record UpdateStatusRequest(
    int ShipmentId,        // bound from the route, not the body
    [Required, RegularExpression(
        "^(Booked|PickedUp|AtOriginHub|InTransit|AtDestinationHub|OutForDelivery|Delivered|Failed|RTO)$")] string Status,
    int? BranchId,
    int? RiderId,
    [Range(-90.0, 90.0)] decimal? Latitude,
    [Range(-180.0, 180.0)] decimal? Longitude,
    [StringLength(500)] string? Remarks);

public sealed record HandoffRequest(
    int ShipmentId,        // bound from the route
    [Range(1, int.MaxValue)] int ToBranchId,
    [Required, RegularExpression(
        "^(Booked|PickedUp|AtOriginHub|InTransit|AtDestinationHub|OutForDelivery|Delivered|Failed|RTO)$")] string Status = "InTransit",
    [StringLength(500)] string? Remarks = null);

public sealed record AssignRiderRequest(
    int ShipmentId,        // bound from the route
    [Range(1, int.MaxValue)] int RiderId);

public sealed record PodSubmitRequest(
    int ShipmentId,        // bound from the route
    [Required, RegularExpression("^(Photo|OTP|Signature)$")] string Type,
    [StringLength(500)] string? PhotoUrl,
    [StringLength(10)] string? Otp,
    int RiderId,
    [Range(-90.0, 90.0)] decimal? Latitude,
    [Range(-180.0, 180.0)] decimal? Longitude,
    [Range(0, 1000000)] decimal? CodCollected,
    [StringLength(500)] string? Remarks);

public sealed record RecordCodRequest(
    [Range(1, int.MaxValue)] int ShipmentId,
    int RiderId,
    [Range(0, 1000000)] decimal AmountCollected);

public sealed record DateRangeRequest(DateTime FromDate, DateTime ToDate);
