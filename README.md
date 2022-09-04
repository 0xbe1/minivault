# Minivault

A vault that accepts coins from any user.

- A user should be able to deposit and withdraw their own funds but no other users' funds.
- An admin could pause to protocol to prevent new deposits and withdrawals, and unpause.

To compile:

```
aptos move compile --named-addresses minivault=0x2
```

To run the tests:

```
aptos move test
```
