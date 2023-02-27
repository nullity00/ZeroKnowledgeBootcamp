%builtins range_check
from starkware.cairo.common.bitwise import bitwise_and, bitwise_xor
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, HashBuiltin
from starkware.cairo.common.math import unsigned_div_rem

// Implement a function that sums even numbers from the provided array
func sum_even{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(arr_len: felt, arr: felt*, run: felt, idx: felt) -> (
    sum: felt
) {
    if ( arr_len == 0 ) {
        return (sum = 0,);
    }
    let (a) = sum_even(arr_len - 1, arr + 1, run, idx + 1);
    let (q, r) = unsigned_div_rem(arr[idx], 2);
    if (r == 0) {
        return (sum = arr[idx] + a,);
    }
    return (sum = a,);
}
