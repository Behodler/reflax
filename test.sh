direnv allow && source .envrc && rm ztest/contract_addresses.txt && touch ztest/contract_addresses.txt && echo $DebugUpTo && forge test  --ffi -f $RPC_URL --match-path ztest/vaults/test_USDC_v1.sol -vvvv --match-test testSimpleImmediateWithdrawal

#  --match-test testClaim_accumulate_rewards
# 