import {Foundry, Resolver, Node} from '@adraffy/blocksmith';
import {Base32} from '@adraffy/cid';
import {EZCCIP, serve} from '@resolverworks/ezccip';
import {ethers} from 'ethers';
import {test, after} from 'node:test';
import assert from 'node:assert/strict';

console.log(Base32.encode([0]));

test('base32', async () => {

	let foundry = await Foundry.launch();
	after(() => foundry.shutdown());

	let contract = await foundry.deploy({sol: `
		import {Base32} from '@src/Base32.sol';
		contract Test {
			function decode(bytes calldata v) external pure returns (bytes memory) {
				uint256 p;
				assembly { p := add(v.offset, 32) }
				(bool ok, bytes memory ret) = Base32.decode(p, v.length);
				require(ok);
				return ret;
			}
			function test(bytes memory v) external pure returns (bytes32) {
				uint256 p;
				assembly { p := add(v, 32) }
				assembly {
					p := mload(p)
				}
				return bytes32(p);
			}
		}
	`});
	//console.log(await contract.test(ethers.toUtf8Bytes('aa')));

	await contract.decode(ethers.toUtf8Bytes('aa'));

	// for (let i = 0; i < 1000; i++) {
	// 	let v0 = ethers.randomBytes(10); //Math.random() * 256|0);
	// 	console.log(Base32.encode(v0));
	// 	let v1 = ethers.getBytes(await contract.decode(ethers.toUtf8Bytes(Base32.encode(v0))));
	// 	assert.deepEqual(v0, v1);
	// }

});

/*
test('resolver', async T => {

	let foundry = await Foundry.launch();
	after(() => foundry.shutdown());

	let root = Node.root();
	let ens = await foundry.deploy({file: 'ENSRegistry'});
	Object.assign(ens, {
		async $register(node, {owner, resolver} = {}) {
			let w = foundry.requireWallet(await this.owner(node.parent.namehash));
			owner = foundry.requireWallet(owner, w);
			await foundry.confirm(this.connect(w).setSubnodeRecord(node.parent.namehash, node.labelhash, owner, resolver ?? ethers.ZeroAddress, 0), {name: node.name});
			return node;
		}
	});

	// create an offchain resolver that has invalid endpoints
	let blackhole = await foundry.deploy({sol: `
		import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
		import {IExtendedResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IExtendedResolver.sol";
		import {ITextResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/ITextResolver.sol";
		error OffchainLookup(address from, string[] urls, bytes request, bytes4 callback, bytes carry);
		interface Chonk {
			function chonk() external view returns (bytes memory);
		}
		contract Blackhole is IERC156, IExtendedResolver {
			function supportsInterface(bytes4 x) external pure returns (bool) {
				return x == type(IERC165).interfaceId || x == type(IExtendedResolver).interfaceId;
			}
			function resolve(bytes memory dnsname, bytes memory data) external view returns (bytes memory) {
				bytes memory request = abi.encodeWithSelector(IExtendedResolver.resolve.selector, dnsname, data);
				string[] memory urls = new string[](1);
				urls[0] = "I AM NOT A URL";
				revert OffchainLookup(address(this), url, request, this.resolveCallback.selector, '');
			}
			function resolveCallback(bytes memory response, bytes memory) view returns (bytes memory) {
				return abi.encode(response);
			}
		}
	`});

	// create a rewriter
	let rewriter = await foundry.deploy({file: 'CCIPRewriter', args: [ens]});

	// setup ens
	let raffy = await ens.$register(root.create('raffy'), {resolver: blackhole});
	let fixer = await ens.$register(root.create('fixer'), {resolver: rewriter});

	// create a ccip server
	let record = {
		text() { return 'Chonk'; }
	};
	let ccip = await serve(() => record, {protocol: 'raw'});
	after(() => ccip.http.close());

	// resolve name and confirm that it fails
	let r1 = await Resolver.get(ens, raffy);
	await T.test('direct fails', () => assert.rejects(() => r1.text('name')));

	// resolve name via rewriter lens and confirm that it works
	let r2 = await Resolver.get(ens, root.create(`${raffy.name}.${Base32.encode(ccip.endpoint)}.${rewriter.name}`));
	await T.test('rewrite okay', async () => assert.equal(await r2.text('name'), record.text()));

});
*/