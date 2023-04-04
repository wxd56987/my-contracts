# Advertisements Project

## Install Dependencies

```sh
yarn
```

## Command

Compile contracts

```sh
yarn compile
```

Test contracts
```sh
yarn test # Run all test case
yarn test test/Advertisements.spec.ts # Run single case
```

Clean caches
```sh
yarn clean
```

Flatten
```sh
yarn flatten
```

## Contracts

```sh
contracts
├── AdMatch.sol
├── Advertisements.sol
├── libraries
│   └── TransferHelper.sol
└── test
    └── TestERC20.sol
```