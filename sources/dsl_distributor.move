/// Module: dsl_distributor
module dsl_distributor::dsl_distributor; 
// === Imports === 

use std::type_name::{Self, TypeName};

use sui::{
    coin::Coin,
    event::emit,
    clock::Clock,
    table::{Self, Table},
    balance::{Self, Balance},
}; 

use dsl_distributor::acl::AuthWitness;

// === Constants === 

// @dev Sentinel value for the start time of the distribution
const MAX_U64: u64 = 18446744073709551615;

// === Errors ===  

#[error]
const EInvalidClaim: vector<u8> = b"You do not have an allowance to claim";

#[error]
const EInvalidTime: vector<u8> = b"You cannot claim before the distribution has started";

// === Structs ===  

public struct DslDistributor<phantom CoinType> has key {
    id: UID,
    allowances: Table<address, u64>,
    balance: Balance<CoinType>,
    start: u64
}

// === Events === 

public struct Claimed has drop, store, copy {
    sharer: address,
    amount: u64,
    coin: TypeName,
}

// === Public Mutative Functions === 

public fun new<CoinType>(ctx: &mut TxContext): DslDistributor<CoinType> {
    DslDistributor {
        id: object::new(ctx),
        allowances: table::new(ctx),
        balance: balance::zero(),
        start: MAX_U64
    }  
}

#[allow(lint(share_owned))]
public fun share<CoinType>(self: DslDistributor<CoinType>) {
    transfer::share_object(self);
}

public fun add<CoinType>(self: &mut DslDistributor<CoinType>, asset: Coin<CoinType>): u64 {
    self.balance.join(asset.into_balance())
}

public fun claim<CoinType>(self: &mut DslDistributor<CoinType>, clock: &Clock, ctx: &mut TxContext): Coin<CoinType> {
    assert!(clock.timestamp_ms() >= self.start, EInvalidTime);
    
    let total_value = self.balance.value(); 

    let sender = ctx.sender(); 

    let allowance = &mut self.allowances[sender]; 

    assert!(*allowance != 0, EInvalidClaim);

    let claim_value = min(total_value, *allowance);

    let asset = self.balance.split(claim_value);

    emit(Claimed {
        sharer: sender,
        amount: claim_value,
        coin: type_name::get<CoinType>()
    });

    *allowance = 0; 

    asset.into_coin(ctx)
}

// === View Functions === 

public fun allowance<CoinType>(self: &DslDistributor<CoinType>, sharer: address): u64 {
    if (!self.allowances.contains(sharer)) 
        return 0;

    self.allowances[sharer]
}

// === Admin Functions === 

public fun set_allowance<CoinType>(
    self: &mut DslDistributor<CoinType>, 
    _: &AuthWitness, 
    sharer: address, 
    new_allowance: u64
) {
    register(&mut self.allowances, sharer); 

    let allowance = &mut self.allowances[sharer];
    *allowance = new_allowance;
}

public fun set_start<CoinType>(
    self: &mut DslDistributor<CoinType>, 
    _: &AuthWitness, 
    start: u64
) {
    self.start = start;
}

public fun remove<CoinType>(
    self: &mut DslDistributor<CoinType>, 
    _: &AuthWitness, 
    amount: u64,
    ctx: &mut TxContext
): Coin<CoinType> {
    let total_value = self.balance.value(); 

    self.balance.split(min(total_value, amount)).into_coin(ctx)
}

// === Private Functions === 

fun register(allowances: &mut Table<address, u64>, sharer: address) {
    if (!allowances.contains(sharer))  
        table::add(allowances, sharer, 0);
}

fun min(a: u64, b: u64): u64 {
    if (a < b) a else b
}