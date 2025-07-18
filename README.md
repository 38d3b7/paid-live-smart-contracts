# paid-live-smart-contracts

This smart contract allows continuous streaming of TON payments from an owner to a designated target address at a specified rate. A commission is automatically split to a configured commission address. The contract supports operations such as starting/stopping the stream, adjusting settings, and handling edge cases like underpayment.

## Technologies I Used

- **TON Blockchain** - L1 blockchain;
- **Tolk Language** - smart contract language for the TVM;
- **toncli** - deployment and interaction;

## Challenges I ran into

- **Understanding the TVM execution model** - unlike EVM’s synchronous calls, TVM uses asynchronous message passing. Coming from the EVM-based development field and adapting to this model required a lot of rethinking of the various concepts;
- **Precise low-level data serialisation** - working with `beginCell()` and manual `.store...()` methods meant paying close attention to data layout. A single mismatch could silently corrupt contract behaviour;
- **Ensuring safe state updates amidst partial failures** - I had to account for bounced messages, interrupted payments, or underfunded transfers to avoid inconsistent contract state, especially around streaming stop events.

## Project structure

-   `contracts` - source code of all the smart contracts of the project and their dependencies.
-   `wrappers` - wrapper classes (implementing `Contract` from ton-core) for the contracts, including any [de]serialization primitives and compilation functions.
-   `tests` - tests for the contracts.
-   `scripts` - scripts used by the project, mainly the deployment scripts.

## How to use

### Build

`npx blueprint build` or `yarn blueprint build`

### Test

`npx blueprint test` or `yarn blueprint test`

### Deploy or run another script

`npx blueprint run` or `yarn blueprint run`

### Add a new contract

`npx blueprint create ContractName` or `yarn blueprint create ContractName`
