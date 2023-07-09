//! A circular doubly linked list

const std = @import("std");

pub const Node = struct {
    prev: *Node = undefined,
    next: *Node = undefined,
};

pub fn insertNext(node: *Node, next: *Node) void {
    next.next = node.next;
    node.next.prev = next;
    node.next = next;
    next.prev = node;
}

pub fn insertPrev(node: *Node, prev: *Node) void {
    prev.prev = node.prev;
    node.prev.next = prev;
    node.prev = prev;
    prev.next = node;
}

pub fn isEmpty(node: *Node) bool {
    if (node.prev != node) return false;
    std.debug.assert(node.next == node);
    return true;
}

/// Head of a list.
///
/// This is allowed to make iterating over list easier and less verbose.
///
/// XXX Beware that you can't do `@fieldParentPtr` on a node.
pub fn Head(comptime T: type, comptime field_name: []const u8) type {
    return struct {
        const Self = @This();

        node: Node = undefined,

        pub fn init(self: *Self) void {
            self.node.next = &self.node;
            self.node.prev = &self.node;
        }

        pub fn iterator(self: *Self) Iterator {
            return .{
                .head = &self.node,
                .current = self.node.next,
            };
        }

        pub fn constIterator(self: *const Self) ConstIterator {
            return .{
                .head = &self.node,
                .current = self.node.next,
            };
        }

        pub const Iterator = struct {
            head: *Node,
            current: *Node,

            pub fn next(self: *Iterator) ?*T {
                if (self.current == self.head) return null;
                var n = self.current;
                self.current = self.current.next;
                return @fieldParentPtr(T, field_name, n);
            }
        };

        pub const ConstIterator = struct {
            head: *const Node,
            current: *const Node,

            pub fn next(self: *ConstIterator) ?*const T {
                if (self.current == self.head) return null;
                var n = self.current;
                self.current = self.current.next;
                return @fieldParentPtr(T, field_name, n);
            }
        };
    };
}
