module dsl_distributor::win;
use sui::coin;

public struct WIN has drop {}

#[allow(lint(share_owned))]
fun init(witness: WIN, ctx: &mut TxContext) {
    let (treasury, metadata) = coin::create_currency(
        witness, 9, b"WIN", b"Win", 
        b"", option::none(), ctx
    );
    
    transfer::public_share_object(metadata);
    transfer::public_transfer(treasury, ctx.sender())
}