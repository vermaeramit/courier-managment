using CourierMvp.Api.Auth;
using CourierMvp.Api.Models.Responses;
using CourierMvp.Api.Repositories;

namespace CourierMvp.Api.Services;

public interface IDashboardService
{
    Task<DashboardDto> DailyCountsAsync(CurrentUser caller, DateTime? forDate, CancellationToken ct);
}

public sealed class DashboardService : IDashboardService
{
    private readonly IDashboardRepository _repo;
    public DashboardService(IDashboardRepository repo) => _repo = repo;

    public Task<DashboardDto> DailyCountsAsync(CurrentUser caller, DateTime? forDate, CancellationToken ct)
        // Admin -> HQ rollup (null scope). Manager -> own branch only.
        => _repo.DailyCountsAsync(caller.ScopeBranchId, forDate, ct);
}
