pub fn substitute(format: []const u8, value: []const u8, buffer: []u8) []const u8 {
    if (format.len == 0) {
        const len = @min(value.len, buffer.len);
        @memcpy(buffer[0..len], value[0..len]);
        return buffer[0..len];
    }

    var out_idx: usize = 0;
    var fmt_idx: usize = 0;
    while (fmt_idx < format.len and out_idx < buffer.len -| value.len) {
        if (fmt_idx + 1 < format.len and format[fmt_idx] == '{' and format[fmt_idx + 1] == '}') {
            @memcpy(buffer[out_idx .. out_idx + value.len], value);
            out_idx += value.len;
            fmt_idx += 2;
        } else {
            buffer[out_idx] = format[fmt_idx];
            out_idx += 1;
            fmt_idx += 1;
        }
    }
    return buffer[0..out_idx];
}

pub fn substitute_multi(format: []const u8, values: []const []const u8, buffer: []u8) []const u8 {
    if (format.len == 0 and values.len > 0) {
        const len = @min(values[0].len, buffer.len);
        @memcpy(buffer[0..len], values[0][0..len]);
        return buffer[0..len];
    }

    var out_idx: usize = 0;
    var fmt_idx: usize = 0;
    var val_idx: usize = 0;
    while (fmt_idx < format.len and out_idx < buffer.len - 20) {
        if (fmt_idx + 1 < format.len and format[fmt_idx] == '{' and format[fmt_idx + 1] == '}') {
            if (val_idx < values.len) {
                const value = values[val_idx];
                if (out_idx + value.len <= buffer.len) {
                    @memcpy(buffer[out_idx .. out_idx + value.len], value);
                    out_idx += value.len;
                }
                val_idx += 1;
            }
            fmt_idx += 2;
        } else {
            buffer[out_idx] = format[fmt_idx];
            out_idx += 1;
            fmt_idx += 1;
        }
    }
    return buffer[0..out_idx];
}
