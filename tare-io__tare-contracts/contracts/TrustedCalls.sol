// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;

import {Enum} from "safe-smart-account/common/Enum.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ITrustedCalls} from "contracts/interfaces/ITrustedCalls.sol";
import {IModuleManager} from "contracts/misc/interfaces/IModuleManager.sol";
import {Rescuable} from "contracts/misc/Rescuable.sol";

/**  
 * @title TrustedCalls  
 * Tiêu_đề TrustedCalls  
 * @notice Safe module that lets per-safe delegates execute a globally whitelisted set of  
 * @notice Module Safe cho phép các đại_diện theo từng safe thực_thi một tập_hợp cuộc_gọi hàm được_đưa_vào_danh_sách_trắng toàn_cục  
 *         function calls on behalf of Safe accounts.  
 *         thay_mặt cho các tài_khoản Safe.  
 * @dev A single deployment serves multiple Safes: the trusted call registry is global  
 * @dev Một lần triển_khai phục_vụ nhiều Safe: sổ_đăng_ký cuộc_gọi tin_cậy là toàn_cục  
 *      while the delegate set is per-Safe.  
 *      trong khi tập_hợp đại_diện là theo từng Safe.  
 */  
// hợp_đồng TrustedCalls là ITrustedCalls, Rescuable {  
contract TrustedCalls is ITrustedCalls, Rescuable {  
  // sử_dụng SafeERC20 cho IERC20;  
  using SafeERC20 for IERC20;  
  
  /// @inheritdoc ITrustedCalls  
  // Kế_thừa từ ITrustedCalls  
  // mapping(bytes32 khóaTinCậy => bool làTinCậy) public cuộcGọiTinCậy_s;  
  mapping(bytes32 trustKey => bool isTrusted) public trustedCalls;  
  
  /// @inheritdoc ITrustedCalls  
  // Kế_thừa từ ITrustedCalls  
  // mapping(địa_chỉ safe => mapping(địa_chỉ đại_diện => bool được_ủy_quyền)) public đại_diện_s;  
  mapping(address safe => mapping(address delegate => bool authorized)) public delegates;  
  
  /**  
   * @notice Restricts function to Safe itself or an admin/guardian.  
   * @notice Hạn_chế hàm chỉ cho Safe hoặc quản_trị_viên/người_giám_hộ.  
   * @param safe The Safe address that must match `msg.sender` (or `msg.sender` must be admin/guardian).  
   * @param safe Địa_chỉ Safe phải khớp với `msg.người_gửi` (hoặc `msg.người_gửi` phải là quản_trị_viên/người_giám_hộ).  
   */  
  // modifier safeHoặcQuảnTrị(địa_chỉ safe) {  
  modifier safeOrAdmin(address safe) {  
    // yêu_cầu(msg.người_gửi == safe || _làQuảnTrịViênHoặcNgườiGiámHộ(msg.người_gửi), NgườiGọiKhôngĐượcPhép());  
    require(msg.sender == safe || _isAdminOrGuardian(msg.sender), UnauthorizedCaller());  
    // _;  
    _;  
  // }  
  }  
  
  /**  
   * @notice Restricts function to Safe itself or a guardian (excludes admin).  
   * @notice Hạn_chế hàm chỉ cho Safe hoặc người_giám_hộ (loại_trừ quản_trị_viên).  
   * @param safe The Safe address that must match `msg.sender` (or `msg.sender` must be a guardian).  
   * @param safe Địa_chỉ Safe phải khớp với `msg.người_gửi` (hoặc `msg.người_gửi` phải là người_giám_hộ).  
   */  
  // modifier safeHoặcNgườiGiámHộ(địa_chỉ safe) {  
  modifier safeOrGuardian(address safe) {  
    // yêu_cầu(msg.người_gửi == safe || cóVaiTrò(VAI_TRÒ_NGƯỜI_GIÁM_HỘ, msg.người_gửi), NgườiGọiKhôngĐượcPhép());  
    require(msg.sender == safe || hasRole(GUARDIAN_ROLE, msg.sender), UnauthorizedCaller());  
    // _;  
    _;  
  // }  
  }  
  
  // constructor(địa_chỉ người_giám_hộ_ban_đầu, địa_chỉ địaChỉKhôiPhụcBanĐầu) {  
  constructor(address initialGuardian, address initialRecoveryAddress) {  
    // _khởiTạoNgườiGiámHộ(người_giám_hộ_ban_đầu);  
    _initGuardian(initialGuardian);  
    // _khởiTạoĐịaChỉKhôiPhục(địaChỉKhôiPhụcBanĐầu);  
    _initRecoveryAddress(initialRecoveryAddress);  
  // }  
  }  
  
  /// @inheritdoc ITrustedCalls  
  // Kế_thừa từ ITrustedCalls  
  // hàm thêmCuộcGọiTinCậy(địa_chỉ đích, bytes4 bộ_chọn) bên_ngoài khiKhôngDừng chỉVaiTrò(VAI_TRÒ_NGƯỜI_GIÁM_HỘ) {  
  function addTrustedCall(address target, bytes4 selector) external whenNotPaused onlyRole(GUARDIAN_ROLE) {  
    // yêu_cầu(bộ_chọn != bytes4(0), BộChọnKhôngHợpLệ());  
    require(selector != bytes4(0), InvalidSelector());  
  
    // bytes32 khóa = lấyKhóaTinCậy(đích, bộ_chọn);  
    bytes32 key = getTrustKey(target, selector);  
    // cuộcGọiTinCậy_s[khóa] = true;  
    trustedCalls[key] = true;  
  
    // phát_sự_kiện CuộcGọiTinCậyĐãThêm(đích, bộ_chọn);  
    emit TrustedCallAdded(target, selector);  
  // }  
  }  
  
  /// @inheritdoc ITrustedCalls  
  // Kế_thừa từ ITrustedCalls  
  // hàm thêmCuộcGọiTinCậy_s(  
  function addTrustedCalls(  
    // địa_chỉ[] dữ_liệu_gọi đích_s,  
    address[] calldata targets,  
    // bytes4[] dữ_liệu_gọi bộ_chọn_s  
    bytes4[] calldata selectors  
  // ) bên_ngoài khiKhôngDừng chỉVaiTrò(VAI_TRÒ_NGƯỜI_GIÁM_HỘ) {  
  ) external whenNotPaused onlyRole(GUARDIAN_ROLE) {  
    // số_nguyên_không_dấu_256 độ_dài = đích_s.độ_dài;  
    uint256 length = targets.length;  
    // yêu_cầu(độ_dài == bộ_chọn_s.độ_dài, ĐộDàiKhôngKhớp());  
    require(length == selectors.length, LengthMismatch());  
    // yêu_cầu(độ_dài > 0, LôTrống());  
    require(length > 0, EmptyBatch());  
  
    // for (số_nguyên_không_dấu_256 i = 0; i < độ_dài; ++i) {  
    for (uint256 i = 0; i < length; ++i) {  
      // yêu_cầu(bộ_chọn_s[i] != bytes4(0), BộChọnKhôngHợpLệ());  
      require(selectors[i] != bytes4(0), InvalidSelector());  
  
      // bytes32 khóa = lấyKhóaTinCậy(đích_s[i], bộ_chọn_s[i]);  
      bytes32 key = getTrustKey(targets[i], selectors[i]);  
      // cuộcGọiTinCậy_s[khóa] = true;  
      trustedCalls[key] = true;  
  
      // phát_sự_kiện CuộcGọiTinCậyĐãThêm(đích_s[i], bộ_chọn_s[i]);  
      emit TrustedCallAdded(targets[i], selectors[i]);  
    // }  
    }  
  // }  
  }  
  
  /// @inheritdoc ITrustedCalls  
  // Kế_thừa từ ITrustedCalls  
  // hàm xóaCuộcGọiTinCậy(địa_chỉ đích, bytes4 bộ_chọn) bên_ngoài chỉQuảnTrịViênHoặcNgườiGiámHộ {  
  function removeTrustedCall(address target, bytes4 selector) external onlyAdminOrGuardian {  
    // bytes32 khóa = lấyKhóaTinCậy(đích, bộ_chọn);  
    bytes32 key = getTrustKey(target, selector);  
    // cuộcGọiTinCậy_s[khóa] = false;  
    trustedCalls[key] = false;  
  
    // phát_sự_kiện CuộcGọiTinCậyĐãXóa(đích, bộ_chọn);  
    emit TrustedCallRemoved(target, selector);  
  // }  
  }  
  
  /// @inheritdoc ITrustedCalls  
  // Kế_thừa từ ITrustedCalls  
  // hàm thêmĐạiDiện(địa_chỉ safe, địa_chỉ đại_diện) bên_ngoài safeHoặcNgườiGiámHộ(safe) {  
  function addDelegate(address safe, address delegate) external safeOrGuardian(safe) {  
    // đại_diện_s[safe][đại_diện] = true;  
    delegates[safe][delegate] = true;  
    // phát_sự_kiện ĐạiDiệnĐãThêm(safe, đại_diện);  
    emit DelegateAdded(safe, delegate);  
  // }  
  }

   /// @inheritdoc ITrustedCalls  
  // Kế_thừa từ ITrustedCalls  
  // hàm xóaĐạiDiện(địa_chỉ safe, địa_chỉ đại_diện) bên_ngoài safeHoặcQuảnTrị(safe) {  
  function removeDelegate(address safe, address delegate) external safeOrAdmin(safe) {  
    // đại_diện_s[safe][đại_diện] = false;  
    delegates[safe][delegate] = false;  
    // phát_sự_kiện ĐạiDiệnĐãXóa(safe, đại_diện);  
    emit DelegateRemoved(safe, delegate);  
  // }  
  }  
  
  /// @inheritdoc ITrustedCalls  
  // Kế_thừa từ ITrustedCalls  
  // hàm thựcThiCuộcGọiTinCậy(  
  function executeTrustedCall(  
    // địa_chỉ safe,  
    address safe,  
    // địa_chỉ đích,  
    address target,  
    // bytes dữ_liệu_gọi dữ_liệu  
    bytes calldata data  
  // ) bên_ngoài khiKhôngDừng trả_về (bool thành_công, bytes bộ_nhớ dữLiệuTrảVề) {  
  ) external whenNotPaused returns (bool success, bytes memory returnData) {  
    // Verify sender is delegate for this Safe  
    // Xác_minh người_gửi là đại_diện cho Safe này  
    // yêu_cầu(đại_diện_s[safe][msg.người_gửi], KhôngPhảiĐạiDiện());  
    require(delegates[safe][msg.sender], NotADelegate());  
  
    // Extract function selector (first 4 bytes)  
    // Trích_xuất bộ_chọn hàm (4 byte đầu_tiên)  
    // yêu_cầu(dữ_liệu.độ_dài >= 4, BộChọnKhôngHợpLệ());  
    require(data.length >= 4, InvalidSelector());  
    // bytes4 bộ_chọn = bytes4(dữ_liệu[:4]);  
    bytes4 selector = bytes4(data[:4]);  
  
    // Verify call is trusted  
    // Xác_minh cuộc_gọi là tin_cậy  
    // bytes32 khóa = lấyKhóaTinCậy(đích, bộ_chọn);  
    bytes32 key = getTrustKey(target, selector);  
    // yêu_cầu(cuộcGọiTinCậy_s[khóa], CuộcGọiKhôngTinCậy());  
    require(trustedCalls[key], CallNotTrusted());  
  
    // Execute call via Safe  
    // Thực_thi cuộc_gọi qua Safe  
    // (thành_công, dữLiệuTrảVề) = IModuleManager(payable(safe)).thựcThiGiaoDịchTừModuleTrảVềDữLiệu(  
    (success, returnData) = IModuleManager(payable(safe)).execTransactionFromModuleReturnData(  
      // đích,  
      target,  
      // 0, // giá_trị: không gửi ETH  
      0, // value: no ETH sent  
      // giá_trị: không gửi ETH  
      // dữ_liệu,  
      data,  
      // Enum.Operation.Gọi  
      Enum.Operation.Call  
    // );  
    );  
  
    // yêu_cầu(thành_công, ThựcThiThấtBại());  
    require(success, ExecutionFailed());  
  // }  
  }  
  
  /// @inheritdoc ITrustedCalls  
  // Kế_thừa từ ITrustedCalls  
  // hàm thựcThiLôCuộcGọiTinCậy(  
  function executeTrustedCallBatch(  
    // địa_chỉ safe,  
    address safe,  
    // địa_chỉ[] dữ_liệu_gọi đích_s,  
    address[] calldata targets,  
    // bytes[] dữ_liệu_gọi dữ_liệu  
    bytes[] calldata data  
  // ) bên_ngoài khiKhôngDừng trả_về (bytes[] bộ_nhớ kết_quả) {  
  ) external whenNotPaused returns (bytes[] memory results) {  
    // số_nguyên_không_dấu_256 độDàiĐích = đích_s.độ_dài;  
    uint256 targetsLength = targets.length;  
  
    // yêu_cầu(đại_diện_s[safe][msg.người_gửi], KhôngPhảiĐạiDiện());  
    require(delegates[safe][msg.sender], NotADelegate());  
    // yêu_cầu(độDàiĐích == dữ_liệu.độ_dài, ĐộDàiKhôngKhớp());  
    require(targetsLength == data.length, LengthMismatch());  
    // yêu_cầu(độDàiĐích > 0, LôTrống());  
    require(targetsLength > 0, EmptyBatch());  
  
    // kết_quả = new bytes[](độDàiĐích);  
    results = new bytes[](targetsLength);  
  
    // for (số_nguyên_không_dấu_256 i = 0; i < độDàiĐích; ++i) {  
    for (uint256 i = 0; i < targetsLength; ++i) {  
      // yêu_cầu(dữ_liệu[i].độ_dài >= 4, BộChọnKhôngHợpLệ());  
      require(data[i].length >= 4, InvalidSelector());  
      // bytes4 bộ_chọn = bytes4(dữ_liệu[i][:4]);  
      bytes4 selector = bytes4(data[i][:4]);  
  
      // bytes32 khóa = lấyKhóaTinCậy(đích_s[i], bộ_chọn);  
      bytes32 key = getTrustKey(targets[i], selector);  
      // yêu_cầu(cuộcGọiTinCậy_s[khóa], CuộcGọiKhôngTinCậy());  
      require(trustedCalls[key], CallNotTrusted());  
  
      // (bool thành_công, bytes bộ_nhớ dữLiệuTrảVề) = IModuleManager(payable(safe)).thựcThiGiaoDịchTừModuleTrảVềDữLiệu(  
      (bool success, bytes memory returnData) = IModuleManager(payable(safe)).execTransactionFromModuleReturnData(  
        // đích_s[i],  
        targets[i],  
        // 0,  
        0,  
        // dữ_liệu[i],  
        data[i],  
        // Enum.Operation.Gọi  
        Enum.Operation.Call  
      // );  
      );  
  
      // yêu_cầu(thành_công, ThựcThiThấtBại());  
      require(success, ExecutionFailed());  
      // kết_quả[i] = dữLiệuTrảVề;  
      results[i] = returnData;  
    // }  
    }  
  // }  
  }  
  
  /// @inheritdoc ITrustedCalls  
  // Kế_thừa từ ITrustedCalls  
  // hàm làCuộcGọiTinCậy(địa_chỉ đích, bytes4 bộ_chọn) bên_ngoài xem trả_về (bool) {  
  function isTrustedCall(address target, bytes4 selector) external view returns (bool) {  
    // trả_về cuộcGọiTinCậy_s[lấyKhóaTinCậy(đích, bộ_chọn)];  
    return trustedCalls[getTrustKey(target, selector)];  
  // }  
  }  
  
  /// @inheritdoc ITrustedCalls  
  // Kế_thừa từ ITrustedCalls  
  // hàm làĐạiDiện(địa_chỉ safe, địa_chỉ đại_diện) bên_ngoài xem trả_về (bool) {  
  function isDelegate(address safe, address delegate) external view returns (bool) {  
    // trả_về đại_diện_s[safe][đại_diện];  
    return delegates[safe][delegate];  
  // }  
  }  
  
  /// @inheritdoc ITrustedCalls  
  // Kế_thừa từ ITrustedCalls  
  // hàm lấyKhóaTinCậy(địa_chỉ đích, bytes4 bộ_chọn) public thuần trả_về (bytes32) {  
  function getTrustKey(address target, bytes4 selector) public pure returns (bytes32) {  
    // trả_về keccak256(abi.mãHóaĐóngGói(đích, bộ_chọn));  
    return keccak256(abi.encodePacked(target, selector));  
  // }  
  }
}
