pub mod cli;
pub mod config;
mod devenv;
pub mod log;
pub mod mcp;
pub(crate) mod nix;
pub mod nix_backend;

#[cfg(feature = "snix")]
pub(crate) mod snix_backend;
mod util;

pub use cli::{default_system, GlobalOptions};
pub use devenv::{Devenv, DevenvOptions, ProcessOptions, DIRENVRC, DIRENVRC_VERSION};
pub use devenv_tasks as tasks;
