// Implement a funcion that returns:
// - 1 when magnitudes of inputs are equal
// - 0 otherwise

%builtins range_check
from starkware.cairo.common.math import abs_value


func abs_eq{range_check_ptr}(x: felt, y: felt) -> (bit: felt) {
    let a = abs_value(x);
    let b = abs_value(y);
    if (a == b) {
        return (bit = 1);
    }
    return (bit = 0);
}
