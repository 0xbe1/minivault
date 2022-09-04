module minivault::vault {
    use std::signer;

    use aptos_framework::coin::{Self, Coin};

    #[test_only]
    use aptos_framework::account;
    #[test_only]
    use minivault::fake_coin;
    #[test_only]
    use std::string;

    const ERR_NOT_ADMIN: u64 = 0;
    const ERR_FUSE_EXISTS: u64 = 1;
    const ERR_FUSE_NOT_EXISTS: u64 = 2;
    const ERR_VAULT_EXISTS: u64 = 3;
    const ERR_VAULT_NOT_EXISTS: u64 = 4;
    const ERR_INSUFFICIENT_ACCOUNT_BALANCE: u64 = 5;
    const ERR_INSUFFICIENT_VAULT_BALANCE: u64 = 6;
    const ERR_VAULT_PASUED: u64 = 7;

    struct Fuse<phantom CoinType> has key {
        paused: bool
    }

    /// Each user owns its own vault
    struct Vault<phantom CoinType> has key {
        coin: Coin<CoinType>
    }

    public entry fun init_fuse<CoinType>(minivault: &signer) {
        assert!(signer::address_of(minivault) == @minivault, ERR_NOT_ADMIN);
        move_to(minivault, Fuse<CoinType> {
            paused: false,
        });
    }

    public fun pause<CoinType>(minivault: &signer) acquires Fuse {
        update_paused<CoinType>(minivault, true)
    }

    public fun unpause<CoinType>(minivault: &signer) acquires Fuse {
        update_paused<CoinType>(minivault, false)
    }

    fun update_paused<CoinType>(minivault: &signer, paused: bool) acquires Fuse {
        assert!(signer::address_of(minivault) == @minivault, ERR_NOT_ADMIN);
        assert!(exists_fuse<CoinType>(), ERR_FUSE_NOT_EXISTS);
        borrow_global_mut<Fuse<CoinType>>(@minivault).paused = paused
    }

    fun pausd<CoinType>(): bool acquires Fuse {
        borrow_global<Fuse<CoinType>>(@minivault).paused
    }

    public fun exists_fuse<CoinType>(): bool {
        exists<Fuse<CoinType>>(@minivault)
    }

    public entry fun init_vault<CoinType>(account: &signer) {
        let account_addr = signer::address_of(account);
        if (!coin::is_account_registered<CoinType>(account_addr)) {
            coin::register<CoinType>(account);
        };
        assert!(!exists_vault<CoinType>(account_addr), ERR_VAULT_EXISTS);
        move_to(account, Vault<CoinType> {
            coin: coin::zero(),
        });
    }

    public entry fun deposit<CoinType>(account: &signer, amount: u64) acquires Vault, Fuse {
        let account_addr = signer::address_of(account);
        assert!(exists_vault<CoinType>(account_addr), ERR_VAULT_NOT_EXISTS);
        let account_balance = coin::balance<CoinType>(account_addr);
        assert!(account_balance >= amount, ERR_INSUFFICIENT_ACCOUNT_BALANCE);
        let coin = coin::withdraw<CoinType>(account, amount);
        deposit_internal<CoinType>(account, coin);
    }

    public entry fun withdraw<CoinType>(account: &signer, amount: u64) acquires Vault, Fuse {
        let account_addr = signer::address_of(account);
        assert!(exists_vault<CoinType>(account_addr), ERR_VAULT_NOT_EXISTS);
        let coin = withdraw_internal<CoinType>(account, amount);
        coin::deposit(account_addr, coin);
    }

    fun deposit_internal<CoinType>(account: &signer, coin: Coin<CoinType>) acquires Vault, Fuse {
        assert!(!pausd<CoinType>(), ERR_VAULT_PASUED);
        let account_addr = signer::address_of(account);
        assert!(exists_vault<CoinType>(account_addr), ERR_VAULT_NOT_EXISTS);
        coin::merge(&mut borrow_global_mut<Vault<CoinType>>(account_addr).coin, coin)
    }

    fun withdraw_internal<CoinType>(account: &signer, amount: u64): Coin<CoinType> acquires Vault, Fuse {
        assert!(!pausd<CoinType>(), ERR_VAULT_PASUED);
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

    #[test(admin = @minivault, user = @0xa)]
    #[expected_failure(abort_code = 0)]
    public fun only_admin_can_pause(admin: &signer, user: &signer) acquires Fuse {
        setup_account(admin, user);
        init_fuse<FakeCoin>(admin);
        init_vault<FakeCoin>(user);

        pause<FakeCoin>(user);
    }

    #[test(admin = @minivault, user = @0xa)]
    #[expected_failure(abort_code = 7)]
    public fun op_fail_when_paused(admin: &signer, user: &signer) acquires Vault, Fuse {
        setup_account(admin, user);
        init_fuse<FakeCoin>(admin);
        init_vault<FakeCoin>(user);

        pause<FakeCoin>(admin);
        deposit<FakeCoin>(user, 10000);
    }

    #[test(admin = @minivault, user = @0xa)]
    public fun end_to_end(admin: &signer, user: &signer) acquires Vault, Fuse {
        // init
        setup_account(admin, user);
        init_fuse<FakeCoin>(admin);
        init_vault<FakeCoin>(user);
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

    #[test_only]
    fun setup_account(admin: &signer, user: &signer) {
        // init accounts and issue 10000 FakeCoin to user
        account::create_account_for_test(signer::address_of(admin));
        account::create_account_for_test(signer::address_of(user));
        fake_coin::initialize_account_with_coin<FakeCoin>(admin, user, string::utf8(b"Fake Coin"), string::utf8(b"FC"), 8, 10000);
    }
}
