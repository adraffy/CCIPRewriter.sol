import {Foundry, Resolver, Node} from '@adraffy/blocksmith';
import {Base32} from '@adraffy/cid';
import {serve} from '@resolverworks/ezccip';
import {ethers} from 'ethers';
import {test, after} from 'node:test';
import assert from 'node:assert/strict';

test('resolver', async T => {

	let foundry = await Foundry.launch();
	after(() => foundry.shutdown());

	let root = Node.root();
	let ens = await foundry.deploy({import: '@ensdomains/ens-contracts/contracts/registry/ENSRegistry.sol'});
	Object.assign(ens, {
		async $register(node, {owner, resolver} = {}) {
			let w = foundry.requireWallet(await this.owner(node.parent.namehash));
			owner = foundry.requireWallet(owner, w);
			await foundry.confirm(this.connect(w).setSubnodeRecord(node.parent.namehash, node.labelhash, owner, resolver ?? ethers.ZeroAddress, 0), {name: node.name});
			return node;
		}
	});

	// setup reverse
	let reverse_registrar = await foundry.deploy({import: '@ensdomains/ens-contracts/contracts/reverseRegistrar/ReverseRegistrar.sol', args: [ens]});
	let reverse = await ens.$register(root.create('reverse'));
	await ens.$register(reverse.create('addr'), {owner: reverse_registrar});

	// create a normal resolver
	const NORMAL = 'Chonker';
	let normal_resolver = await foundry.deploy({sol: `
		import {ITextResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/ITextResolver.sol";
		contract Normal is ITextResolver {
			function text(bytes32 node, string memory key) external pure returns (string memory) {
				return "${NORMAL}";
			}
		}
	`});

	// create an offchain resolver that has invalid endpoints
	let broken_resolver = await foundry.deploy({sol: `
		import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
		import {IExtendedResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IExtendedResolver.sol";
		import {ITextResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/ITextResolver.sol";
		error OffchainLookup(address from, string[] urls, bytes request, bytes4 callback, bytes carry);
		interface Chonk {
			function chonk() external view returns (bytes memory);
		}
		contract Broken is IERC165, IExtendedResolver {
			function supportsInterface(bytes4 x) external pure returns (bool) {
				return x == type(IERC165).interfaceId || x == type(IExtendedResolver).interfaceId;
			}
			function resolve(bytes memory dnsname, bytes memory data) external view returns (bytes memory) {
				bytes memory request = abi.encodeWithSelector(IExtendedResolver.resolve.selector, dnsname, data);
				string[] memory urls = new string[](1);
				urls[0] = "I AM NOT A URL";
				revert OffchainLookup(address(this), urls, request, this.resolveCallback.selector, '');
			}
			function resolveCallback(bytes memory response, bytes memory) external view returns (bytes memory) {
				return response;
			}
		}
	`});

	// create a rewriter
	let rewriter_resolver = await foundry.deploy({file: 'CCIPRewriter', args: [ens]});

	// setup ens
	let broken   = await ens.$register(root.create('broken'),  {resolver: broken_resolver});
	let normal   = await ens.$register(root.create('normal'),  {resolver: normal_resolver});
	let rewriter = await ens.$register(root.create('rewriter'), {resolver: rewriter_resolver});

	// create a ccip server
	let record = {
		text() { return 'Chonk'; }
	};
	let ccip = await serve(() => record, {protocol: 'raw'});
	after(() => ccip.http.close());

	function rewrite(node) {
		return root.create(`${node.name}.${Base32.encode(ethers.toUtf8Bytes(ccip.endpoint))}.${rewriter.name}`);
	}

	// resolve broken and confirm that it fails
	await T.test(`broken: direct`, () => assert.rejects(() => Resolver.get(ens, broken).then(r => r.text('name'))));
	
	// resolve broken with rewriter and confirm that it works
	let re_broken = rewrite(broken);
	await T.test(`broken: ${re_broken.name}`, async () => assert.equal(await Resolver.get(ens, re_broken).then(r => r.text('name')), record.text()));

	// resolve normal
	await T.test('normal: direct', async () => assert.equal(await Resolver.get(ens, normal).then(r => r.text('name')), NORMAL));

	// resolve normal with rewriter and confirm unaffected
	let re_normal = rewrite(normal);
	await T.test(`normal: ${re_normal.name}`, async () => assert.equal(await Resolver.get(ens, re_normal).then(r => r.text('name')), NORMAL));

});