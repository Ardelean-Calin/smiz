const std = @import("std");
const testing = std.testing;

// The available State Machine errors
pub const StateMachineError = error{
    InvalidTransition,
};

pub fn StateMachine(comptime sm_skeleton: anytype) type {
    const T = @TypeOf(sm_skeleton);

    const StateType = @field(sm_skeleton, "state_type");
    const event_present = @hasField(T, "event_type");
    const EventType = if (event_present) ?@field(sm_skeleton, "event_type") else ?void;

    // By default, no transition shall have an event
    const TransitionType = struct {
        event: EventType = null,
        from: StateType,
        to: StateType,
    };

    // Optional fields
    // If I specify a handler, I will generate code that uses it on event transition
    const handler_present = @hasField(T, "handler");
    const handler_function = if (handler_present) @field(sm_skeleton, "handler") else null;

    // Transitions and initial_state are required fields.
    return struct {
        transitions: []const TransitionType = @field(sm_skeleton, "transitions"),
        internal: struct {
            current_state: StateType = @field(sm_skeleton, "initial_state"),
        } = .{},

        const Self = @This();
        pub fn getState(self: Self) StateType {
            return self.internal.current_state;
        }

        pub fn step(self: *Self) !void {
            try self.stepWithEvent(null);
        }

        pub fn stepWithEvent(self: *Self, event: EventType) !void {
            // Basically create two if cases for every transition:
            // One which checks that both state and event are ok
            // One which only checks the state
            inline for (@field(sm_skeleton, "transitions")) |transition| {
                if (transition.from == self.internal.current_state and event_present and transition.event == event) {
                    if (handler_present) {
                        @call(.auto, handler_function, .{ transition.from, transition.to, transition.event });
                    }

                    self.internal.current_state = transition.to;
                    return;
                }
                if (transition.from == self.internal.current_state and !event_present) {
                    if (handler_present) {
                        // Events are unused so we don't need our handler to have event parameter
                        @call(.auto, handler_function, .{ transition.from, transition.to });
                    }
                    self.internal.current_state = transition.to;
                    return;
                }
            }

            // If no transition could occur, we report an error.
            return StateMachineError.InvalidTransition;
        }
    };
}

const State = enum { sleep, waiting, parsing };
const Event = enum { click, pop };

test "Basic State Machine interface no Event" {
    // zig fmt: off
    var sm = StateMachine(.{
        // Necessary type declarations
        .state_type = State,
        .initial_state = .sleep,
        .transitions = &.{
            .{ .from =   .sleep, .to = .waiting },
            .{ .from = .waiting, .to = .parsing },
            .{ .from = .parsing, .to =   .sleep },
        },
    }){};
    // zig fmt: on

    try std.testing.expectEqual(sm.getState(), .sleep);

    try sm.step();
    try std.testing.expectEqual(sm.getState(), .waiting);

    try sm.step();
    try std.testing.expectEqual(sm.getState(), .parsing);

    try sm.step();
    try std.testing.expectEqual(sm.getState(), .sleep);
}

test "Basic State Machine interface no Event with Handler" {
    const Handler = struct {
        var count: u32 = 0;

        pub fn onTransition(from: State, to: State) void {
            _ = to;
            _ = from;
            count += 1;
        }
    };

    // zig fmt: off
    var sm = StateMachine(.{
        // Necessary type declarations
        .state_type = State,
        .initial_state = .sleep,
        .transitions = &.{
            .{ .from =   .sleep, .to = .waiting },
            .{ .from = .waiting, .to = .parsing },
            .{ .from = .parsing, .to =   .sleep },
        },
        // Optional transition handler
        .handler = &Handler.onTransition,
    }){};
    // zig fmt: on

    try std.testing.expectEqual(sm.getState(), .sleep);

    try sm.step();
    try std.testing.expectEqual(sm.getState(), .waiting);

    try sm.step();
    try std.testing.expectEqual(sm.getState(), .parsing);

    try sm.step();
    try std.testing.expectEqual(sm.getState(), .sleep);

    // Test that the event handler was called
    try std.testing.expectEqual(Handler.count, 3);
}

test "Basic State Machine interface with Event no handler" {
    // zig fmt: off
    var sm = StateMachine(.{
        // Necessary type declarations
        .state_type = State,
        .event_type = Event,
        .initial_state = .sleep,
        .transitions = &.{
            .{ .event = .click, .from =   .sleep, .to = .waiting },
            .{ .event =   .pop, .from = .waiting, .to = .parsing },
            .{ .event =   null, .from = .parsing, .to =   .sleep },
        },
    }){};
    // zig fmt: on

    try std.testing.expectEqual(sm.getState(), .sleep);

    // Expect that an invalid event will give an error.
    try std.testing.expectError(StateMachineError.InvalidTransition, sm.step());
    try std.testing.expectError(StateMachineError.InvalidTransition, sm.stepWithEvent(.pop));

    try sm.stepWithEvent(.click);
    try std.testing.expectEqual(sm.getState(), .waiting);

    try sm.stepWithEvent(.pop);
    try std.testing.expectEqual(sm.getState(), .parsing);

    try sm.step();
    try std.testing.expectEqual(sm.getState(), .sleep);
}

