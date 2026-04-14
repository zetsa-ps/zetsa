// Converts config coordinates to protocol coordinates.
pub fn floatToInt(c: f32) i32 {
    return @trunc(c * 100);
}
