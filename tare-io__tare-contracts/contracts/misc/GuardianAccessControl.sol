// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {IGuardianAccessControl} from "contracts/misc/interfaces/IGuardianAccessControl.sol";

/**  
 * @title GuardianAccessControl  
 * @title KiểmSoátTruyCapGuardian  
 * @notice Base access-control contract providing a two-tier guardian / admin  
 * @notice Hợp_đồng kiểm_soát_truy_cập cơ sở cung cấp mô hình vai trò hai tầng guardian / admin  
 *         role model on top of OpenZeppelin AccessControl.  
 *         trên nền tảng OpenZeppelin AccessControl.  
 *         Guardian is the role-admin for all roles.  
 *         Guardian là role-admin cho tất cả các vai trò.  
 *         Includes OZ Pausable with pause() gated to admin/guardian and  
 *         Bao gồm OZ Pausable với pause() được giới hạn cho admin/guardian và  
 *         unpause() restricted to guardian only.  
 *         unpause() chỉ dành riêng cho guardian.  
 */  
// hợp_đồng_trừu_tượng KiểmSoátTruyCapGuardian kế_thừa KiểmSoátTruyCap, TạmDừng, IKiểmSoátTruyCapGuardian {  
abstract contract GuardianAccessControl is AccessControl, Pausable, IGuardianAccessControl {  
  /// @inheritdoc IGuardianAccessControl  
  /// @inheritdoc (kế thừa tài liệu từ) IGuardianAccessControl  
  // bytes32 công_khai hằng_số VAI_TRÒ_GUARDIAN = keccak256("GUARDIAN_ROLE");  
  bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");  
  
  /// @inheritdoc IGuardianAccessControl  
  /// @inheritdoc (kế thừa tài liệu từ) IGuardianAccessControl  
  // bytes32 công_khai hằng_số VAI_TRÒ_ADMIN = keccak256("ADMIN_ROLE");  
  bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");  
  
  /// @inheritdoc IGuardianAccessControl  
  /// @inheritdoc (kế thừa tài liệu từ) IGuardianAccessControl  
  // bytes32 công_khai hằng_số VAI_TRÒ_PAUSER = keccak256("PAUSER_ROLE");  
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");  
  
  /// @dev Number of accounts holding `GUARDIAN_ROLE`. Used to enforce the  
  /// @dev Số lượng tài khoản nắm giữ `GUARDIAN_ROLE`. Dùng để thực thi  
  ///      at-least-one-guardian invariant on role revocation.  
  ///      bất_biến ít_nhất_một_guardian khi thu hồi vai trò.  
  // số_nguyên_không_dấu_256 nội_bộ sốLượngGuardian;  
  uint256 internal guardianCount;  
  
  /// @notice Restricts access to `ADMIN_ROLE` or `GUARDIAN_ROLE` holders.  
  /// @notice Giới hạn truy cập cho những người nắm giữ `ADMIN_ROLE` hoặc `GUARDIAN_ROLE`.  
  // bộ_sửa_đổi chỉDànhChoAdminHoặcGuardian() {  
  modifier onlyAdminOrGuardian() {  
    // yêu_cầu(_làAdminHoặcGuardian(msg.người_gửi), TàiKhoảnKiểmSoátTruyCapKhôngĐượcPhép(msg.người_gửi, VAI_TRÒ_ADMIN));  
    require(_isAdminOrGuardian(msg.sender), AccessControlUnauthorizedAccount(msg.sender, ADMIN_ROLE));  
    // _; (tiếp_tục_thực_thi_hàm)  
    _;  
  }  

 /**  
   * @notice Allows a guardian to update the role-admin of any role except `GUARDIAN_ROLE`.  
   * @notice Cho phép một guardian cập nhật role-admin của bất kỳ vai trò nào ngoại trừ `GUARDIAN_ROLE`.  
   * @param role The role whose admin is being changed.  
   * @param role Vai trò có admin đang được thay đổi.  
   * @param adminRole The new admin role.  
   * @param adminRole Vai trò admin mới.  
   */  
  // hàm đặtAdminVaiTrò(bytes32 vai_trò, bytes32 adminVaiTrò) bên_ngoài chỉVaiTrò(VAI_TRÒ_GUARDIAN) {  
  function setRoleAdmin(bytes32 role, bytes32 adminRole) external onlyRole(GUARDIAN_ROLE) {  
    // nếu (vai_trò == VAI_TRÒ_GUARDIAN) hoàn_tác KhôngThểThayĐổiAdminGuardian();  
    if (role == GUARDIAN_ROLE) revert CannotChangeGuardianAdmin();  
    // _đặtAdminVaiTrò(vai_trò, adminVaiTrò);  
    _setRoleAdmin(role, adminRole);  
  }  
  
  /// @notice Pauses the contract. Callable by admin, guardian, or pauser.  
  /// @notice Tạm dừng hợp đồng. Có thể gọi bởi admin, guardian, hoặc pauser.  
  // hàm tạmDừng() bên_ngoài ảo {  
  function pause() external virtual {  
    // yêu_cầu(  
    require(  
      // _làAdminHoặcGuardian(msg.người_gửi) || cóVaiTrò(VAI_TRÒ_PAUSER, msg.người_gửi),  
      _isAdminOrGuardian(msg.sender) || hasRole(PAUSER_ROLE, msg.sender),  
      // TàiKhoảnKiểmSoátTruyCapKhôngĐượcPhép(msg.người_gửi, VAI_TRÒ_PAUSER)  
      AccessControlUnauthorizedAccount(msg.sender, PAUSER_ROLE)  
    );  
    // _tạmDừng();  
    _pause();  
  }  
  
  /// @notice Unpauses the contract. Callable by guardian only.  
  /// @notice Tiếp tục hợp đồng. Chỉ có thể gọi bởi guardian.  
  // hàm tiếpTục() bên_ngoài ảo chỉVaiTrò(VAI_TRÒ_GUARDIAN) {  
  function unpause() external virtual onlyRole(GUARDIAN_ROLE) {  
    // _tiếpTục();  
    _unpause();  
  }  
  
  /**  
   * @notice Disabled. Roles are managed exclusively by the guardian via `revokeRole`;  
   * @notice Bị vô hiệu hóa. Các vai trò được quản lý độc quyền bởi guardian thông qua `revokeRole`;  
   *         self-renouncing could permanently strip access (e.g. the guardian role,  
   *         tự từ bỏ có thể xóa vĩnh viễn quyền truy cập (ví dụ: vai trò guardian,  
   *         which administers all other roles).  
   *         quản lý tất cả các vai trò khác).  
   * @dev Always reverts with `RenounceRoleDisabled`.  
   * @dev Luôn hoàn_tác với `TừBỏVaiTròBịVôHiệuHóa`.  
   */  
  // hàm từBỏVaiTrò(bytes32, địa_chỉ) công_khai ảo ghi_đè(KiểmSoátTruyCap, IKiểmSoátTruyCap) {  
  function renounceRole(bytes32, address) public virtual override(AccessControl, IAccessControl) {  
    // hoàn_tác TừBỏVaiTròBịVôHiệuHóa();  
    revert RenounceRoleDisabled();  
  }  
  
  /**  
   * @notice Initialises the role hierarchy and grants `GUARDIAN_ROLE`.  
   * @notice Khởi tạo hệ thống phân cấp vai trò và cấp `GUARDIAN_ROLE`.  
   * @dev Must be called exactly once from the concrete constructor.  
   * @dev Phải được gọi đúng một lần từ constructor cụ thể.  
   * @param initialGuardian Address that receives `GUARDIAN_ROLE`.  
   * @param initialGuardian Địa_chỉ nhận `GUARDIAN_ROLE`.  
   */  
  // hàm _khởiTạoGuardian(địa_chỉ guardianBanĐầu) nội_bộ {  
  function _initGuardian(address initialGuardian) internal {  
    // nếu (guardianBanĐầu == địa_chỉ(0)) hoàn_tác GuardianKhôngHợpLệ();  
    if (initialGuardian == address(0)) revert InvalidGuardian();  
  
    // Lock OpenZeppelin's DEFAULT_ADMIN_ROLE under guardian control.  
    // Khóa DEFAULT_ADMIN_ROLE của OpenZeppelin dưới sự kiểm soát của guardian.  
    // Without this, DEFAULT_ADMIN_ROLE is its own role-admin (bytes32(0)),  
    // Nếu không có điều này, DEFAULT_ADMIN_ROLE là role-admin của chính nó (bytes32(0)),  
    // meaning anyone granted it could escalate to any role.  
    // nghĩa là bất kỳ ai được cấp nó đều có thể leo thang lên bất kỳ vai trò nào.  
    // _đặtAdminVaiTrò(VAI_TRÒ_ADMIN_MẶC_ĐỊNH, VAI_TRÒ_GUARDIAN);  
    _setRoleAdmin(DEFAULT_ADMIN_ROLE, GUARDIAN_ROLE);  
  
    // _đặtAdminVaiTrò(VAI_TRÒ_GUARDIAN, VAI_TRÒ_GUARDIAN);  
    _setRoleAdmin(GUARDIAN_ROLE, GUARDIAN_ROLE);  
    // _đặtAdminVaiTrò(VAI_TRÒ_ADMIN, VAI_TRÒ_GUARDIAN);  
    _setRoleAdmin(ADMIN_ROLE, GUARDIAN_ROLE);  
    // _đặtAdminVaiTrò(VAI_TRÒ_PAUSER, VAI_TRÒ_GUARDIAN);  
    _setRoleAdmin(PAUSER_ROLE, GUARDIAN_ROLE);  
    // _cấpVaiTrò(VAI_TRÒ_GUARDIAN, guardianBanĐầu);  
    _grantRole(GUARDIAN_ROLE, initialGuardian);  
  }  
  
  /**  
   * @dev Returns true if the account holds `ADMIN_ROLE` or `GUARDIAN_ROLE`.  
   * @dev Trả_về true nếu tài khoản nắm giữ `ADMIN_ROLE` hoặc `GUARDIAN_ROLE`.  
   */  
  // hàm _làAdminHoặcGuardian(địa_chỉ tàiKhoản) nội_bộ chỉ_xem trả_về (bool) {  
  function _isAdminOrGuardian(address account) internal view returns (bool) {  
    // trả_về cóVaiTrò(VAI_TRÒ_ADMIN, tàiKhoản) || cóVaiTrò(VAI_TRÒ_GUARDIAN, tàiKhoản);  
    return hasRole(ADMIN_ROLE, account) || hasRole(GUARDIAN_ROLE, account);  
  }  
  
  /// @dev Tracks the guardian count so revocations can enforce the at-least-one-guardian invariant.  
  /// @dev Theo dõi số lượng guardian để các lần thu hồi có thể thực thi bất_biến ít_nhất_một_guardian.  
  // hàm _cấpVaiTrò(bytes32 vai_trò, địa_chỉ tàiKhoản) nội_bộ ảo ghi_đè trả_về (bool đã_cấp) {  
  function _grantRole(bytes32 role, address account) internal virtual override returns (bool granted) {  
    // đã_cấp = cha._cấpVaiTrò(vai_trò, tàiKhoản);  
    granted = super._grantRole(role, account);  
    // nếu (đã_cấp && vai_trò == VAI_TRÒ_GUARDIAN) sốLượngGuardian++;  
    if (granted && role == GUARDIAN_ROLE) guardianCount++;  
  }  
  
  /// @dev Reverts with `LastGuardian` when revoking would leave zero guardians.  
  /// @dev Hoàn_tác với `GuardianCuốiCùng` khi việc thu hồi sẽ để lại không có guardian nào.  
  // hàm _thuHồiVaiTrò(bytes32 vai_trò, địa_chỉ tàiKhoản) nội_bộ ảo ghi_đè trả_về (bool đã_thu_hồi) {  
  function _revokeRole(bytes32 role, address account) internal virtual override returns (bool revoked) {  
    // đã_thu_hồi = cha._thuHồiVaiTrò(vai_trò, tàiKhoản);  
    revoked = super._revokeRole(role, account);  
    // nếu (đã_thu_hồi && vai_trò == VAI_TRÒ_GUARDIAN) {  
    if (revoked && role == GUARDIAN_ROLE) {  
      // nếu (sốLượngGuardian == 1) hoàn_tác GuardianCuốiCùng();  
      if (guardianCount == 1) revert LastGuardian();  
      // sốLượngGuardian--;  
      guardianCount--;  
    }  
  }
}
