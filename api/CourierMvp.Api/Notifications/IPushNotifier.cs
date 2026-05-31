namespace CourierMvp.Api.Notifications;

/// <summary>
/// Push to a rider's device, targeted by OneSignal external user id (== Users.Id).
/// Implementations MUST be best-effort: never throw, never block the core write.
/// </summary>
public interface IPushNotifier
{
    Task SendToUserAsync(int userId, string title, string message,
        IReadOnlyDictionary<string, string>? data = null, CancellationToken ct = default);
}
