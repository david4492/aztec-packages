use dep::std::hash::{pedersen, pedersen_with_separator};
use crate::constants_gen::{GENERATOR_INDEX__UNIQUE_COMMITMENT, GENERATOR_INDEX__OUTER_COMMITMENT};

fn compute_inner_hash(storage_slot: Field, note_hash: Field) -> Field {
    pedersen([storage_slot, note_hash])[0]
}

fn compute_unique_hash(nonce: Field, inner_note_hash: Field) -> Field {
    let inputs = [nonce, inner_note_hash];
    pedersen_with_separator(inputs, GENERATOR_INDEX__UNIQUE_COMMITMENT)[0]
}

fn compute_siloed_hash(contract_address: Field, unique_note_hash: Field) -> Field {
    let inputs = [contract_address, unique_note_hash];
    pedersen_with_separator(inputs, GENERATOR_INDEX__OUTER_COMMITMENT)[0]
}