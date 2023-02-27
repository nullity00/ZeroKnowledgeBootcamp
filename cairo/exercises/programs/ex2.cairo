from starkware.cairo.common.uint256 import Uint256, uint256_add

// Modify both functions so that they increment
// supplied value and return it
func add_one(y: felt) -> (val: felt) {
    return (val = y + 1,);
}

func add_one_U256{range_check_ptr}(y: Uint256) -> (val: Uint256) {
    let (a,b) = uint256_add(y, Uint256(low=1, high=0));
    return (val = a,);
}
