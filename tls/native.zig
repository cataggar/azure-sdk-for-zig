const std = @import("std");
const symcrypt = @import("symcrypt");
const p = @import("httpx").crypto_provider;

// These operations exist in the already-pinned native library, but the 0.1.0
// Zig wrapper does not expose separate HKDF expansion or the TLS PRF.
pub const c = @cImport({
    if (@import("builtin").os.tag == .windows) {
        @cUndef("_MSC_VER");
        @cDefine("__GNUC__", "4");
    }
    @cDefine("SYMCRYPT_ZIG_IMPORT", "1");
    @cInclude("stddef.h");
    @cInclude("symcrypt.h");
});

comptime {
    if (c.SYMCRYPT_CODE_VERSION_API != symcrypt.header_version.api or
        c.SYMCRYPT_CODE_VERSION_MINOR != symcrypt.header_version.minor or
        c.SYMCRYPT_CODE_VERSION_PATCH != symcrypt.header_version.patch)
        @compileError("TLS binding requires the exact zig_symcrypt headers");
}

extern fn SymCryptZigHmacSha256Algorithm() c.PCSYMCRYPT_MAC;
extern fn SymCryptZigHmacSha384Algorithm() c.PCSYMCRYPT_MAC;
extern fn SymCryptZigHmacSha512Algorithm() c.PCSYMCRYPT_MAC;

pub fn mac(algorithm: p.HashAlgorithm) p.ProviderError!c.PCSYMCRYPT_MAC {
    if (comptime @import("builtin").os.tag == .windows and symcrypt.linkage == .dynamic) {
        return switch (algorithm) {
            .sha1 => error.UnsupportedAlgorithm,
            .sha256 => SymCryptZigHmacSha256Algorithm(),
            .sha384 => SymCryptZigHmacSha384Algorithm(),
            .sha512 => SymCryptZigHmacSha512Algorithm(),
        };
    }
    return switch (algorithm) {
        .sha1 => error.UnsupportedAlgorithm,
        .sha256 => c.SymCryptHmacSha256Algorithm,
        .sha384 => c.SymCryptHmacSha384Algorithm,
        .sha512 => c.SymCryptHmacSha512Algorithm,
    };
}

pub fn check(code: c.SYMCRYPT_ERROR) p.ProviderError!void {
    symcrypt.checkCode(@bitCast(code)) catch |err| return mapError(err);
}

pub fn mapError(err: (symcrypt.Error || std.mem.Allocator.Error)) p.ProviderError {
    return switch (err) {
        error.OutOfMemory, error.MemoryAllocationFailure => error.OutOfMemory,
        error.AuthenticationFailure => error.AuthenticationFailed,
        error.SignatureVerificationFailure, error.InvalidSignature => error.SignatureInvalid,
        error.NotImplemented => error.UnsupportedAlgorithm,
        error.WrongKeySize => error.InvalidKeyLength,
        error.WrongNonceSize => error.InvalidNonceLength,
        error.WrongTagSize => error.InvalidTagLength,
        error.BufferTooSmall => error.OutputTooSmall,
        error.OverlappingBuffers => error.InvalidOverlap,
        error.InvalidEncoding, error.InvalidBlob, error.IncompatibleFormat => error.InvalidEncoding,
        error.InvalidState => error.InvalidHandle,
        error.WrongBlockSize,
        error.WrongDataSize,
        error.WrongIterationCount,
        error.InvalidArgument,
        error.ValueTooLarge,
        error.InvalidUsage,
        error.InvalidLength,
        error.KeyMismatch,
        error.MessageTooLong,
        => error.InvalidInput,
        error.IncompatibleSymCryptVersion,
        error.SymCryptInitializationFailed,
        error.Unused,
        error.ExternalFailure,
        error.FipsFailure,
        error.HardwareFailure,
        error.SessionReplayFailure,
        error.HbsNoOtsKeysLeft,
        error.HbsPublicRootMismatch,
        error.UnknownSymCryptError,
        => error.InternalError,
    };
}
