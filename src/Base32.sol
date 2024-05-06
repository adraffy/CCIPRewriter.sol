/// @author raffy.eth
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

library Base32 {

	function decode(uint256 pos, uint256 len) internal pure returns (bool ok, bytes memory) {
		unchecked {
			uint256 n = (len * 5) >> 3;
			bytes memory v = new bytes(n);
			uint256 clip;
			uint256 ammo;
			uint256 bits;
			uint256 word;
			for (uint256 i; i < n; i += 1) {
				while (bits < 8) {
					if (ammo == 0) {
						ammo = 32;
						assembly { clip := mload(pos) }
						pos += ammo;
					}
					uint256 x = _indexOf(clip >> 248);
					if (x == 32) return (false, '');
					clip <<= 8;
					ammo -= 1;
					word = (word << 5) | x;
					bits += 5;
				}
				v[i] = bytes1(uint8(word >> (bits -= 8)));
			}
			return (true, v);
		}
	}

	// "abcdefghijklmnopqrstuvwxyz234567";
	function _indexOf(uint256 x) internal pure returns (uint256) {
		if (x >= 97 && x <= 122) {
			return x - 97;
		} else if (x >= 50 && x <= 55) {
			return x - 24; // 50-26
		} else {
			return 32;
		}
	}

}
