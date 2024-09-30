module dsl_distributor::win {
    use sui::coin::{Self, TreasuryCap, Coin};
    
    public struct WIN has drop {}

    fun init(witness: WIN, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(
            witness, 9, b"WIN", b"Win", 
            b"", option::none(), ctx
        );
        
        transfer::public_share_object(metadata);
        transfer::public_transfer(treasury, ctx.sender())
    }

    // Create WINs using the TreasuryCap.
    public(package) fun mint(
        treasury_cap: &mut TreasuryCap<WIN>, 
        amount: u64, 
        ctx: &mut TxContext,
    ): Coin<WIN> {
        coin::mint(treasury_cap, amount, ctx)
    }
}