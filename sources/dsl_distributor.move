/// Module: dsl_distributor
module dsl_distributor::distributor; 
// === Imports === 

use std::u64;
use sui::{
    coin::Coin,
    event::emit,
    clock::Clock,
    balance::{Self, Balance},
}; 
use dsl_distributor::{
    acl::AuthWitness,
    win::{Self, WIN} // TODO: import from DSL contract
};

// === Errors ===  

#[error]
const EInvalidTime: vector<u8> = b"You cannot claim before the distribution has started";

#[error]
const EDistributorEmpty: vector<u8> = b"The distributor has no more tokens to claim";

// === Structs ===  

public struct DslDistributor<phantom WIN> has key {
    id: UID,
    balance: Balance<WIN>,
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
    transfer::share_object(DslDistributor<WIN> {
        id: object::new(ctx),
        balance: balance::zero(),
        start: u64::max_value!()
    });
}

public fun claim(
    self: &mut DslDistributor<WIN>, 
    allocation: Allocation,
    clock: &Clock, 
    ctx: &mut TxContext
): Coin<WIN> {
    assert!(clock.timestamp_ms() >= self.start, EInvalidTime);
    assert!(self.balance.value() > 0, EDistributorEmpty);

    let Allocation { id, amount } = allocation;
    id.delete();

    let claim_value = min(self.balance.value(), amount);

    emit(Claimed {
        sharer: ctx.sender(),
        amount: claim_value,
    });

    self.balance.split(claim_value).into_coin(ctx)
}

public fun deposit(self: &mut DslDistributor<WIN>, asset: Coin<WIN>): u64 {
    self.balance.join(asset.into_balance())
}

// === Admin Functions === 

public fun allocate(
    _: &AuthWitness, 
    amount: u64,
    ctx: &mut TxContext
): Allocation {
    Allocation { id: object::new(ctx), amount }
}

public fun remove(
    self: &mut DslDistributor<WIN>, 
    _: &AuthWitness, 
    amount: u64,
    ctx: &mut TxContext
): Coin<WIN> {
    let total_value = self.balance.value(); 

    self.balance.split(min(total_value, amount)).into_coin(ctx)
}

public fun set_start(
    self: &mut DslDistributor<WIN>, 
    _: &AuthWitness, 
    start: u64
) {
    self.start = start;
}

// === Private Functions === 

fun min(a: u64, b: u64): u64 {
    if (a < b) a else b
}