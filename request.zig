/// Writes a JSON-escaped string without surrounding quotes.
pub fn writeJsonEscaped(writer: anytype, value: []const u8) !void {
    for (value) |c| {
        switch (c) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            else => {
                if (c < 0x20) {
                    const hex = "0123456789abcdef";
                    try writer.writeAll("\\u00");
                    try writer.writeByte(hex[c >> 4]);
                    try writer.writeByte(hex[c & 0x0f]);
                } else {
                    try writer.writeByte(c);
                }
            },
        }
    }
}
