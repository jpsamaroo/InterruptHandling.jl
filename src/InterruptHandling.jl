module InterruptHandling

import REPL: TerminalMenus

const ROOT_MENU = TerminalMenus.RadioMenu(
    [
     "Interrupt all",
     "Interrupt only...",
     "Ignore it",
     "Stop handling interrupts",
     "Exit Julia",
     "Force-exit Julia",
    ]
)

const HANDLERS_LOCK = Threads.ReentrantLock()
const HANDLERS = Dict{Module,Vector{Task}}()

function register!(mod::Module, handler::Task)
    lock(HANDLERS_LOCK) do
        handlers = get!(Vector{Task}, HANDLERS, mod)
        push!(handlers, handler)
    end
end

function root_handler()
    while true
        try
            # Wait to be interrupted
            wait()
        catch err
            if !(err isa InterruptException)
                rethrow(err)
            end

            if length(lock(()->length(HANDLERS), HANDLERS_LOCK)) == 0
                println("No interrupt handlers were registered, ignoring interrupt...")
                continue
            end

            # Display root menu
            @label display_root
            choice = TerminalMenus.request("Interrupt received, select an action:", ROOT_MENU)
            if choice == 1
                lock(HANDLERS_LOCK) do
                    for mod in keys(HANDLERS)
                        for handler in HANDLERS[mod]
                            if handler.state == :runnable
                                schedule(handler)
                            end
                        end
                    end
                end
            elseif choice == 2
                # Display modules menu
                mods = lock(HANDLERS_LOCK) do
                    collect(keys(HANDLERS))
                end
                length(mods) > 0 || continue
                mod_menu = TerminalMenus.RadioMenu(vcat(map(mod->"Interrupt $mod", HANDLERS), "Go Back"))
                @label display_mods
                choice = TerminalMenus.request("Select a library to interrupt:", mod_menu)
                if choice > length(mods) || choice == -1
                    @goto display_root
                else
                    for handler in HANDLERS[mods[choice]]
                        if handler.state == :runnable
                            schedule(handler)
                        end
                    end
                    @goto display_mods
                end
            elseif choice == 3 || choice == -1
                # Do nothing
            elseif choice == 4
                # Exit handler (caller will unregister us)
                return
            elseif choice == 5
                # Exit Julia cleanly
                exit()
            elseif choice == 6
                # Force an exit
                ccall(:abort, Cvoid, ())
            end
        end
    end
end
function root_handler_checked()
    try
        root_handler()
    catch err
        # Some internal error, make sure we start a new handler
        Base.unregister_interrupt_handler(current_task())
        start_root_handler()
        rethrow()
    end
    # Clean exit
    Base.unregister_interrupt_handler(current_task())
end
function start_root_handler()
    root_handler_task = errormonitor(Threads.@spawn root_handler_checked())
    Base.register_interrupt_handler(root_handler_task)
end

function __init__()
    if !isdefined(Base, :register_interrupt_handler)
        return
    end
    if ccall(:jl_generating_output, Cint, ()) == 0
        # Setup root interrupt handler
        start_root_handler()
    end
end

end # module InterruptHandling
