// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Rescuable} from "contracts/misc/Rescuable.sol";
import {
  IERC1404,
  SUCCESS_CODE,
  SENDER_RESTRICTED_CODE,
  RECIPIENT_RESTRICTED_CODE,
  SUCCESS_MESSAGE,
  SENDER_RESTRICTED_MESSAGE,
  RECIPIENT_RESTRICTED_MESSAGE,
  UNKNOWN_MESSAGE
} from "contracts/interfaces/IERC1404.sol";
import {IVaultShareToken} from "contracts/interfaces/IVaultShareToken.sol";

/**  
 * @title VaultShareToken  
 * Tiêu_đề VaultShareToken  
 * @notice Role-gated ERC20 share token issued by `PortfolioVault`. Transfers  
 * @notice Token cổ_phần ERC20 được kiểm_soát bởi vai_trò, phát_hành bởi `PortfolioVault`. Các lần chuyển  
 *         are restricted to addresses holding `SHAREHOLDER_ROLE`; the vault  
 *         bị hạn_chế đối_với các địa_chỉ nắm_giữ `VAI_TRÒ_CỔ_ĐÔNG`; vault  
 *         holds `MINTER_ROLE` and `BURNER_ROLE` to issue and redeem shares.  
 *         nắm_giữ `VAI_TRÒ_ĐÚC` và `VAI_TRÒ_ĐỐT` để phát_hành và mua_lại cổ_phần.  
 * @dev Implements an ERC1404-style restriction interface  
 * @dev Triển_khai giao_diện hạn_chế kiểu ERC1404  
 *      (`detectTransferRestriction`/`messageForTransferRestriction`) so off-chain  
 *      (`phátHiệnHạnChếChuyển`/`thôngBáoChoHạnChếChuyển`) để người_dùng ngoài_chuỗi  
 *      consumers can surface a human-readable reason for blocked transfers.  
 *      có_thể hiển_thị lý_do có_thể_đọc_được cho các lần chuyển bị_chặn.  
 */  
