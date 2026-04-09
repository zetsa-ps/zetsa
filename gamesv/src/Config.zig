recv_buffer_size: usize,
send_buffer_size: usize,
listen_address: []const u8,
default_characters: [3]?tables.hero.Id,

const tables = @import("tables.zig");
