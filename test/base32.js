import {Foundry} from '@adraffy/blocksmith';
import {Base32} from '@adraffy/cid';
import {ethers} from 'ethers';
import {test, after} from 'node:test';
import assert from 'node:assert/strict';

test('base32', async () => {

	let foundry = await Foundry.launch();
	after(() => foundry.shutdown());

	let contract = await foundry.deploy({sol: `
		import {Base32} from '@src/Base32.sol';
		contract Test {
			function decode(bytes memory v) external pure returns (bytes memory) {
				uint256 p;
				assembly { p := add(v, 32) }
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

	for (let i = 0; i < 1000; i++) {
		let v0 = ethers.randomBytes(Math.random() * 256|0);
		let v1 = ethers.getBytes(await contract.decode(ethers.toUtf8Bytes(Base32.encode(v0))));
		assert.deepEqual(v0, v1);
	}

});
