# CCIPRewriter.sol

Inline CCIP-Read endpoint-rewriter resolver.

* [**CCIPRewriter.sol**](./src/CCIPRewriter.sol)
	* Deployments: `ccipr.eth`
		* [`mainnet:0x0B03f37f7671825A90Aa2bdE4C00D0559EcBD12C`](https://etherscan.io/address/0x0B03f37f7671825A90Aa2bdE4C00D0559EcBD12C)
		* [`sepolia:0x4434c3F63aCbd9Fe0a108323d5D172e4f7D736d0`](https://sepolia.etherscan.io/address/0x4434c3F63aCbd9Fe0a108323d5D172e4f7D736d0)
	* [**Rewriter Tool**](https://adraffy.github.io/CCIPRewriter.sol/test/) ⭐

### Example

* Original: [`eth.coinbase.tog.raffy.eth`](https://adraffy.github.io/ens-normalize.js/test/resolver.html#eth.coinbase.tog.raffy.eth)
* Rewritten: [`eth.coinbase.tog.raffy.eth.[https://raffy.xyz/tog/fixed/e1].ccipr.eth`](https://adraffy.github.io/CCIPRewriter.sol/test/#coinbase.tog.raffy.eth.nb2hi4dthixs64tbmzthsltypf5c65dpm4xwm2lymvsc6zjr.ccipr.eth)
* Uneffected: [`nick.eth.[https://raffy.xyz/tog/fixed/e1].ccipr.eth`](https://adraffy.github.io/CCIPRewriter.sol/test/#nick.eth.nb2hi4dthixs64tbmzthsltypf5c65dpm4xwm2lymvsc6zjr.ccipr.eth)

### Test

1. `foundryup`
1. `npm i`
1. `npm run test`
