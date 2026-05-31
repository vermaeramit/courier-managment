namespace CourierMvp.Api.Common;

/// <summary>
/// Domain-level error surfaced to clients as a 400 with a clean message.
/// Used for business-rule violations raised either in services or from a proc THROW.
/// </summary>
public sealed class AppException : Exception
{
    public AppException(string message) : base(message) { }
}
