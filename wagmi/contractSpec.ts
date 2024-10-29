import { ContractConfig } from '@wagmi/cli';
import { Abi } from 'viem';
const contractSpec:  ContractConfig<number, undefined>[] =
    [
        {
            abi: [
                {
                    "type": "function",
                    "name": "config",
                    "inputs": [],
                    "outputs": [
                        {
                            "name": "inputToken",
                            "type": "address",
                            "internalType": "contract IERC20"
                        },
                        {
                            "name": "flax",
                            "type": "address",
                            "internalType": "contract IERC20"
                        },
                        {
                            "name": "sFlax",
                            "type": "address",
                            "internalType": "contract ISFlax"
                        },
                        {
                            "name": "yieldSource",
                            "type": "address",
                            "internalType": "contract AYieldSource"
                        },
                        {
                            "name": "booster",
                            "type": "address",
                            "internalType": "contract IBooster"
                        }
                    ],
                    "stateMutability": "view"
                },
                {
                    "type": "function",
                    "name": "migrateYieldSouce",
                    "inputs": [
                        {
                            "name": "newYieldSource",
                            "type": "address",
                            "internalType": "address"
                        }
                    ],
                    "outputs": [],
                    "stateMutability": "nonpayable"
                },
                {
                    "type": "function",
                    "name": "owner",
                    "inputs": [],
                    "outputs": [
                        {
                            "name": "",
                            "type": "address",
                            "internalType": "address"
                        }
                    ],
                    "stateMutability": "view"
                },
                {
                    "type": "function",
                    "name": "renounceOwnership",
                    "inputs": [],
                    "outputs": [],
                    "stateMutability": "nonpayable"
                },
                {
                    "type": "function",
                    "name": "setConfig",
                    "inputs": [
                        {
                            "name": "flaxAddress",
                            "type": "string",
                            "internalType": "string"
                        },
                        {
                            "name": "sFlaxAddress",
                            "type": "string",
                            "internalType": "string"
                        },
                        {
                            "name": "yieldAddress",
                            "type": "string",
                            "internalType": "string"
                        },
                        {
                            "name": "boosterAddress",
                            "type": "string",
                            "internalType": "string"
                        }
                    ],
                    "outputs": [],
                    "stateMutability": "nonpayable"
                },
                {
                    "type": "function",
                    "name": "transferOwnership",
                    "inputs": [
                        {
                            "name": "newOwner",
                            "type": "address",
                            "internalType": "address"
                        }
                    ],
                    "outputs": [],
                    "stateMutability": "nonpayable"
                },
                {
                    "type": "function",
                    "name": "withdrawUnaccountedForToken",
                    "inputs": [
                        {
                            "name": "token",
                            "type": "address",
                            "internalType": "address"
                        }
                    ],
                    "outputs": [],
                    "stateMutability": "nonpayable"
                },
                {
                    "type": "event",
                    "name": "OwnershipTransferred",
                    "inputs": [
                        {
                            "name": "previousOwner",
                            "type": "address",
                            "indexed": true,
                            "internalType": "address"
                        },
                        {
                            "name": "newOwner",
                            "type": "address",
                            "indexed": true,
                            "internalType": "address"
                        }
                    ],
                    "anonymous": false
                },
                {
                    "type": "error",
                    "name": "OwnableInvalidOwner",
                    "inputs": [
                        {
                            "name": "owner",
                            "type": "address",
                            "internalType": "address"
                        }
                    ]
                },
                {
                    "type": "error",
                    "name": "OwnableUnauthorizedAccount",
                    "inputs": [
                        {
                            "name": "account",
                            "type": "address",
                            "internalType": "address"
                        }
                    ]
                },
                {
                    "type": "error",
                    "name": "ReentrancyGuardReentrantCall",
                    "inputs": []
                }
            ],
            name: "AVault"
        }

    ]

export default contractSpec