test "Basic State Machine interface with Event and handler" {
    const Handler = struct {
        var click_event: usize = 0;
        var pop_event: usize = 0;
        var no_event: usize = 0;

        const TransitionType = struct { from: State, to: State, event: ?Event };
        var transitions = std.ArrayList(TransitionType).init(std.testing.allocator);

        /// Simple transition handler which counts all events!
        pub fn onTransition(from: State, to: State, event: ?Event) void {
            transitions.append(.{ .from = from, .to = to, .event = event }) catch unreachable;
            if (event) |e| {
                switch (e) {
                    .click => click_event += 1,
                    .pop => pop_event += 1,
                }
            } else {
                no_event += 1;
            }
        }
    };

    defer Handler.transitions.deinit();

    // zig fmt: off
    var sm = StateMachine(.{
        // Necessary type declarations
        .state_type = State,
        .event_type = Event,
        .initial_state = .sleep,
        .transitions = &.{
            .{ .event = .click, .from =   .sleep, .to = .waiting },
            .{ .event =   .pop, .from = .waiting, .to = .parsing },
            .{ .event =   null, .from = .parsing, .to =   .sleep },
        },
        .handler = &Handler.onTransition,
    }){};
    // zig fmt: on

    try std.testing.expectEqual(sm.getState(), .sleep);
    try std.testing.expectEqual(Handler.click_event, 0);
    try std.testing.expectEqual(Handler.pop_event, 0);
    try std.testing.expectEqual(Handler.no_event, 0);

    // Expect that an invalid event will give an error.
    try std.testing.expectError(StateMachineError.InvalidTransition, sm.step());
    try std.testing.expectError(StateMachineError.InvalidTransition, sm.stepWithEvent(.pop));

    try sm.stepWithEvent(.click);
    try std.testing.expectEqual(sm.getState(), .waiting);

    try sm.stepWithEvent(.pop);
    try std.testing.expectEqual(sm.getState(), .parsing);

    try sm.step();
    try std.testing.expectEqual(sm.getState(), .sleep);

    try std.testing.expectEqual(Handler.click_event, 1);
    try std.testing.expectEqual(Handler.pop_event, 1);
    try std.testing.expectEqual(Handler.no_event, 1);

    // Check that all transitions got reported via the event handlers.
    try std.testing.expectEqualSlices(Handler.TransitionType, &.{
        .{ .event = .click, .from = .sleep, .to = .waiting },
        .{ .event = .pop, .from = .waiting, .to = .parsing },
        .{ .event = null, .from = .parsing, .to = .sleep },
    }, Handler.transitions.items);
}

test "more complicated state machine" {
    const State2 = enum {
        Measuring,
        Sleeping,
    };
    const Event2 = enum {
        MeasTemp,
        MeasMoisture,
        MeasBoth,
        TimerExpired,
    };

    const Handler = struct {
        var timer_expired: usize = 0;
        /// Simple transition handler which counts all events!
        pub fn onTransition(from: State2, to: State2, event: ?Event2) void {
            _ = to;
            _ = from;
            if (event.? == .TimerExpired) {
                timer_expired += 1;
            }
        }
    };

    // zig fmt: off
    var sm2 = StateMachine(
        .{
            .state_type = State2,
            .event_type = Event2,
            .initial_state = .Sleeping,
            .transitions = &.{
                .{ .event = .MeasTemp,     .from = .Sleeping,  .to = .Measuring },
                .{ .event = .MeasMoisture, .from = .Sleeping,  .to = .Measuring },
                .{ .event = .MeasBoth,     .from = .Sleeping,  .to = .Measuring },
                .{ .event = .TimerExpired, .from = .Measuring, .to = .Sleeping },
            },
            .handler = &Handler.onTransition,
        },
    ){};
    // zig fmt: on
    try std.testing.expectEqual(sm2.getState(), .Sleeping);
    try std.testing.expectEqual(Handler.timer_expired, 0);

    try sm2.stepWithEvent(.MeasTemp);
    try std.testing.expectEqual(sm2.getState(), .Measuring);
    try sm2.stepWithEvent(.TimerExpired);
    try std.testing.expectEqual(sm2.getState(), .Sleeping);

    try sm2.stepWithEvent(.MeasMoisture);
    try std.testing.expectEqual(sm2.getState(), .Measuring);
    try sm2.stepWithEvent(.TimerExpired);
    try std.testing.expectEqual(sm2.getState(), .Sleeping);

    try sm2.stepWithEvent(.MeasBoth);
    try std.testing.expectEqual(sm2.getState(), .Measuring);
    try sm2.stepWithEvent(.TimerExpired);
    try std.testing.expectEqual(sm2.getState(), .Sleeping);
    try std.testing.expectEqual(Handler.timer_expired, 3);
}
