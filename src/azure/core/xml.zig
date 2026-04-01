///! XML parsing utilities for Azure SDK, powered by zig-xml.
///!
///! Replaces libxml2 for parsing Azure Storage and other service XML responses.
///! Provides a simple pull-parser wrapper for extracting element text content.

const std = @import("std");
const xml = @import("xml");

/// Parse an XML document and extract text content of elements matching `tag_name`.
///
/// Returns all occurrences as an allocated slice of allocated strings.
/// Caller owns all memory.
pub fn findAllText(allocator: std.mem.Allocator, doc: []const u8, tag_name: []const u8) ![][]const u8 {
    var results: std.ArrayList([]const u8) = .empty;
    errdefer {
        for (results.items) |s| allocator.free(s);
        results.deinit(allocator);
    }

    var reader: xml.Reader.Static = .init(allocator, doc, .{});
    defer reader.deinit();
    const r = &reader.interface;

    var inside_target = false;
    while (true) {
        const node = r.read() catch break;
        switch (node) {
            .element_start => {
                const name = r.elementName();
                inside_target = std.mem.eql(u8, name, tag_name);
            },
            .element_end => {
                inside_target = false;
            },
            .text => {
                if (inside_target) {
                    const text = try allocator.dupe(u8, r.textRaw());
                    try results.append(allocator, text);
                }
            },
            .eof => break,
            else => {},
        }
    }

    return results.toOwnedSlice(allocator);
}

/// Parse an XML document and extract the text of the first element matching `tag_name`.
/// Returns null if not found.
pub fn findFirstText(allocator: std.mem.Allocator, doc: []const u8, tag_name: []const u8) !?[]const u8 {
    var reader: xml.Reader.Static = .init(allocator, doc, .{});
    defer reader.deinit();
    const r = &reader.interface;

    var inside_target = false;
    while (true) {
        const node = r.read() catch break;
        switch (node) {
            .element_start => {
                const name = r.elementName();
                inside_target = std.mem.eql(u8, name, tag_name);
            },
            .element_end => {
                inside_target = false;
            },
            .text => {
                if (inside_target) {
                    return try allocator.dupe(u8, r.textRaw());
                }
            },
            .eof => break,
            else => {},
        }
    }

    return null;
}

// ─────────────── Tests ───────────────

test "findAllText extracts blob names" {
    const allocator = std.testing.allocator;
    const doc =
        \\<?xml version="1.0" encoding="utf-8"?>
        \\<EnumerationResults>
        \\  <Blobs>
        \\    <Blob><Name>file1.txt</Name><Properties><Content-Length>100</Content-Length></Properties></Blob>
        \\    <Blob><Name>file2.txt</Name><Properties><Content-Length>200</Content-Length></Properties></Blob>
        \\    <Blob><Name>dir/file3.txt</Name></Blob>
        \\  </Blobs>
        \\</EnumerationResults>
    ;

    const names = try findAllText(allocator, doc, "Name");
    defer {
        for (names) |n| allocator.free(n);
        allocator.free(names);
    }

    try std.testing.expectEqual(@as(usize, 3), names.len);
    try std.testing.expectEqualStrings("file1.txt", names[0]);
    try std.testing.expectEqualStrings("file2.txt", names[1]);
    try std.testing.expectEqualStrings("dir/file3.txt", names[2]);
}

test "findFirstText" {
    const allocator = std.testing.allocator;
    const doc =
        \\<Error><Code>BlobNotFound</Code><Message>The blob does not exist.</Message></Error>
    ;

    const code = try findFirstText(allocator, doc, "Code");
    defer if (code) |c| allocator.free(c);
    try std.testing.expectEqualStrings("BlobNotFound", code.?);

    const msg = try findFirstText(allocator, doc, "Message");
    defer if (msg) |m| allocator.free(m);
    try std.testing.expectEqualStrings("The blob does not exist.", msg.?);
}

test "findFirstText returns null when not found" {
    const allocator = std.testing.allocator;
    const doc = "<Root><Other>value</Other></Root>";
    const result = try findFirstText(allocator, doc, "Missing");
    try std.testing.expect(result == null);
}

test "findAllText with Content-Length" {
    const allocator = std.testing.allocator;
    const doc =
        \\<EnumerationResults>
        \\  <Blobs>
        \\    <Blob><Properties><Content-Length>100</Content-Length></Properties></Blob>
        \\    <Blob><Properties><Content-Length>200</Content-Length></Properties></Blob>
        \\  </Blobs>
        \\</EnumerationResults>
    ;

    const lengths = try findAllText(allocator, doc, "Content-Length");
    defer {
        for (lengths) |l| allocator.free(l);
        allocator.free(lengths);
    }

    try std.testing.expectEqual(@as(usize, 2), lengths.len);
    try std.testing.expectEqualStrings("100", lengths[0]);
    try std.testing.expectEqualStrings("200", lengths[1]);
}
