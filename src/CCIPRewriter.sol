/// @author raffy.eth
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// interfaces
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ENS} from "@ensdomains/ens-contracts/contracts/registry/ENS.sol";
import {IExtendedResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IExtendedResolver.sol";
import {IMulticallable} from "@ensdomains/ens-contracts/contracts/resolvers/IMulticallable.sol";

// libraries
import {Base32} from "./Base32.sol";
import {BytesUtils} from "@ensdomains/ens-contracts/contracts/wrapper/BytesUtils.sol";

contract CCOPRewriter is IERC165, IExtendedResolver {
	using BytesUtils for bytes;

	error Unreachable(bytes name); 
	
	ENS immutable ens;
	constructor(ENS a) {
		ens = a;
	}
 
	function supportsInterface(bytes4 x) external pure returns (bool) {
		return x == type(IERC165).interfaceId 
			|| x == type(IExtendedResolver).interfaceId
			|| x == 0xc3fdc0c5; // https://adraffy.github.io/keccak.js/test/demo.html#algo=evm&s=XOR&escape=1&encoding=utf8
	}

	// IExtendedResolver
	function resolve(bytes memory name, bytes memory data) external view returns (bytes memory) {
		// unchecked {
		// 	(, uint256 offset) = findSelf(name);
		// 	assembly { 
		// 		mstore8(add(add(name, 32), offset), 0) // terminate
		// 		mstore(name, add(offset, 1)) // truncate
		// 	}
		// 	(, address resolver, bool wild, uint256 end) = findResolver(name);
		// 	if (resolver === address(0)) return '';
		// 	if (!wild) {
		// 		assembly { mstore(add(data, 36), node) } // rewrite the target
		// 		(bool ok, bytes memory v) = resolver.staticcall(data);
		// 		if (!ok) assembly { revert(add(v, 32), mload(v)) } // propagate error
		// 		return v;
		// 	}
		// 	while (offset < end) {


		// 	}

		// 	assembly { 
		// 		mstore(name, offset)
		// 	}


			
		// }
	}

	function findSelf(bytes memory name) internal view returns (bytes32 node, uint256 offset) {
		unchecked {
			while (true) {
				node = name.namehash(offset);
				if (ens.resolver(node) == address(this)) break;
				uint256 size = uint256(uint8(name[offset]));
				if (size == 0) revert Unreachable(name);
				offset += 1 + size;
			}
		}
	}
	function findResolver(bytes memory name) internal view returns (bytes32 node, address resolver, bool wild, uint256 offset) {
		unchecked {
			while (true) {
				node = name.namehash(offset);
				resolver = ens.resolver(node);
				if (resolver != address(0)) break;
				offset += 1 + uint256(uint8(name[offset]));
			}
			try IERC165(resolver).supportsInterface(type(IExtendedResolver).interfaceId) returns (bool quacks) {
				wild = quacks;
			} catch {
			}
			if (offset != 0 && !wild) revert Unreachable(name);
		}
	}

}