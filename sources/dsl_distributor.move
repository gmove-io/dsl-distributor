/// Module: dsl_distributor
module dsl_distributor::distributor; 
// === Imports === 

use std::u64;
use sui::{
    coin::{TreasuryCap, Coin},
    event::emit,
    clock::Clock,
}; 
use dsl_distributor::{
    acl::AuthWitness,
    win::{Self, WIN}
};

// === Errors ===  

#[error]
const EInvalidTime: vector<u8> = b"You cannot claim before the distribution has started";

#[error]
const EDistributorEmpty: vector<u8> = b"The distributor has no more tokens to claim";

// === Structs ===  

public struct DslDistributor has key {
    id: UID,
    total: u64,
    start: u64
}

public struct Allocation has key {
    id: UID,
    amount: u64
}

// === Events === 

public struct Claimed has drop, store, copy {
    sharer: address,
    amount: u64,
}

// === Public Mutative Functions === 

fun init(ctx: &mut TxContext) {
    transfer::share_object(DslDistributor {
        id: object::new(ctx),
        total: 0,
        start: u64::max_value!()
    });
}

public fun claim(
    self: &mut DslDistributor, 
    allocation: Allocation,
    treasury_cap: &mut TreasuryCap<WIN>,
    clock: &Clock, 
    ctx: &mut TxContext
): Coin<WIN> {
    assert!(clock.timestamp_ms() >= self.start, EInvalidTime);
    assert!(self.total > 0, EDistributorEmpty);

    let Allocation { id, amount } = allocation;
    id.delete();

    let claim_value = min(self.total, amount);
    self.total = self.total - claim_value;

    emit(Claimed {
        sharer: ctx.sender(),
        amount: claim_value,
    });

    win::mint(treasury_cap, amount, ctx)
}

// === Admin Functions === 

public fun allocate(
    _: &AuthWitness, 
    amount: u64,
    ctx: &mut TxContext
): Allocation {
    Allocation { id: object::new(ctx), amount }
}

public fun set_start(
    self: &mut DslDistributor, 
    _: &AuthWitness, 
    start: u64
) {
    self.start = start;
}

public fun set_total(
    self: &mut DslDistributor, 
    _: &AuthWitness, 
    total: u64
) {
    self.total = total;
}

// === Private Functions === 

fun min(a: u64, b: u64): u64 {
    if (a < b) a else b
}