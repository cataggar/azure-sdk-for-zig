//! Stable pipeline state and constructor plumbing.
//!
//! Owning clients will allocate pipeline state at a stable address. Derived
//! clients borrow that state and may not outlive the owning service client.
