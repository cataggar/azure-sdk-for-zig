const binding = @import("binding");

// Taking the complete vtable forces every callback and native ABI through
// semantic analysis, even when compiling without linked native libraries.
export fn symcryptTlsHeaderCheck(owner: *binding.Provider) binding.contract.CryptoProvider {
    return owner.provider();
}
