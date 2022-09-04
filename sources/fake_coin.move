module minivault::fake_coin {
    use std::signer;
    use std::string;

    use aptos_framework::coin;

    #[test_only]
    public entry fun initialize_account_with_coin<CoinType>(
        issuer: &signer,
        destination: &signer,
        name: string::String,
        symbol: string::String,
        decimals: u8,
        amount: u64
    ) {
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize(issuer, name, symbol, decimals, true);
        coin::register<CoinType>(issuer);
        coin::register<CoinType>(destination);
        let coins_minted = coin::mint<CoinType>(amount, &mint_cap);
        coin::deposit(signer::address_of(destination), coins_minted);

        // cleanup
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_freeze_cap(freeze_cap);
        coin::destroy_mint_cap(mint_cap);
    }
}
