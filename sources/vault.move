/// The module can accept an Arbitrary number of Coins from an arbitrary number of users
/// There should be a 'deposit', and 'withdraw' function that any user can use to deposit and withdraw their own funds,
/// but no other users funds
/// There should also be two functions that only admins can call.
/// 'Pause' and 'Unpause' that prevent new deposits or withdrawals from occurring.
module minivault::vault {
    use std::signer;

    use aptos_framework::coin::{Self, Coin};

    #[test_only]
    use aptos_framework::account;
    #[test_only]
    use minivault::fake_coin;
    #[test_only]
    use std::string;

    const ERR_VAULT_EXISTS: u64 = 0;
    const ERR_VAULT_NOT_EXISTS: u64 = 1;
    const ERR_INSUFFICIENT_ACCOUNT_BALANCE: u64 = 2;
    const ERR_INSUFFICIENT_VAULT_BALANCE: u64 = 3;

    struct Vault<phantom CoinType> has key {
        coin: Coin<CoinType>
    }

    public entry fun open_vault<CoinType>(account: &signer) {
        let account_addr = signer::address_of(account);
        if (!coin::is_account_registered<CoinType>(account_addr)) {
            coin::register<CoinType>(account);
        };
        assert!(!exists_vault<CoinType>(account_addr), ERR_VAULT_EXISTS);
        move_to(account, Vault<CoinType> {
            coin: coin::zero(),
        });
    }

    public entry fun deposit<CoinType>(account: &signer, amount: u64) acquires Vault {
        let account_addr = signer::address_of(account);
        assert!(exists_vault<CoinType>(account_addr), ERR_VAULT_NOT_EXISTS);
        let account_balance = coin::balance<CoinType>(account_addr);
        assert!(account_balance >= amount, ERR_INSUFFICIENT_ACCOUNT_BALANCE);
        let coin = coin::withdraw<CoinType>(account, amount);
        deposit_internal<CoinType>(account, coin);
    }

    public entry fun withdraw<CoinType>(account: &signer, amount: u64) acquires Vault {
        let account_addr = signer::address_of(account);
        assert!(exists_vault<CoinType>(account_addr), ERR_VAULT_NOT_EXISTS);
        let coin = withdraw_internal<CoinType>(account, amount);
        coin::deposit(account_addr, coin);
    }

    public fun deposit_internal<CoinType>(account: &signer, coin: Coin<CoinType>) acquires Vault {
        let account_addr = signer::address_of(account);
        assert!(exists_vault<CoinType>(account_addr), ERR_VAULT_NOT_EXISTS);
        coin::merge(&mut borrow_global_mut<Vault<CoinType>>(account_addr).coin, coin)
    }

    public fun withdraw_internal<CoinType>(account: &signer, amount: u64): Coin<CoinType> acquires Vault {
        let account_addr = signer::address_of(account);
        assert!(exists_vault<CoinType>(account_addr), ERR_VAULT_NOT_EXISTS);
        assert!(vault_balance<CoinType>(account_addr) >= amount, ERR_INSUFFICIENT_VAULT_BALANCE);
        coin::extract(&mut borrow_global_mut<Vault<CoinType>>(account_addr).coin, amount)
    }

    public fun exists_vault<CoinType>(account_addr: address): bool {
        exists<Vault<CoinType>>(account_addr)
    }

    public fun vault_balance<CoinType>(account_addr: address): u64 acquires Vault {
        coin::value(&borrow_global<Vault<CoinType>>(account_addr).coin)
    }

    #[test_only]
    struct FakeCoin {}

    #[test(issuer = @minivault, user = @0xa)]
    public fun end_to_end(issuer: &signer, user: &signer) acquires Vault {
        // init accounts and issue 10000 FakeCoin to user
        account::create_account_for_test(signer::address_of(issuer));
        account::create_account_for_test(signer::address_of(user));
        fake_coin::initialize_account_with_coin<FakeCoin>(issuer, user, string::utf8(b"Fake Coin"), string::utf8(b"FC"), 8, 10000);

        // open vault
        open_vault<FakeCoin>(user);
        let user_addr = signer::address_of(user);

        // deposit
        deposit<FakeCoin>(user, 6000);
        assert!(vault_balance<FakeCoin>(user_addr) == 6000, 0);
        assert!(coin::balance<FakeCoin>(user_addr) == 4000, 0);

        // withdraw
        withdraw<FakeCoin>(user, 5000);
        assert!(vault_balance<FakeCoin>(user_addr) == 1000, 0);
        assert!(coin::balance<FakeCoin>(user_addr) == 9000, 0);
    }
}
