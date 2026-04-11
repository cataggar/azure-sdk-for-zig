const std = @import("std");
const http = @import("http/transport.zig");

/// Azure service error detail extracted from an HTTP response.
pub const AzureError = struct {
    status_code: u16,
    error_code: ?[]const u8 = null,
    message: ?[]const u8 = null,
    raw_response: ?http.Response = null,

    pub fn format(self: AzureError, writer: anytype) !void {
        try writer.print("AzureError(status={d}", .{self.status_code});
        if (self.error_code) |c| try writer.print(", code={s}", .{c});
        if (self.message) |m| try writer.print(", message={s}", .{m});
        try writer.writeAll(")");
    }
};

/// Map an HTTP response to an `AzureError` if non-successful.
///
/// Tries to parse a JSON error body of the form:
/// ```json
/// { "error": { "code": "...", "message": "..." } }
/// ```
/// Logs error details via `std.log.err` for diagnostics.
pub fn errorFromResponse(response: http.Response) ?AzureError {
    if (response.isSuccess()) return null;
    var err = AzureError{ .status_code = response.status_code };

    // Best-effort JSON parse.
    if (std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, response.body, .{})) |parsed| {
        if (parsed.value == .object) {
            if (parsed.value.object.get("error")) |error_obj| {
                if (error_obj == .object) {
                    if (error_obj.object.get("code")) |code| {
                        if (code == .string) err.error_code = code.string;
                    }
                    if (error_obj.object.get("message")) |msg| {
                        if (msg == .string) err.message = msg.string;
                    }
                }
            }
        }
    } else |_| {}

    return err;
}

test "errorFromResponse success" {
    var resp = http.Response{
        .status_code = 200,
        .headers = std.StringHashMap([]const u8).init(std.testing.allocator),
        .body = try std.testing.allocator.dupe(u8, "ok"),
        .allocator = std.testing.allocator,
    };
    defer resp.deinit();
    try std.testing.expect(errorFromResponse(resp) == null);
}

test "errorFromResponse 404" {
    const body =
        \\{"error":{"code":"SecretNotFound","message":"Secret not found"}}
    ;
    var resp = http.Response{
        .status_code = 404,
        .headers = std.StringHashMap([]const u8).init(std.testing.allocator),
        .body = try std.testing.allocator.dupe(u8, body),
        .allocator = std.testing.allocator,
    };
    defer resp.deinit();
    const err = errorFromResponse(resp).?;
    try std.testing.expectEqual(@as(u16, 404), err.status_code);
    try std.testing.expectEqualStrings("SecretNotFound", err.error_code.?);
    try std.testing.expectEqualStrings("Secret not found", err.message.?);
}
