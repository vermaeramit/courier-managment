namespace CourierMvp.Api.Notifications;

/// <summary>
/// Customer-facing notifications (SMS / WhatsApp). Customers have no app, so this is
/// a SEPARATE channel from rider push.
///
/// >>> STUB ONLY <<<  This MVP deliberately does NOT integrate a real SMS/WhatsApp
/// provider. Wire a provider (e.g. Twilio, Gupshup, MSG91) behind this interface
/// later. The default implementation just logs.
/// </summary>
public interface ICustomerNotifier
{
    Task SendStatusUpdateAsync(string toPhone, string trackingId, string status,
        string? trackingUrl = null, CancellationToken ct = default);
}

public sealed class LoggingCustomerNotifier : ICustomerNotifier
{
    private readonly ILogger<LoggingCustomerNotifier> _log;
    public LoggingCustomerNotifier(ILogger<LoggingCustomerNotifier> log) => _log = log;

    public Task SendStatusUpdateAsync(string toPhone, string trackingId, string status,
        string? trackingUrl = null, CancellationToken ct = default)
    {
        // STUB: replace with a real SMS/WhatsApp call.
        _log.LogInformation(
            "[SMS STUB] To {Phone}: Shipment {TrackingId} is now {Status}. {Url}",
            toPhone, trackingId, status, trackingUrl ?? "");
        return Task.CompletedTask;
    }
}
