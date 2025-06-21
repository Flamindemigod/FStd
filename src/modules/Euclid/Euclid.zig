//The goal for this module is to make a basic DB to replace my usecase of sqllite.
//I want to have it in pure zig
const std = @import("std");
//Opening Block-------
//Magic Alignment   u16
//Version Alignment u16
//Table Count       u32
//Entry Count       u32
//Transaction Count u32
//--------------
//Transaction Block Header[] (Packed Struct) -|
//Transaction Magic u8                        |
//Transaction Type                            |
//  (Create  = 0b0000                         |
//  |Update  = 0b0001                         |
//  |Delete  = 0b0010                         |
//  |else    => reserved) u4                  |
//Transaction Mode                            |
//  (Table   = 0b0000                         |
//  |Entry   = 0b0001                         |
//  |else    => reserved) u4                  |
//Data Size (in Bytes) u16                    |
//Transaction ID u32                          |
//Transaction Time i64                       -|
//Data []{Key, Val}
//-------------

//The idea basically is that the db is a massive transaction log
//And periodically the transactions get condensed



pub const DB = struct {
    const Header = packed struct {
        magic: u16 = CONSTS.Magics.DB,
        version: u16 = CONSTS.Version,
        tableCount: u32 = 0,
        entryCount: u32 = 0,
        transactionCount: u32 = 0,
        fn validate(self: *const Header) !void {
            if (self.magic != CONSTS.Magics.DB) return error.InvalidMagic;
        }
    };

    const TransactionHeader = packed struct {
        const TType = enum(u8) {
            Create = 0b00000001,
            Update = 0b00000010,
            Delete = 0b00000100,
            _,
        };

        const TMode = enum(u8){
            Entry = 0b00000001,
            Table = 0b00000010,
            _,
        };

        magic: u16 = CONSTS.Magics.Transaction,
        type: TType ,
        mode: TMode ,
        //Size In Bytes
        size: u16,
        id: u32,
        relation: u32, //Points To The Idx of the Table if its a Entry else its unused;
        time: i64,
        fn init(t: TType, m: TMode) TransactionHeader{
            return .{.type = t, .mode = m, .time = std.time.timestamp(), .size = 0, .id = 0, .relation = 0};
        }
    };

    _fd: std.fs.File,
    header: Header = .{},

    pub const OpenFlags = std.fs.File.CreateFlags;
    pub fn init(path: []const u8, flags: OpenFlags) !DB {
        const doesNotExist: bool = if (std.fs.cwd().access(path, .{}) catch |err| switch (err) {
            error.FileNotFound => null,
            else => {},
        }) |_| false else true;
        const file = try std.fs.cwd().createFile(path, flags);
        var db: DB = .{ ._fd = file };
        if (!doesNotExist) try db.reconstruct() else try db.CreateDB();
        return db;
    }

    fn reconstruct(self: *DB) !void {
        const reader = self._fd.reader();
        const header = try reader.readStructEndian(Header, .big);
        try header.validate();
        self.header = header;
    }

    pub fn deinit(self: *DB) void {
        self._fd.close();
    }

    fn writeStruct(self: *const DB, value: anytype) !void {
        const writer = self._fd.writer();
        switch (@typeInfo(@TypeOf(value))){
            .@"struct" => try writer.writeStructEndian(value, .big),
            .pointer => try writer.writeStructEndian(value.*, .big),
            else => |x|@compileLog(x),
        }
    }

    fn WriteHeader(self: *const DB) !void {
        try self._fd.seekTo(0);
        try self.writeStruct(self.header);
    }
    fn CreateDB(self: *const DB) !void {
        try self.WriteHeader();
    }
    fn InsertTransaction(self: *DB, header: *TransactionHeader, data: anytype) !void{
        switch (header.mode){
            .Table => {
                switch (header.type) {
                    .Create=> {self.header.tableCount += 1;},
                    .Delete=> {self.header.tableCount -= 1;},
                    else => {},
                }
            },
            .Entry => {
                switch (header.type) {
                    .Create=> {self.header.entryCount += 1;},
                    .Delete=> {self.header.entryCount -= 1;},
                    else => {},
                }
            },
            _ => {},
        }
        self.header.transactionCount += 1;
        header.id = self.header.transactionCount;
        try self.WriteHeader();
        try self._fd.seekFromEnd(0);
        header.size = @bitSizeOf(@TypeOf(data.*));
        std.debug.print("Size Of Data: {d}\n", .{header.size});
        try self.writeStruct(header);
    }

};

const CONSTS = struct {
    const Magics = struct {
        const DB: u16 = 0xEDDB;
        const Transaction: u16 = 0xEDB7;
    };
    const Version: u16 = 0x0001;
};

test "T" {
    {
        var db = try DB.init("./test/db", .{ .lock = .exclusive, .read = true, .truncate = false });
        defer db.deinit();
        try db.InsertTransaction(@constCast(&DB.TransactionHeader.init(.Delete, .Entry)), &[1]u8{0});
    }
}
