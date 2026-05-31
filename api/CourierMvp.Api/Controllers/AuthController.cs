using CourierMvp.Api.Models.Requests;
using CourierMvp.Api.Models.Responses;
using CourierMvp.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CourierMvp.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public sealed class AuthController : ControllerBase
{
    private readonly IAuthService _auth;
    private readonly IWebHostEnvironment _env;

    public AuthController(IAuthService auth, IWebHostEnvironment env)
    {
        _auth = auth;
        _env = env;
    }

    [AllowAnonymous]
    [HttpPost("login")]
    public async Task<ActionResult<LoginResponse>> Login(LoginRequest req, CancellationToken ct)
        => Ok(await _auth.LoginAsync(req, ct));

    /// <summary>
    /// DEV-ONLY helper to generate a PasswordHash for seeding. Disabled outside Development.
    /// </summary>
    [AllowAnonymous]
    [HttpGet("dev-hash")]
    public ActionResult<object> DevHash([FromQuery] string password)
    {
        if (!_env.IsDevelopment()) return NotFound();
        return Ok(new { password, hash = _auth.HashPassword(password) });
    }
}
