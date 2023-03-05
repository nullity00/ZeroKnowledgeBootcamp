%lang starknet
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_block_timestamp
from starkware.cairo.common.math import unsigned_div_rem, assert_le_felt, assert_le, assert_nn, assert_not_zero, assert_not_equal
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.pow import pow
from starkware.cairo.common.hash_state import hash_init, hash_update
from starkware.cairo.common.bitwise import bitwise_and, bitwise_xor, bitwise_or
from lib.constants import TRUE, FALSE

// Structs
//#########################################################################################

struct Consortium {
    chairperson: felt,
    proposal_count: felt,
}

struct Member {
    votes: felt,
    prop: felt,
    ans: felt,
}

struct Answer {
    text: felt,
    votes: felt,
}

struct Proposal {
    type: felt,  // whether new answers can be added
    win_idx: felt,  // index of preffered option
    ans_idx: felt,
    deadline: felt,
    over: felt,
}

// remove in the final asnwerless
struct Winner {
    highest: felt,
    idx: felt,
}

// Storage
//#########################################################################################

@storage_var
func consortium_idx() -> (idx: felt) {
}

@storage_var
func consortiums(consortium_idx: felt) -> (consortium: Consortium) {
}

@storage_var
func members(consortium_idx: felt, member_addr: felt) -> (memb: Member) {
}

@storage_var
func proposals(consortium_idx: felt, proposal_idx: felt) -> (proposal: Proposal) {
}

@storage_var
func proposals_idx(consortium_idx: felt) -> (idx: felt) {
}

@storage_var
func proposals_title(consortium_idx: felt, proposal_idx: felt, string_idx: felt) -> (
    substring: felt
) {
}

@storage_var
func proposals_link(consortium_idx: felt, proposal_idx: felt, string_idx: felt) -> (
    substring: felt
) {
}

@storage_var
func proposals_answers(consortium_idx: felt, proposal_idx: felt, answer_idx: felt) -> (
    answers: Answer
) {
}

@storage_var
func voted(consortium_idx: felt, proposal_idx: felt, member_addr: felt) -> (true: felt) {
}

@storage_var
func answered(consortium_idx: felt, proposal_idx: felt, member_addr: felt) -> (true: felt) {
}

// External functions
//#########################################################################################

@external
func create_consortium{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let (idx: felt) = consortium_idx.read();
    let (chairperson: felt) = get_caller_address();
    consortium_idx.write(idx+1);
    consortiums.write(idx+1, Consortium(chairperson, 0));
    members.write(idx+1, chairperson, Member(100, TRUE, TRUE));
    return ();
}

@external
func add_proposal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    consortium_idx: felt,
    title_len: felt,
    title: felt*,
    link_len: felt,
    link: felt*,
    ans_len: felt,
    ans: felt*,
    type: felt,
    deadline: felt,
) {
    let (callee: felt) = get_caller_address();
    let (member: Member) = members.read(consortium_idx, callee);
    assert_not_equal(member.prop, FALSE);
    let (idx: felt) = proposals_idx.read(consortium_idx);
    proposals_idx.write(consortium_idx, idx + 1);
    proposals.write(consortium_idx, idx + 1, Proposal(type, 0, 0, deadline, FALSE));
    proposals_title.write(consortium_idx, idx + 1, title_len, title);
    proposals_link.write(consortium_idx, idx + 1, link_len, link);
    return ();
}

@external
func add_member{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    consortium_idx: felt, member_addr: felt, prop: felt, ans: felt, votes: felt
) {
    let (callee: felt) = get_caller_address();
    let (consortium: Consortium) = consortiums.read(consortium_idx);
    if (callee != consortium.chairperson) {
        return ();
    }
    members.write(consortium_idx, member_addr, Member(votes, prop, ans));
    return ();
}

@external
func add_answer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    consortium_idx: felt, proposal_idx: felt, string_len: felt, string: felt
) {
    let (callee: felt) = get_caller_address();
    let (member: Member) = members.read(consortium_idx, callee);
    assert_not_equal(member.ans, FALSE);
    let (proposal: Proposal) = proposals.read(consortium_idx, proposal_idx);
    proposals_answers.write(consortium_idx, proposal_idx, proposal.ans_idx + 1, Answer(string, 0));
    proposals.write(consortium_idx, proposal_idx, Proposal(proposal.type, proposal.win_idx, proposal.ans_idx + 1, proposal.deadline, proposal.over));
    return ();
}

@external
func vote_answer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    consortium_idx: felt, proposal_idx: felt, answer_idx: felt
) {
    let (callee: felt) = get_caller_address();
    let (member : Member) = members.read(consortium_idx, callee);
    assert_not_zero(member.votes);
    let (true) = voted.read(consortium_idx, proposal_idx, callee);
    assert_not_equal(true, 1);
    voted.write(consortium_idx, proposal_idx, callee, 1);
    let (answer : felt) = proposals_answers.read(consortium_idx, proposal_idx, answer_idx);
    proposals_answers.write(consortium_idx, proposal_idx, answer_idx, Answer(answer.text, answer.votes + 1));
    members.write(consortium_idx, callee, Member(member.votes - 1, member.prop, member.ans));
    return ();
}

@external
func tally{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    consortium_idx: felt, proposal_idx: felt
) -> (win_idx: felt) {
    let (callee: felt) = get_caller_address();
    let (timestamp: felt) = get_block_timestamp();
    let (consortium: Consortium) = consortiums.read(consortium_idx);
    if (callee != consortium.chairperson) {
        assert_le(consortium.deadline, timestamp);
        let (proposal: Proposal) = proposals.read(consortium_idx, proposal_idx);
        let highest_votes: felt = 0;
        let (idx : felt) = find_highest(consortium_idx, proposal_idx, highest_votes, proposal.ans_idx, proposal.ans_idx);
        return (win_idx = idx,);
    }
}


// Internal functions
//#########################################################################################


func find_highest{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    consortium_idx: felt, proposal_idx: felt, highest: felt, idx: felt, countdown: felt
) -> (idx: felt) {
    if (countdown == 0) {
        return (idx = idx,);
    }
    let (answer: Answer) = proposals_answers.read(consortium_idx, proposal_idx, countdown);
    if (answer.votes - highest == 0) {
        return (idx = find_highest(consortium_idx, proposal_idx, answer.votes, countdown, countdown - 1),);
    } 
    return (idx = find_highest(consortium_idx, proposal_idx, highest, idx, countdown - 1),); 
}

// Loads it based on length, internall calls only
func load_selector{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    string_len: felt,
    string: felt*,
    slot_idx: felt,
    proposal_idx: felt,
    consortium_idx: felt,
    selector: felt,
    offset: felt,
) {

    return ();
}
