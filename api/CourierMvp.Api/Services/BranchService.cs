using CourierMvp.Api.Common;
using CourierMvp.Api.Models.Requests;
using CourierMvp.Api.Models.Responses;
using CourierMvp.Api.Repositories;

namespace CourierMvp.Api.Services;

public interface IBranchService
{
    Task<IReadOnlyList<BranchDto>> ListAsync(bool onlyActive, CancellationToken ct);
    Task<BranchDto> CreateAsync(CreateBranchRequest req, CancellationToken ct);
    Task<BranchDto> UpdateAsync(UpdateBranchRequest req, CancellationToken ct);
    Task<ServiceabilityDto?> CheckServiceableAsync(string pincode, CancellationToken ct);
}

public sealed class BranchService : IBranchService
{
    private readonly IBranchRepository _repo;
    public BranchService(IBranchRepository repo) => _repo = repo;

    public Task<IReadOnlyList<BranchDto>> ListAsync(bool onlyActive, CancellationToken ct)
        => _repo.ListAsync(onlyActive, ct);

    public async Task<BranchDto> CreateAsync(CreateBranchRequest req, CancellationToken ct)
        => await _repo.CreateAsync(req, ct) ?? throw new AppException("Failed to create branch.");

    public async Task<BranchDto> UpdateAsync(UpdateBranchRequest req, CancellationToken ct)
        => await _repo.UpdateAsync(req, ct) ?? throw new AppException("Branch not found.");

    public Task<ServiceabilityDto?> CheckServiceableAsync(string pincode, CancellationToken ct)
        => _repo.CheckServiceableAsync(pincode, ct);
}
