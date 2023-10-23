### What is Smiz?

Smiz is a state machine library written in Zig. I am using it for embedded development, so the purpose of this library is to be as small as possible and to (ideally) not use an allocator.

It is still **WIP** but the basic functionality is there. You can use it to create a simple Finite State Machine with compile-time defined states and optional state transition events.
Transition event handlers are also supported.

### Example

The simplest FSM has no events and no transition handler:

```zig
const fsm = @import("smiz");

const State = enum { sleep, waiting, parsing };

var sm = fsm.StateMachine(.{
    // Necessary type declarations
    .state_type = State,
    .initial_state = .sleep,
    // Transition table
    .transitions = &.{
        .{ .from =   .sleep, .to = .waiting },
        .{ .from = .waiting, .to = .parsing },
        .{ .from = .parsing, .to =   .sleep },
    },
}){};


try std.testing.expectEqual(sm.getState(), .sleep);
// This is how we step without an event
try sm.step();
try std.testing.expectEqual(sm.getState(), .waiting);
```

A more complicated FSM also has an Event Type and *optionally* a transition event handler to do stuff on transition.

```zig
const fsm = @import("smiz");

const State = enum { sleep, waiting, parsing };
const Event = enum { click };

var sm = fsm.StateMachine(.{
    // Necessary type declarations
    .state_type = State,
    .event_type = Event,
    .initial_state = .sleep,
    // Transition table
    .transitions = &.{
        .{ .event = .click, .from =   .sleep, .to = .waiting },
        .{ .event = .click, .from = .waiting, .to = .parsing },
        .{ .event =   null, .from = .parsing, .to =   .sleep },
    },
}){};


try std.testing.expectEqual(sm.getState(), .sleep);
// This is how we step with an event
try sm.stepWithEvent(.click);
try std.testing.expectEqual(sm.getState(), .waiting);
try sm.stepWithEvent(.click);
try std.testing.expectEqual(sm.getState(), .parsing);
try sm.stepWithEvent(.click); // ! ERROR
try sm.stepWithEvent(null); // Correct! Alternatively you can simply .step()
try std.testing.expectEqual(sm.getState(), .sleep);
```
