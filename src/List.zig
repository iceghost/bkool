pub const Node = struct {
    prev: ?*Node = null,
    next: ?*Node = null,
};

pub fn iterator(node: *Node) Iterator {
    return .{ .cur = node };
}

pub const Iterator = struct {
    cur: ?*Node,

    pub fn next(self: *Iterator) ?*Node {
        const cur = self.cur orelse return null;
        self.cur = cur.next;
        return cur;
    }
};

pub fn insertNext(node: *Node, next: *Node) void {
    if (node.next) |old_next| {
        next.next = old_next;
        old_next.prev = next;
    } else {
        next.next = null;
    }
    node.next = next;
    next.prev = node;
}

pub fn insertPrev(node: *Node, prev: *Node) void {
    if (node.prev) |old_prev| {
        old_prev.next = prev;
        prev.prev = old_prev;
    } else {
        prev.prev = null;
    }
    node.prev = prev;
    prev.next = node;
}
