# InterruptHandling.jl

This package makes provides a simple terminal menu interface for Ctrl-C
interrupt events, along with the ability to trigger handler tasks registered by
libraries. Libraries should call `InterruptHandling.register!` with their
top-level module and a handler task; during a Ctrl-C or SIGINT,
InterruptHandling.jl will provide a TerminalMenus-driven prompt to select which
library handlers to trigger, as well as other options like ignoring the
interrupt, exiting Julia, or disabling further interrupt handling by
InterruptHandling.jl.
