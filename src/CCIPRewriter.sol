/// @author raffy.eth
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// interfaces
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ENS} from "@ensdomains/ens-contracts/contracts/registry/ENS.sol";
import {IExtendedResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IExtendedResolver.sol";
import {IMulticallable} from "@ensdomains/ens-contracts/contracts/resolvers/IMulticallable.sol";
import {IReverseRegistrar} from "@ensdomains/ens-contracts/contracts/reverseRegistrar/IReverseRegistrar.sol";

// libraries
import {Base32} from "./Base32.sol";
import {BytesUtils} from "@ensdomains/ens-contracts/contracts/wrapper/BytesUtils.sol";

// https://eips.ethereum.org/EIPS/eip-3668
error OffchainLookup(address from, string[] urls, bytes request, bytes4 callback, bytes carry);

contract CCIPRewriter is IERC165, IExtendedResolver {
	using BytesUtils for bytes;

	error Unreachable(bytes name); 
	error InvalidBase32(bytes name);

	ENS immutable _ens;
	constructor(ENS ens) {
		_ens = ens;
		_rr().claim(msg.sender);
	}

	function _rr() internal view returns (IReverseRegistrar) {
		// https://adraffy.github.io/keccak.js/test/demo.html#algo=namehash&s=addr.reverse&escape=1&encoding=utf8
		return IReverseRegistrar(_ens.owner(0x91d1777781884d03a6757a803996e38de2a42967fb37eeaca72729271025a9e2));
	}
 
	function supportsInterface(bytes4 x) external pure returns (bool) {
		return x == type(IERC165).interfaceId 
			|| x == type(IExtendedResolver).interfaceId
			|| x == 0x87f60257; // https://adraffy.github.io/keccak.js/test/demo.html#algo=evm&s=CCIPRewriter&escape=1&encoding=utf8
	}

	// reflect into the reverse record
	function _resolveBasename(bytes32, bytes memory data) internal view returns (bytes memory) {
		bytes32 node = _rr().node(address(this));
		address resolver = _ens.resolver(node);
		if (resolver != address(0)) {
			assembly { mstore(add(data, 36), node) }
			(bool ok, bytes memory v) = resolver.staticcall(data);
			if (ok) return v;
		}
		return new bytes(64);
	}

	// IExtendedResolver
	function resolve(bytes memory name, bytes memory data) external view returns (bytes memory v) {
		unchecked {
			// look for [name].{base32}.[basename]
			(bytes32 node, uint256 offset, uint256 offset2) = _findSelf(name);
			if (offset == 0 || offset2 == 0) return _resolveBasename(node, data);
			uint256 name_ptr;
			assembly { name_ptr := add(add(name, 32), offset2) }
			offset2 += 1;
			(bool valid, bytes memory url) = Base32.decode(name_ptr + 1, offset - offset2);
			if (!valid) revert InvalidBase32(name);
			string[] memory urls = new string[](1);
			urls[0] = string(url);
			assembly { 
				mstore8(name_ptr, 0) // terminate
				mstore(name, offset2) // truncate
			}
			(, address resolver, bool wild, ) = _findResolver(name);
			if (resolver == address(0)) return new bytes(64);
			node = name.namehash(0);
			assembly { mstore(add(data, 36), node) } // rewrite the target
			bool ok;
			if (wild) {
				(ok, v) = resolver.staticcall(abi.encodeCall(IExtendedResolver.resolve, (name, data)));
				if (ok) {
					v = abi.decode(v, (bytes));
				} else {
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

	function _findSelf(bytes memory name) internal view returns (bytes32 node, uint256 offset, uint256 offset2) {
		unchecked {
			while (true) {
				node = name.namehash(offset);
				if (_ens.resolver(node) == address(this)) break;
				uint256 size = uint256(uint8(name[offset]));
				if (size == 0) revert Unreachable(name);
				offset2 = offset;
				offset += 1 + size;
			}
		}
	}
	function _findResolver(bytes memory name) internal view returns (bytes32 node, address resolver, bool wild, uint256 offset) {
		unchecked {
			while (true) {
				node = name.namehash(offset);
				resolver = _ens.resolver(node);
				if (resolver != address(0)) break;
				offset += 1 + uint256(uint8(name[offset]));
			}
 			try IERC165(resolver).supportsInterface{gas: 30000}(type(IExtendedResolver).interfaceId) returns (bool quacks) {
				wild = quacks;
			} catch {
			}
			if (offset != 0 && !wild) revert Unreachable(name);
		}
	}

}
