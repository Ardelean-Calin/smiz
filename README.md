### What is Smiz?

Smiz is a state machine library written in Zig. I am using it for embedded development, so the purpose of this library is to be as small as possible and to (ideally) not use an allocator.

It is still **WIP** but the basic functionality is there. You can use it to create a simple Finite State Machine with compile-time defined states and optional state transition events.
Transition event handlers are also supported.

### Example

A simple state machine without events and without a transition handler:

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

A simple state machine without events but **with** a transition handler:

```zig
const fsm = @import("smiz");

const State = enum { sleep, waiting, parsing };

/// Called whenever a transition from one state to another takes place
fn handler(from: State, to: State) {
    // Check states and do stuff
    if (from == .sleep and .to == .waiting){
        // ...
    }
}

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
    // Optional transition handler
    .handler = &handler,
}){};


try std.testing.expectEqual(sm.getState(), .sleep);
// This is how we step without an event
try sm.step();
try std.testing.expectEqual(sm.getState(), .waiting);
```

A FSM with an Event Type and an **optional** transition event handler.

```zig
const fsm = @import("smiz");

const State = enum { sleep, waiting, parsing };
const Event = enum { click };

fn myTransitionHandler(from: State, to: State, event: ?Event) {
    if (event.? == .click and from == .sleep) {
        // do something
    }
    else if (event == null and to == .sleep) {
        // do something else
    } 
    else {
        // you get the point
    }
}

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
    // Optional, can be omitted
    .handler = &myTransitionHandler,
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

As you can see the `Event` can simply be a `null` value in case of no event.
