use dep::std::hash::poseidon;

// https://github.com/noir-lang/noir/blob/master/noir_stdlib/src/merkle.nr
// instead of pedersen hash we use poseidon hash
pub fn compute_merkle_root<let N: u32>(leaf: Field, index: Field, hash_path: [Field; N]) -> Field {
    // let n = hash_path.len();
    // let index_bits = index.to_le_bits();
    let index_bits: [u1; N] = index.to_le_bits();
    let mut current = leaf;
    for i in 0..N {
        let path_bit = index_bits[i] as bool;
        let (hash_left, hash_right) = if path_bit {
            (hash_path[i], current)
        } else {
            (current, hash_path[i])
        };
        current = poseidon::bn254::hash_2([hash_left, hash_right]);
    }
    current
}

// #[test]
// fn test_not_equal() {
//     assert(not_equal(1, 2));

//     // Uncomment to make test fail
//     // assert(not_equal(1, 1));
// }
