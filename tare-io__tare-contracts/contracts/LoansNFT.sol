// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC721Utils} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {ILoansNFT, ILockable} from "contracts/interfaces/ILoansNFT.sol";
import {IGuardianAccessControl} from "contracts/misc/interfaces/IGuardianAccessControl.sol";

/**  
 * @title LoansNFT  
 * Tiêu_đề LoansNFT  
 * @notice ERC721Enumerable loan NFT with ERC-5753-compatible locking.  
 * @notice NFT khoản_vay ERC721Enumerable với khóa tương_thích ERC-5753.  
 */  
// hợp_đồng LoansNFT là ILoansNFT, ERC721Enumerable {  
contract LoansNFT is ILoansNFT, ERC721Enumerable {  
  // địa_chỉ public immutable HỢP_ĐỒNG_KHOẢN_VAY;  
  address public immutable LOANS_CONTRACT;  
  
  /// @dev Cached from the Loans contract to avoid repeated external calls.  
  // Được lưu_vào_bộ_nhớ_đệm từ hợp_đồng Loans để tránh các lần gọi bên_ngoài lặp_lại.  
  // bytes32 public immutable VAI_TRÒ_QUẢN_TRỊ;  
  bytes32 public immutable ADMIN_ROLE;  
  
  /// @dev Cached from the Loans contract to avoid repeated external calls.  
  // Được lưu_vào_bộ_nhớ_đệm từ hợp_đồng Loans để tránh các lần gọi bên_ngoài lặp_lại.  
  // bytes32 public immutable VAI_TRÒ_NGƯỜI_GIÁM_HỘ;  
  bytes32 public immutable GUARDIAN_ROLE;  
  
  // string private _uriCơSởKhoảnVay;  
  string private _loansBaseURI;  
  // mapping(số_nguyên_không_dấu_256 mãToken => địa_chỉ người_mở_khóa) private _người_mở_khóa_s;  
  mapping(uint256 tokenId => address unlocker) private _unlockers;  
  
  /// @inheritdoc ILoansNFT  
  // Kế_thừa từ ILoansNFT  
  // mapping(địa_chỉ tài_khoản => số_nguyên_không_dấu_256 số_thứ_tự) public số_thứ_tự_sở_hữu_s;  
  mapping(address account => uint256 nonce) public ownershipNonce;  
  
  // constructor(  
  constructor(  
    // địa_chỉ hợpĐồngKhoảnVay,  
    address loansContract,  
    // string bộ_nhớ tênBộSưuTập,  
    string memory collectionName,  
    // string bộ_nhớ uriCơSở  
    string memory baseURI  
  // ) ERC721(tênBộSưuTập, "LOAN") {  
  ) ERC721(collectionName, "LOAN") {  
    // yêu_cầu(hợpĐồngKhoảnVay != địa_chỉ(0), KhôngĐượcPhép());  
    require(loansContract != address(0), Unauthorized());  
    // HỢP_ĐỒNG_KHOẢN_VAY = hợpĐồngKhoảnVay;  
    LOANS_CONTRACT = loansContract;  
    // VAI_TRÒ_QUẢN_TRỊ = IGuardianAccessControl(hợpĐồngKhoảnVay).VAI_TRÒ_QUẢN_TRỊ();  
    ADMIN_ROLE = IGuardianAccessControl(loansContract).ADMIN_ROLE();  
    // VAI_TRÒ_NGƯỜI_GIÁM_HỘ = IGuardianAccessControl(hợpĐồngKhoảnVay).VAI_TRÒ_NGƯỜI_GIÁM_HỘ();  
    GUARDIAN_ROLE = IGuardianAccessControl(loansContract).GUARDIAN_ROLE();  
    // _uriCơSởKhoảnVay = uriCơSở;  
    _loansBaseURI = baseURI;  
    // phát_sự_kiện URICơSởĐãCậpNhật(uriCơSở);  
    emit BaseURIUpdated(baseURI);  
  // }  
  }  
  
  /// @inheritdoc ILoansNFT  
  // Kế_thừa từ ILoansNFT  
  // hàm đúc(địa_chỉ đến, số_nguyên_không_dấu_256 mãToken) bên_ngoài {  
  function mint(address to, uint256 tokenId) external {  
    // yêu_cầu(msg.người_gửi == HỢP_ĐỒNG_KHOẢN_VAY, KhôngĐượcPhép());  
    require(msg.sender == LOANS_CONTRACT, Unauthorized());  
  
    // _đúc(đến, mãToken);  
    _mint(to, tokenId);  
  // }  
  }  
  
  /// @inheritdoc ILoansNFT  
  // Kế_thừa từ ILoansNFT  
  // hàm đặtURICơSở(string dữ_liệu_gọi uriCơSởMới) bên_ngoài {  
  function setBaseURI(string calldata newBaseURI) external {  
    // yêu_cầu(IGuardianAccessControl(HỢP_ĐỒNG_KHOẢN_VAY).cóVaiTrò(VAI_TRÒ_QUẢN_TRỊ, msg.người_gửi), KhôngĐượcPhép());  
    require(IGuardianAccessControl(LOANS_CONTRACT).hasRole(ADMIN_ROLE, msg.sender), Unauthorized());  
  
    // _uriCơSởKhoảnVay = uriCơSởMới;  
    _loansBaseURI = newBaseURI;  
    // phát_sự_kiện URICơSởĐãCậpNhật(uriCơSởMới);  
    emit BaseURIUpdated(newBaseURI);  
  // }  
  }  
  
  /// @inheritdoc ILoansNFT  
  // Kế_thừa từ ILoansNFT  
  // hàm chuyểnBắtBuộc(địa_chỉ từ, địa_chỉ đến, số_nguyên_không_dấu_256 mãToken) bên_ngoài {  
  function forceTransfer(address from, address to, uint256 tokenId) external {  
    // yêu_cầu(IGuardianAccessControl(HỢP_ĐỒNG_KHOẢN_VAY).cóVaiTrò(VAI_TRÒ_NGƯỜI_GIÁM_HỘ, msg.người_gửi), KhôngĐượcPhép());  
    require(IGuardianAccessControl(LOANS_CONTRACT).hasRole(GUARDIAN_ROLE, msg.sender), Unauthorized());  
  
    // địa_chỉ chủSởHữuHiệnTại = _yêuCầuSởHữu(mãToken);  
    address currentOwner = _requireOwned(tokenId);  
    // yêu_cầu(từ == chủSởHữuHiệnTại, TừKhôngHợpLệ());  
    require(from == currentOwner, InvalidFrom());  
    // yêu_cầu(đến != địa_chỉ(0), ĐếnKhôngHợpLệ());  
    require(to != address(0), InvalidTo());  
    // yêu_cầu(_người_mở_khóa_s[mãToken] == địa_chỉ(0), TokenĐãKhóa());  
    require(_unlockers[tokenId] == address(0), TokenLocked());  
  
    // Pass `address(0)` as `auth` to bypass the ERC721 approval check. The  
    // Truyền `địa_chỉ(0)` làm `xác_thực` để bỏ_qua kiểm_tra phê_duyệt ERC721. Phần  
    // override still runs (bumping ownership nonces and emitting `Transfer`).  
    // ghi_đè vẫn chạy (tăng số_thứ_tự sở_hữu và phát `Chuyển`).  
    // _cậpNhật(đến, mãToken, địa_chỉ(0));  
    _update(to, tokenId, address(0));  
  
    // Ensure `to` can receive ERC-721s, mirroring the safe-transfer rescue path.  
    // Đảm_bảo `đến` có_thể nhận ERC-721, phản_chiếu đường_dẫn giải_cứu chuyển_an_toàn.  
    // ERC721Utils.kiểmTraNhậnERC721(msg.người_gửi, từ, đến, mãToken, "");  
    ERC721Utils.checkOnERC721Received(msg.sender, from, to, tokenId, "");  
  
    // phát_sự_kiện ChuyểnBắtBuộc(từ, đến, mãToken);  
    emit ForceTransfer(from, to, tokenId);  
  // }  
  }  
  
  /**  
   * @inheritdoc ILockable  
   * Kế_thừa từ ILockable  
   * @dev Authorization is intentionally broader than the ERC-5753 reference  
   * @dev Ủy_quyền được cố_ý rộng hơn so với triển_khai tham_chiếu ERC-5753  
   *      implementation (owner or operator): per-token approved addresses may also  
   *      (chủ_sở_hữu hoặc người_vận_hành): các địa_chỉ được phê_duyệt theo từng token cũng có_thể  
   *      lock. This lets integrators such as `LoansExchange` lock listed loans with  
   *      khóa. Điều này cho phép các bên_tích_hợp như `LoansExchange` khóa các khoản_vay được_liệt_kê với  
   *      narrow per-token approvals instead of requiring `setApprovalForAll`.  
   *      các phê_duyệt hẹp theo từng token thay_vì yêu_cầu `đặtPhêDuyệtChoTất_cả`.  
   */  
  // hàm khóa(địa_chỉ người_mở_khóa, số_nguyên_không_dấu_256 id) bên_ngoài {  
  function lock(address unlocker, uint256 id) external {  
    // địa_chỉ chủSởHữuToken = chủSởHữuCủa(id);  
    address tokenOwner = ownerOf(id);  
  
    // yêu_cầu(người_mở_khóa != địa_chỉ(0), NguờiMởKhóaKhôngHợpLệ());  
    require(unlocker != address(0), InvalidUnlocker());  
    // yêu_cầu(_người_mở_khóa_s[id] == địa_chỉ(0), ĐãKhóaRồi());  
    require(_unlockers[id] == address(0), AlreadyLocked());  
    // yêu_cầu(_đãĐượcỦyQuyền(chủSởHữuToken, msg.người_gửi, id), KhôngĐượcPhép());  
    require(_isAuthorized(tokenOwner, msg.sender, id), Unauthorized());  
  
    // Clear approval  
    // Xóa phê_duyệt  
    // _phêDuyệt(địa_chỉ(0), id, địa_chỉ(0), false);  
    _approve(address(0), id, address(0), false);  
    // _người_mở_khóa_s[id] = người_mở_khóa;  
    _unlockers[id] = unlocker;  
  
    // phát_sự_kiện Khóa(người_mở_khóa, id);  
    emit Lock(unlocker, id);  
  // }  
  }

   /// @inheritdoc ILockable  
  // Kế_thừa từ ILockable  
  // hàm mởKhóa(số_nguyên_không_dấu_256 id) bên_ngoài {  
  function unlock(uint256 id) external {  
    // _yêuCầuSởHữu(id);  
    _requireOwned(id);  
    // yêu_cầu(msg.người_gửi == _người_mở_khóa_s[id], KhôngPhảiNgườiMởKhóa());  
    require(msg.sender == _unlockers[id], NotUnlocker());  
  
    // delete _người_mở_khóa_s[id];  
    delete _unlockers[id];  
  
    // phát_sự_kiện MởKhóa(id);  
    emit Unlock(id);  
  // }  
  }  
  
  /// @inheritdoc ILockable  
  // Kế_thừa từ ILockable  
  // hàm lấyĐãKhóa(số_nguyên_không_dấu_256 mãToken) public xem trả_về (địa_chỉ người_mở_khóa) {  
  function getLocked(uint256 tokenId) public view returns (address unlocker) {  
    // _yêuCầuSởHữu(mãToken);  
    _requireOwned(tokenId);  
    // trả_về _người_mở_khóa_s[mãToken];  
    return _unlockers[tokenId];  
  // }  
  }  
  
  /// @inheritdoc ILoansNFT  
  // Kế_thừa từ ILoansNFT  
  // hàm chủSởHữuVàNgườiMởKhóa(số_nguyên_không_dấu_256 mãToken) bên_ngoài xem trả_về (địa_chỉ chủ_sở_hữu, địa_chỉ người_mở_khóa) {  
  function ownerAndUnlocker(uint256 tokenId) external view returns (address owner, address unlocker) {  
    // chủ_sở_hữu = _yêuCầuSởHữu(mãToken);  
    owner = _requireOwned(tokenId);  
    // người_mở_khóa = _người_mở_khóa_s[mãToken];  
    unlocker = _unlockers[tokenId];  
  // }  
  }  
  
  /// @inheritdoc ERC721  
  // Kế_thừa từ ERC721  
  // hàm phêDuyệt(địa_chỉ đến, số_nguyên_không_dấu_256 mãToken) public ghi_đè(ERC721, IERC721) {  
  function approve(address to, uint256 tokenId) public override(ERC721, IERC721) {  
    // yêu_cầu(_người_mở_khóa_s[mãToken] == địa_chỉ(0), TokenĐãKhóa());  
    require(_unlockers[tokenId] == address(0), TokenLocked());  
    // super.phêDuyệt(đến, mãToken);  
    super.approve(to, tokenId);  
  // }  
  }  
  
  /// @inheritdoc ERC721  
  // Kế_thừa từ ERC721  
  // hàm lấyĐãPhêDuyệt(số_nguyên_không_dấu_256 mãToken) public xem ghi_đè(ERC721, IERC721) trả_về (địa_chỉ) {  
  function getApproved(uint256 tokenId) public view override(ERC721, IERC721) returns (address) {  
    // _yêuCầuSởHữu(mãToken);  
    _requireOwned(tokenId);  
  
    // địa_chỉ người_mở_khóa = _người_mở_khóa_s[mãToken];  
    address unlocker = _unlockers[tokenId];  
    // nếu (người_mở_khóa != địa_chỉ(0)) {  
    if (unlocker != address(0)) {  
      // trả_về người_mở_khóa;  
      return unlocker;  
    // }  
    }  
  
    // trả_về super._lấyĐãPhêDuyệt(mãToken);  
    return super._getApproved(tokenId);  
  // }  
  }  
  
  /**  
   * @inheritdoc IERC165  
   * Kế_thừa từ IERC165  
   * @dev Advertises `ILockable` (ERC-5753) support in addition to the standard ERC721 set.  
   * @dev Quảng_cáo hỗ_trợ `ILockable` (ERC-5753) ngoài tập_hợp ERC721 tiêu_chuẩn.  
   */  
  // hàm hỗTrợGiaoThức(bytes4 mãGiaoThức) public xem ghi_đè(ERC721Enumerable, IERC165) trả_về (bool) {  
  function supportsInterface(bytes4 interfaceId) public view override(ERC721Enumerable, IERC165) returns (bool) {  
    // trả_về mãGiaoThức == type(ILockable).mãGiaoThức || super.hỗTrợGiaoThức(mãGiaoThức);  
    return interfaceId == type(ILockable).interfaceId || super.supportsInterface(interfaceId);  
  // }  
  }  
  
  /**  
   * @dev Returns the base URI prefix used by `tokenURI`. Settable by admin via `setBaseURI`.  
   * @dev Trả_về tiền_tố URI cơ_sở được dùng bởi `tokenURI`. Có_thể đặt bởi quản_trị_viên qua `đặtURICơSở`.  
   */  
  // hàm _uriCơSở() nội_bộ xem ghi_đè trả_về (string bộ_nhớ) {  
  function _baseURI() internal view override returns (string memory) {  
    // trả_về _uriCơSởKhoảnVay;  
    return _loansBaseURI;  
  // }  
  }  
  
  /// @inheritdoc ERC721Enumerable  
  // Kế_thừa từ ERC721Enumerable  
  // hàm _cậpNhật(địa_chỉ đến, số_nguyên_không_dấu_256 mãToken, địa_chỉ ủyQuyền) nội_bộ ghi_đè trả_về (địa_chỉ chủSởHữuTrước) {  
  function _update(address to, uint256 tokenId, address auth) internal override returns (address previousOwner) {  
    // địa_chỉ người_mở_khóa = _người_mở_khóa_s[mãToken];  
    address unlocker = _unlockers[tokenId];  
    // địa_chỉ từ = _chủSởHữuCủa(mãToken);  
    address from = _ownerOf(tokenId);  
  
    // bool đãKhóa = từ != địa_chỉ(0) && người_mở_khóa != địa_chỉ(0);  
    bool isLocked = from != address(0) && unlocker != address(0);  
    // nếu (đãKhóa && ủyQuyền != người_mở_khóa) {  
    if (isLocked && auth != unlocker) {  
      // hoàn_tác TokenĐãKhóa();  
      revert TokenLocked();  
    // }  
    }  
  
    // Bump per-address ownership nonce so external integrators can detect any  
    // Tăng số_thứ_tự sở_hữu theo từng địa_chỉ để các bên_tích_hợp bên_ngoài có_thể phát_hiện bất_kỳ  
    // change to the NFT ownership set of a given address. The zero address is  
    // thay_đổi nào đối_với tập_hợp sở_hữu NFT của một địa_chỉ nhất_định. Địa_chỉ không là  
    // skipped (mint's `from`, burn's `to`) because no consumer reads that slot.  
    // bỏ_qua (`từ` của đúc, `đến` của đốt) vì không có người_dùng nào đọc ô đó.  
    // unchecked {  
    unchecked {  
      // nếu (từ != địa_chỉ(0)) ++số_thứ_tự_sở_hữu[từ];  
      if (from != address(0)) ++ownershipNonce[from];  
      // nếu (đến != địa_chỉ(0)) ++số_thứ_tự_sở_hữu[đến];  
      if (to != address(0)) ++ownershipNonce[to];  
    // }  
    }  
  
    // When the unlocker is transferring a locked token, bypass the standard  
    // Khi người_mở_khóa đang chuyển một token đã_khóa, bỏ_qua kiểm_tra phê_duyệt ERC-721 tiêu_chuẩn  
    // ERC-721 approval check (pass address(0) as auth) because the unlocker  
    // (truyền địa_chỉ(0) làm ủyQuyền) vì người_mở_khóa  
    // is not set via the normal approve() storage slot.  
    // không được đặt qua ô lưu_trữ phêDuyệt() thông_thường.  
    // chủSởHữuTrước = super._cậpNhật(đến, mãToken, đãKhóa ? địa_chỉ(0) : ủyQuyền);  
    previousOwner = super._update(to, tokenId, isLocked ? address(0) : auth);  
  
    // nếu (chủSởHữuTrước != địa_chỉ(0) && người_mở_khóa != địa_chỉ(0)) {  
    if (previousOwner != address(0) && unlocker != address(0)) {  
      // delete _người_mở_khóa_s[mãToken];  
      delete _unlockers[tokenId];  
      // phát_sự_kiện MởKhóa(mãToken);  
      emit Unlock(tokenId);  
    // }  
    }  
  // }  
  }
}
