using CourierMvp.Api.Auth;
using CourierMvp.Api.Models.Requests;
using CourierMvp.Api.Models.Responses;
using CourierMvp.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CourierMvp.Api.Controllers;

[Route("api/[controller]")]
[Authorize(Roles = $"{Roles.Admin},{Roles.BranchManager}")]
public sealed class UsersController : ApiControllerBase
{
    private readonly IUserService _service;
    public UsersController(IUserService service) => _service = service;

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<UserDto>>> List([FromQuery] string? role, CancellationToken ct)
        => Ok(await _service.ListAsync(CurrentUser, role, ct));

    [HttpPost]
    public async Task<ActionResult<UserDto>> Create(CreateUserRequest req, CancellationToken ct)
        => Ok(await _service.CreateAsync(CurrentUser, req, ct));

    [HttpPut("{id:int}")]
    public async Task<ActionResult<UserDto>> Update(int id, UpdateUserRequest req, CancellationToken ct)
        => Ok(await _service.UpdateAsync(CurrentUser, req with { Id = id }, ct));
}
