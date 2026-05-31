using System.Text;
using System.Text.Json;

namespace CourierMvp.Api.Notifications;

/// <summary>
/// OneSignal REST implementation. Targets the rider by external_user_id (Users.Id).
/// Any failure is caught and logged — a push problem never breaks a status update.
/// </summary>
public sealed class OneSignalPushNotifier : IPushNotifier
{
    private readonly HttpClient _http;
    private readonly ILogger<OneSignalPushNotifier> _log;
    private readonly string? _appId;
    private readonly string? _apiKey;

    public OneSignalPushNotifier(HttpClient http, IConfiguration config, ILogger<OneSignalPushNotifier> log)
    {
        _http = http;
        _log = log;
        var section = config.GetSection("OneSignal");
        _appId = section["AppId"];
        _apiKey = section["ApiKey"];
    }

    public async Task SendToUserAsync(int userId, string title, string message,
        IReadOnlyDictionary<string, string>? data = null, CancellationToken ct = default)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(_appId) || string.IsNullOrWhiteSpace(_apiKey))
            {
                _log.LogInformation("OneSignal not configured; skipping push to user {UserId}: {Title}", userId, title);
                return;
            }

            var payload = new
            {
                app_id = _appId,
                include_external_user_ids = new[] { userId.ToString() },
                channel_for_external_user_ids = "push",
                headings = new { en = title },
                contents = new { en = message },
                data = data ?? new Dictionary<string, string>()
            };

            using var req = new HttpRequestMessage(HttpMethod.Post, "https://api.onesignal.com/notifications");
            req.Headers.TryAddWithoutValidation("Authorization", $"Basic {_apiKey}");
            req.Content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json");

            var resp = await _http.SendAsync(req, ct);
            if (!resp.IsSuccessStatusCode)
            {
                var body = await resp.Content.ReadAsStringAsync(ct);
                _log.LogWarning("OneSignal push to user {UserId} failed: {Status} {Body}",
                    userId, (int)resp.StatusCode, body);
            }
        }
        catch (Exception ex)
        {
            // Best-effort: swallow & log. Never rethrow into the calling write path.
            _log.LogError(ex, "OneSignal push to user {UserId} threw.", userId);
        }
    }
}
