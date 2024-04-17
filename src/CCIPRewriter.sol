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

// https://eips.ethereum.org/EIPS/eip-3668
error OffchainLookup(address from, string[] urls, bytes request, bytes4 callback, bytes carry);

contract CCIPRewriter is IERC165, IExtendedResolver {
	using BytesUtils for bytes;

	error Unreachable(bytes name); 
	error InvalidBase32(bytes name);
	
	ENS immutable ens;
	constructor(ENS _ens) {
		ens = _ens;
	}
 
	function supportsInterface(bytes4 x) external pure returns (bool) {
		return x == type(IERC165).interfaceId 
			|| x == type(IExtendedResolver).interfaceId
			|| x == 0x87f60257; // https://adraffy.github.io/keccak.js/test/demo.html#algo=evm&s=CCIPRewriter&escape=1&encoding=utf8
	}

	// IExtendedResolver
	function resolve(bytes memory name, bytes memory data) external view returns (bytes memory v) {
		unchecked {
			(, uint256 offset, uint256 size) = _findSelf(name);
			offset -= size;	
			uint256 name_ptr;
			assembly { name_ptr := add(add(name, 32), offset) }
			(bool valid, bytes memory url) = Base32.decode(name_ptr, size);
			if (!valid) revert InvalidBase32(name);
			string[] memory urls = new string[](1);
			urls[0] = string(url);
			assembly { 
				mstore8(sub(name_ptr, 1), 0) // terminate
				mstore(name, offset) // truncate
			}
			(, address resolver, bool wild, ) = _findResolver(name);
			if (resolver == address(0)) return '';
			bytes32 node = name.namehash(0);
			assembly { mstore(add(data, 36), node) } // rewrite the target
			bool ok;
			if (wild) {
				(ok, v) = resolver.staticcall(abi.encodeCall(IExtendedResolver.resolve, (name, data)));
				if (!ok) {
					if (bytes4(v) != OffchainLookup.selector) assembly { revert(add(v, 32), mload(v)) }
					assembly {
						mstore(add(v, 4), sub(mload(v), 4)) 
						v := add(v, 4)
					}
					(address sender, , bytes memory request, bytes4 callback, bytes memory carry) = abi.decode(v, (address, string[], bytes, bytes4, bytes));
					revert OffchainLookup(address(this), urls, request, this.resolveCallback.selector, abi.encode(sender, callback, carry));
				}
			} else {
				(ok, v) = resolver.staticcall(data);
				if (!ok) assembly { revert(add(v, 32), mload(v)) } // propagate error
			}
		}
	}

	function resolveCallback(bytes calldata response, bytes calldata extra) external view returns (bytes memory) {
		(address sender, bytes4 callback, bytes memory carry) = abi.decode(extra, (address, bytes4, bytes));
		(bool ok, bytes memory v) = sender.staticcall(abi.encodeWithSelector(callback, response, carry));
		if (!ok) assembly { revert(add(v, 32), mload(v)) }
		assembly { return(add(v, 32), mload(v)) }
	}

	function _findSelf(bytes memory name) internal view returns (bytes32 node, uint256 offset, uint256 size) {
		unchecked {
			while (true) {
				node = name.namehash(offset);
				if (ens.resolver(node) == address(this)) break;
				size = uint256(uint8(name[offset]));
				if (size == 0) revert Unreachable(name);
				offset += 1 + size;
			}
		}
	}
	function _findResolver(bytes memory name) internal view returns (bytes32 node, address resolver, bool wild, uint256 offset) {
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