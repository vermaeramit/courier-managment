using System.Text.Json;
using Microsoft.Data.SqlClient;

namespace CourierMvp.Api.Common;

/// <summary>
/// Maps domain + proc errors to clean HTTP responses:
///   AppException / proc THROW (50000+) -> 400
///   UnauthorizedAccessException        -> 401
///   everything else                    -> 500 (logged)
/// </summary>
public sealed class ExceptionMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ExceptionMiddleware> _log;

    public ExceptionMiddleware(RequestDelegate next, ILogger<ExceptionMiddleware> log)
    {
        _next = next;
        _log = log;
    }

    public async Task InvokeAsync(HttpContext ctx)
    {
        try
        {
            await _next(ctx);
        }
        catch (AppException ex)
        {
            await WriteAsync(ctx, StatusCodes.Status400BadRequest, ex.Message);
        }
        catch (UnauthorizedAccessException ex)
        {
            await WriteAsync(ctx, StatusCodes.Status401Unauthorized, ex.Message);
        }
        catch (SqlException ex) when (ex.Number == 2627 || ex.Number == 2601)
        {
            // Unique-key / duplicate violation -> 409 Conflict (not a 500). The raw
            // SQL text is logged but not echoed to the client.
            _log.LogWarning(ex, "Unique constraint violation.");
            await WriteAsync(ctx, StatusCodes.Status409Conflict, "A record with the same unique value already exists.");
        }
        catch (SqlException ex) when (ex.Number >= 50000)
        {
            // Deliberate business-rule THROWs from stored procedures surface as clean 400s.
            await WriteAsync(ctx, StatusCodes.Status400BadRequest, ex.Message);
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "Unhandled exception.");
            await WriteAsync(ctx, StatusCodes.Status500InternalServerError, "An unexpected error occurred.");
        }
    }

    private static async Task WriteAsync(HttpContext ctx, int status, string message)
    {
        if (ctx.Response.HasStarted) return;
        ctx.Response.Clear();
        ctx.Response.StatusCode = status;
        ctx.Response.ContentType = "application/json";
        await ctx.Response.WriteAsync(JsonSerializer.Serialize(new { message }));
    }
}