// hợp_đồng VaultShareToken là ERC20, Rescuable, IVaultShareToken {  
contract VaultShareToken is ERC20, Rescuable, IVaultShareToken {  
  /// @inheritdoc IVaultShareToken  
  // Kế_thừa từ IVaultShareToken  
  // bytes32 public constant VAI_TRÒ_CỔ_ĐÔNG = keccak256("SHAREHOLDER_ROLE");  
  bytes32 public constant SHAREHOLDER_ROLE = keccak256("SHAREHOLDER_ROLE");  
  
  /// @inheritdoc IVaultShareToken  
  // Kế_thừa từ IVaultShareToken  
  // bytes32 public constant VAI_TRÒ_NGƯỜI_THÊM_DANH_SÁCH_TRẮNG = keccak256("WHITELISTER_ROLE");  
  bytes32 public constant WHITELISTER_ROLE = keccak256("WHITELISTER_ROLE");  
  
  /// @inheritdoc IVaultShareToken  
  // Kế_thừa từ IVaultShareToken  
  // bytes32 public constant VAI_TRÒ_ĐÚC = keccak256("MINTER_ROLE");  
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");  
  
  /// @inheritdoc IVaultShareToken  
  // Kế_thừa từ IVaultShareToken  
  // bytes32 public constant VAI_TRÒ_ĐỐT = keccak256("BURNER_ROLE");  
  bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");  
  
  // địa_chỉ private immutable _tàiSản;  
  address private immutable _asset;  
  // địa_chỉ private _vault;  
  address private _vault;  
  
  /**  
   * @notice Deploys the share token, wires up its role hierarchy, and grants the initial  
   * @notice Triển_khai token cổ_phần, thiết_lập hệ_thống_phân_cấp vai_trò, và cấp cho vault ban_đầu  
   *         vault `MINTER_ROLE` + `BURNER_ROLE`.  
   *         `VAI_TRÒ_ĐÚC` + `VAI_TRÒ_ĐỐT`.  
   * @param name_ ERC20 token name.  
   * @param name_ Tên token ERC20.  
   * @param symbol_ ERC20 token symbol.  
   * @param symbol_ Ký_hiệu token ERC20.  
   * @param initialGuardian Address that receives `GUARDIAN_ROLE` (controls all admin roles).  
   * @param initialGuardian Địa_chỉ nhận `VAI_TRÒ_NGƯỜI_GIÁM_HỘ` (kiểm_soát tất_cả vai_trò quản_trị).  
   * @param initialRecoveryAddress Address that rescued tokens are sent to (must be non-zero).  
   * @param initialRecoveryAddress Địa_chỉ mà token được giải_cứu được gửi đến (phải khác không).  
   * @param vault_ Initial vault contract address authorised to mint, burn, and hold shares.  
   * @param vault_ Địa_chỉ hợp_đồng vault ban_đầu được ủy_quyền để đúc, đốt, và nắm_giữ cổ_phần.  
   * @param asset_ The underlying asset address the vault settles in (used by `vault(asset)`).  
   * @param asset_ Địa_chỉ tài_sản cơ_bản mà vault thanh_toán bằng (dùng bởi `vault(tàiSản)`).  
   */  
  // constructor(  
  constructor(  
    // string bộ_nhớ tên_,  
    string memory name_,  
    // string bộ_nhớ ký_hiệu_,  
    string memory symbol_,  
    // địa_chỉ người_giám_hộ_ban_đầu,  
    address initialGuardian,  
    // địa_chỉ địaChỉKhôiPhụcBanĐầu,  
    address initialRecoveryAddress,  
    // địa_chỉ vault_,  
    address vault_,  
    // địa_chỉ tàiSản_  
    address asset_  
  // ) ERC20(tên_, ký_hiệu_) {  
  ) ERC20(name_, symbol_) {  
    // yêu_cầu(người_giám_hộ_ban_đầu != địa_chỉ(0), ĐịaChỉKhông());  
    require(initialGuardian != address(0), ZeroAddress());  
    // yêu_cầu(vault_ != địa_chỉ(0), ĐịaChỉKhông());  
    require(vault_ != address(0), ZeroAddress());  
    // yêu_cầu(tàiSản_ != địa_chỉ(0), ĐịaChỉKhông());  
    require(asset_ != address(0), ZeroAddress());  
  
    // _tàiSản = tàiSản_;  
    _asset = asset_;  
    // _vault = vault_;  
    _vault = vault_;  
  
    // _khởiTạoNgườiGiámHộ(người_giám_hộ_ban_đầu);  
    _initGuardian(initialGuardian);  
    // _khởiTạoĐịaChỉKhôiPhục(địaChỉKhôiPhụcBanĐầu);  
    _initRecoveryAddress(initialRecoveryAddress);  
    // _đặtQuảnTrịVaiTrò(VAI_TRÒ_NGƯỜI_THÊM_DANH_SÁCH_TRẮNG, VAI_TRÒ_NGƯỜI_GIÁM_HỘ);  
    _setRoleAdmin(WHITELISTER_ROLE, GUARDIAN_ROLE);  
    // _đặtQuảnTrịVaiTrò(VAI_TRÒ_CỔ_ĐÔNG, VAI_TRÒ_NGƯỜI_THÊM_DANH_SÁCH_TRẮNG);  
    _setRoleAdmin(SHAREHOLDER_ROLE, WHITELISTER_ROLE);  
    // _đặtQuảnTrịVaiTrò(VAI_TRÒ_ĐÚC, VAI_TRÒ_NGƯỜI_GIÁM_HỘ);  
    _setRoleAdmin(MINTER_ROLE, GUARDIAN_ROLE);  
    // _đặtQuảnTrịVaiTrò(VAI_TRÒ_ĐỐT, VAI_TRÒ_NGƯỜI_GIÁM_HỘ);  
    _setRoleAdmin(BURNER_ROLE, GUARDIAN_ROLE);  
    // _cấpVaiTrò(VAI_TRÒ_ĐÚC, vault_);  
    _grantRole(MINTER_ROLE, vault_);  
    // _cấpVaiTrò(VAI_TRÒ_ĐỐT, vault_);  
    _grantRole(BURNER_ROLE, vault_);  
    // _cấpVaiTrò(VAI_TRÒ_CỔ_ĐÔNG, vault_);  
    _grantRole(SHAREHOLDER_ROLE, vault_);  
  
    // phát_sự_kiện CậpNhậtVault(tàiSản_, vault_);  
    emit VaultUpdate(asset_, vault_);  
  // }  
  }  
  
  /// @inheritdoc IVaultShareToken  
  // Kế_thừa từ IVaultShareToken  
  // hàm vault(địa_chỉ tàiSản) bên_ngoài xem trả_về (địa_chỉ) {  
  function vault(address asset) external view returns (address) {  
    // trả_về tàiSản == _tàiSản ? _vault : địa_chỉ(0);  
    return asset == _asset ? _vault : address(0);  
  // }  
  }  
  
  /// @inheritdoc IVaultShareToken  
  // Kế_thừa từ IVaultShareToken  
  // hàm đặtVault(địa_chỉ vaultMới) bên_ngoài chỉVaiTrò(VAI_TRÒ_NGƯỜI_GIÁM_HỘ) {  
  function setVault(address newVault) external onlyRole(GUARDIAN_ROLE) {  
    // yêu_cầu(vaultMới != địa_chỉ(0), ĐịaChỉKhông());  
    require(newVault != address(0), ZeroAddress());  
  
    // Revoke mint/burn authority from the outgoing vault so an exploited old  
    // Thu_hồi quyền đúc/đốt từ vault đang_rời để vault cũ bị_khai_thác không_thể  
    // vault cannot mint or burn shares.  
    // đúc hoặc đốt cổ_phần.  
    // địa_chỉ vaultCũ = _vault;  
    address oldVault = _vault;  
    // _thuHồiVaiTrò(VAI_TRÒ_ĐÚC, vaultCũ);  
    _revokeRole(MINTER_ROLE, oldVault);  
    // _thuHồiVaiTrò(VAI_TRÒ_ĐỐT, vaultCũ);  
    _revokeRole(BURNER_ROLE, oldVault);  
  
    // _vault = vaultMới;  
    _vault = newVault;  
    // phát_sự_kiện CậpNhậtVault(_tàiSản, vaultMới);  
    emit VaultUpdate(_asset, newVault);  
  // }  
  }  
  
  /// @inheritdoc IVaultShareToken  
  // Kế_thừa từ IVaultShareToken  
  // hàm đúc(địa_chỉ đến, số_nguyên_không_dấu_256 số_lượng) bên_ngoài chỉVaiTrò(VAI_TRÒ_ĐÚC) {  
  function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {  
    // _đúc(đến, số_lượng);  
    _mint(to, amount);  
  // }  
  }  
  
  /// @inheritdoc IVaultShareToken  
  // Kế_thừa từ IVaultShareToken  
  // hàm đốt(địa_chỉ từ, số_nguyên_không_dấu_256 số_lượng) bên_ngoài chỉVaiTrò(VAI_TRÒ_ĐỐT) {  
  function burn(address from, uint256 amount) external onlyRole(BURNER_ROLE) {  
    // _đốt(từ, số_lượng);  
    _burn(from, amount);  
  // }  
  }  
  
  /// @inheritdoc IERC1404  
  // Kế_thừa từ IERC1404  
  // hàm phátHiệnHạnChếChuyển(địa_chỉ từ, địa_chỉ đến, số_nguyên_không_dấu_256) bên_ngoài xem trả_về (số_nguyên_không_dấu_8) {  
  function detectTransferRestriction(address from, address to, uint256) external view returns (uint8) {  
    // trả_về _phátHiệnHạnChếChuyển(từ, đến);  
    return _detectTransferRestriction(from, to);  
  // }  
  }

    // @inheritdoc IERC1404  
  // Kế_thừa từ IERC1404  
  // hàm thôngBáoChoHạnChếChuyển(số_nguyên_không_dấu_8 mãHạnChế) bên_ngoài thuần trả_về (string bộ_nhớ) {  
  function messageForTransferRestriction(uint8 restrictionCode) external pure returns (string memory) {  
    // nếu (mãHạnChế == MÃ_THÀNH_CÔNG) trả_về THÔNG_ĐIỆP_THÀNH_CÔNG;  
    if (restrictionCode == SUCCESS_CODE) return SUCCESS_MESSAGE;  
    // nếu (mãHạnChế == MÃ_NGƯỜI_GỬI_BỊ_HẠN_CHẾ) trả_về THÔNG_ĐIỆP_NGƯỜI_GỬI_BỊ_HẠN_CHẾ;  
    if (restrictionCode == SENDER_RESTRICTED_CODE) return SENDER_RESTRICTED_MESSAGE;  
    // nếu (mãHạnChế == MÃ_NGƯỜI_NHẬN_BỊ_HẠN_CHẾ) trả_về THÔNG_ĐIỆP_NGƯỜI_NHẬN_BỊ_HẠN_CHẾ;  
    if (restrictionCode == RECIPIENT_RESTRICTED_CODE) return RECIPIENT_RESTRICTED_MESSAGE;  
    // trả_về THÔNG_ĐIỆP_KHÔNG_XÁC_ĐỊNH;  
    return UNKNOWN_MESSAGE;  
  // }  
  }  
  
  /**  
   * @notice Advertises `IERC7575Share` (ERC-7575 share-to-vault lookup), `IERC1404`  
   * @notice Quảng_bá `IERC7575Share` (tra_cứu cổ_phần-sang-vault ERC-7575), `IERC1404`  
   *         (transfer restrictions), and `IERC20` interface support in addition to the  
   *         (hạn_chế chuyển), và hỗ_trợ giao_diện `IERC20` ngoài  
   *         standard `AccessControl` set.  
   *         bộ `AccessControl` tiêu_chuẩn.  
   * @dev The `0xf815c03d` selector is the hard-coded `IERC7575Share` interface id from the EIP.  
   * @dev Bộ_chọn `0xf815c03d` là id giao_diện `IERC7575Share` được mã_hóa_cứng từ EIP.  
   */  
  // hàm hỗTrợGiaoDiện(bytes4 idGiaoDiện) public xem ghi_đè trả_về (bool) {  
  function supportsInterface(bytes4 interfaceId) public view override returns (bool) {  
    // trả_về  
    return  
      // idGiaoDiện == 0xf815c03d ||  
      interfaceId == 0xf815c03d ||  
      // idGiaoDiện == type(IERC1404).interfaceId ||  
      interfaceId == type(IERC1404).interfaceId ||  
      // idGiaoDiện == type(IERC20).interfaceId ||  
      interfaceId == type(IERC20).interfaceId ||  
      // super.hỗTrợGiaoDiện(idGiaoDiện);  
      super.supportsInterface(interfaceId);  
  // }  
  }  
  
  /**  
   * @dev Enforces the shareholder gate on every transfer/mint/burn. Mint (`from == 0`) and  
   * @dev Thực_thi cổng cổ_đông trên mọi lần chuyển/đúc/đốt. Đúc (`từ == 0`) và  
   *      burn (`to == 0`) skip the corresponding side's role check so the vault can issue and  
   *      đốt (`đến == 0`) bỏ_qua kiểm_tra vai_trò của phía tương_ứng để vault có_thể phát_hành và  
   *      redeem shares without first being granted `SHAREHOLDER_ROLE`.  
   *      mua_lại cổ_phần mà không cần được cấp `VAI_TRÒ_CỔ_ĐÔNG` trước.  
   */  
  // hàm _cậpNhật(địa_chỉ từ, địa_chỉ đến, số_nguyên_không_dấu_256 giá_trị) nội_bộ ghi_đè {  
  function _update(address from, address to, uint256 value) internal override {  
    // số_nguyên_không_dấu_8 hạnChế = _phátHiệnHạnChếChuyển(từ, đến);  
    uint8 restriction = _detectTransferRestriction(from, to);  
    // nếu (hạnChế == MÃ_NGƯỜI_GỬI_BỊ_HẠN_CHẾ) hoàn_tác CổĐôngBịHạnChế(từ);  
    if (restriction == SENDER_RESTRICTED_CODE) revert ShareholderRestricted(from);  
    // nếu (hạnChế == MÃ_NGƯỜI_NHẬN_BỊ_HẠN_CHẾ) hoàn_tác CổĐôngBịHạnChế(đến);  
    if (restriction == RECIPIENT_RESTRICTED_CODE) revert ShareholderRestricted(to);  
  
    // super._cậpNhật(từ, đến, giá_trị);  
    super._update(from, to, value);  
  // }  
  }  
  
  /**  
   * @dev Shared shareholder-eligibility rule backing both the ERC-1404 read path  
   * @dev Quy_tắc đủ_điều_kiện cổ_đông chung hỗ_trợ cả đường_dẫn đọc ERC-1404  
   *      (`detectTransferRestriction`) and the enforcement path (`_update`). Mint  
   *      (`phátHiệnHạnChếChuyển`) và đường_dẫn thực_thi (`_cậpNhật`). Đúc  
   *      (`from == 0`) and burn (`to == 0`) skip the corresponding side's check.  
   *      (`từ == 0`) và đốt (`đến == 0`) bỏ_qua kiểm_tra của phía tương_ứng.  
   */  
  // hàm _phátHiệnHạnChếChuyển(địa_chỉ từ, địa_chỉ đến) riêng_tư xem trả_về (số_nguyên_không_dấu_8) {  
  function _detectTransferRestriction(address from, address to) private view returns (uint8) {  
    // nếu (từ != địa_chỉ(0) && !cóVaiTrò(VAI_TRÒ_CỔ_ĐÔNG, từ)) trả_về MÃ_NGƯỜI_GỬI_BỊ_HẠN_CHẾ;  
    if (from != address(0) && !hasRole(SHAREHOLDER_ROLE, from)) return SENDER_RESTRICTED_CODE;  
    // nếu (đến != địa_chỉ(0) && !cóVaiTrò(VAI_TRÒ_CỔ_ĐÔNG, đến)) trả_về MÃ_NGƯỜI_NHẬN_BỊ_HẠN_CHẾ;  
    if (to != address(0) && !hasRole(SHAREHOLDER_ROLE, to)) return RECIPIENT_RESTRICTED_CODE;  
    // trả_về MÃ_THÀNH_CÔNG;  
    return SUCCESS_CODE;  
  // }  
  }
}
