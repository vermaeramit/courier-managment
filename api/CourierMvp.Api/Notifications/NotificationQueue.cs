using System.Threading.Channels;

namespace CourierMvp.Api.Notifications;

/// <summary>
/// A push job: enqueued by services, drained by the background worker. Decouples the
/// core write path from notification I/O so a slow/failing provider never blocks a write.
/// </summary>
public sealed record PushJob(
    int UserId, string Title, string Message, IReadOnlyDictionary<string, string>? Data);

public interface INotificationQueue
{
    /// <summary>Non-blocking enqueue. Never throws into the caller.</summary>
    void Enqueue(PushJob job);
    IAsyncEnumerable<PushJob> DequeueAllAsync(CancellationToken ct);
}

public sealed class ChannelNotificationQueue : INotificationQueue
{
    private readonly Channel<PushJob> _channel =
        Channel.CreateUnbounded<PushJob>(new UnboundedChannelOptions { SingleReader = true });

    private readonly ILogger<ChannelNotificationQueue> _log;
    public ChannelNotificationQueue(ILogger<ChannelNotificationQueue> log) => _log = log;

    public void Enqueue(PushJob job)
    {
        if (!_channel.Writer.TryWrite(job))
            _log.LogWarning("Notification queue rejected a job for user {UserId}.", job.UserId);
    }

    public IAsyncEnumerable<PushJob> DequeueAllAsync(CancellationToken ct)
        => _channel.Reader.ReadAllAsync(ct);
}

/// <summary>Hosted worker that drains the queue and sends each push best-effort.</summary>
public sealed class NotificationBackgroundService : BackgroundService
{
    private readonly INotificationQueue _queue;
    private readonly IPushNotifier _notifier;
    private readonly ILogger<NotificationBackgroundService> _log;

    public NotificationBackgroundService(
        INotificationQueue queue, IPushNotifier notifier, ILogger<NotificationBackgroundService> log)
    {
        _queue = queue;
        _notifier = notifier;
        _log = log;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _log.LogInformation("Notification background worker started.");
        try
        {
            await foreach (var job in _queue.DequeueAllAsync(stoppingToken))
            {
                await _notifier.SendToUserAsync(job.UserId, job.Title, job.Message, job.Data, stoppingToken);
            }
        }
        catch (OperationCanceledException) { /* shutting down */ }
        catch (Exception ex)
        {
            _log.LogError(ex, "Notification worker crashed.");
        }
    }
}
