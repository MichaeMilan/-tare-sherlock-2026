// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {Allowance, ITrustedSpender, NFTAllowance} from "contracts/interfaces/ITrustedSpender.sol";
import {Rescuable} from "contracts/misc/Rescuable.sol";

/**  
 * @title TrustedSpender  
 * Tiêu_đề TrustedSpender  
 * @notice Lets per-safe delegates move tokens (ERC20 and ERC721) out of Safe accounts to  
 * @notice Cho phép các đại_diện theo từng safe chuyển token (ERC20 và ERC721) ra khỏi tài_khoản Safe đến  
 *         pre-approved recipient routes, capped by per-route allowances.  
 *         các tuyến người_nhận đã_được_phê_duyệt trước, bị giới_hạn bởi hạn_mức theo từng tuyến.  
 * @dev Safes must approve this contract beforehand (`approve` for ERC20,  
 * @dev Các Safe phải phê_duyệt hợp_đồng này trước (`phê_duyệt` cho ERC20,  
 *      `setApprovalForAll` for ERC721); this contract does not hold custody.  
 *      `đặtPhêDuyệtChoTất_cả` cho ERC721); hợp_đồng này không nắm_giữ quyền_giám_hộ.  
 */  
// hợp_đồng TrustedSpender là ITrustedSpender, Rescuable {  
contract TrustedSpender is ITrustedSpender, Rescuable {  
  // sử_dụng SafeERC20 cho IERC20;  
  using SafeERC20 for IERC20;  
  
  /// @inheritdoc ITrustedSpender  
  // Kế_thừa từ ITrustedSpender  
  // mapping(địa_chỉ safe => mapping(địa_chỉ đại_diện => bool được_ủy_quyền)) public đại_diện_s;  
  mapping(address safe => mapping(address delegate => bool authorized)) public delegates;  
  
  /** @dev `(token, safe, recipient) => allowance`. Internal; queried via `getAllowance`. */  
  /** @dev `(token, safe, người_nhận) => hạn_mức`. Nội_bộ; truy_vấn qua `lấyHạnMức`. */  
  // mapping(địa_chỉ token => mapping(địa_chỉ từ => mapping(địa_chỉ đến => HạnMức hạn_mức))) nội_bộ _hạnMức_s;  
  mapping(address token => mapping(address from => mapping(address to => Allowance allowance))) internal _allowances;  
  
  /** @dev `(collection, safe, recipient) => NFT allowance`. Internal; queried via `getNFTAllowance`. */  
  /** @dev `(bộ_sưu_tập, safe, người_nhận) => hạn_mức NFT`. Nội_bộ; truy_vấn qua `lấyHạnMứcNFT`. */  
  // mapping(địa_chỉ bộ_sưu_tập => mapping(địa_chỉ từ => mapping(địa_chỉ đến => HạnMứcNFT hạn_mức)))  
  mapping(address collection => mapping(address from => mapping(address to => NFTAllowance allowance)))  
    // nội_bộ _hạnMứcNFT_s;  
    internal _nftAllowances;  
  
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
  
  /// @inheritdoc ITrustedSpender  
  // Kế_thừa từ ITrustedSpender  
  // hàm thêmĐạiDiện(địa_chỉ safe, địa_chỉ đại_diện) bên_ngoài safeHoặcNgườiGiámHộ(safe) {  
  function addDelegate(address safe, address delegate) external safeOrGuardian(safe) {  
    // yêu_cầu(safe != địa_chỉ(0) && đại_diện != địa_chỉ(0), ĐịaChỉKhông());  
    require(safe != address(0) && delegate != address(0), ZeroAddress());  
  
    // đại_diện_s[safe][đại_diện] = true;  
    delegates[safe][delegate] = true;  
    // phát_sự_kiện ĐạiDiệnĐãThêm(safe, đại_diện);  
    emit DelegateAdded(safe, delegate);  
  // }  
  }  
  
  /// @inheritdoc ITrustedSpender  
  // Kế_thừa từ ITrustedSpender  
  // hàm xóaĐạiDiện(địa_chỉ safe, địa_chỉ đại_diện) bên_ngoài safeHoặcQuảnTrị(safe) {  
  function removeDelegate(address safe, address delegate) external safeOrAdmin(safe) {  
    // đại_diện_s[safe][đại_diện] = false;  
    delegates[safe][delegate] = false;  
    // phát_sự_kiện ĐạiDiệnĐãXóa(safe, đại_diện);  
    emit DelegateRemoved(safe, delegate);  
  // }  
  }  
  
  /// @inheritdoc ITrustedSpender  
  // Kế_thừa từ ITrustedSpender  
  // hàm đặtHạnMức(  
  function setAllowance(  
    // địa_chỉ token,  
    address token,  
    // địa_chỉ từ,  
    address from,  
    // địa_chỉ đến,  
    address to,  
    // số_nguyên_không_dấu_208 số_lượng,  
    uint208 amount,  
    // số_nguyên_không_dấu_48 hợpLệĐến  
    uint48 validUntil  
  // ) bên_ngoài safeHoặcNgườiGiámHộ(từ) {  
  ) external safeOrGuardian(from) {  
    // yêu_cầu(token != địa_chỉ(0) && từ != địa_chỉ(0) && đến != địa_chỉ(0), ĐịaChỉKhông());  
    require(token != address(0) && from != address(0) && to != address(0), ZeroAddress());  
    // yêu_cầu(hợpLệĐến > block.dấu_thời_gian, HạnChótHạnMứcKhôngHợpLệ());  
    require(validUntil > block.timestamp, InvalidAllowanceDeadline());  
  
    // _hạnMức_s[token][từ][đến] = HạnMức({số_lượng: số_lượng, hợpLệĐến: hợpLệĐến});  
    _allowances[token][from][to] = Allowance({amount: amount, validUntil: validUntil});  
    // phát_sự_kiện HạnMứcĐãĐặt(token, từ, đến, số_lượng, hợpLệĐến);  
    emit AllowanceSet(token, from, to, amount, validUntil);  
  // }  
  }  
  
  /// @inheritdoc ITrustedSpender  
  // Kế_thừa từ ITrustedSpender  
  // hàm thựcThiChuyển(địa_chỉ token, địa_chỉ từ, địa_chỉ đến, số_nguyên_không_dấu_256 số_lượng) bên_ngoài khiKhôngDừng {  
  function executeTransfer(address token, address from, address to, uint256 amount) external whenNotPaused {  
    // Verify sender is a delegate  
    // Xác_minh người_gửi là đại_diện  
    // yêu_cầu(đại_diện_s[từ][msg.người_gửi], KhôngPhảiĐạiDiện());  
    require(delegates[from][msg.sender], NotADelegate());  
  
    // Check allowance exists, is sufficient, and has not expired  
    // Kiểm_tra hạn_mức tồn_tại, đủ, và chưa hết_hạn  
    // HạnMức lưu_trữ hạn_mức = _hạnMức_s[token][từ][đến];  
    Allowance storage allowance = _allowances[token][from][to];  
    // yêu_cầu(hạn_mức.số_lượng >= số_lượng, HạnMứcKhôngĐủ());  
    require(allowance.amount >= amount, InsufficientAllowance());  
    // yêu_cầu(block.dấu_thời_gian <= hạn_mức.hợpLệĐến, HạnMứcĐãHếtHạn());  
    require(block.timestamp <= allowance.validUntil, AllowanceExpired());  
  
    // Update allowance if not infinite  
    // Cập_nhật hạn_mức nếu không phải vô_hạn  
    // nếu (hạn_mức.số_lượng != type(số_nguyên_không_dấu_208).max) {  
    if (allowance.amount != type(uint208).max) {  
      // hạn_mức.số_lượng -= số_nguyên_không_dấu_208(số_lượng);  
      allowance.amount -= uint208(amount);  
    // }  
    }  
  
    // IERC20(token).chuyểnAnToànTừ(từ, đến, số_lượng);  
    IERC20(token).safeTransferFrom(from, to, amount);  
  // }  
  }

    /// @inheritdoc ITrustedSpender  
  // Kế_thừa từ ITrustedSpender  
  // hàm lấyHạnMức(  
  function getAllowance(  
    // địa_chỉ token,  
    address token,  
    // địa_chỉ từ,  
    address from,  
    // địa_chỉ đến  
    address to  
  // ) bên_ngoài xem trả_về (số_nguyên_không_dấu_256 số_lượng, số_nguyên_không_dấu_48 hợpLệĐến) {  
  ) external view returns (uint256 amount, uint48 validUntil) {  
    // HạnMức lưu_trữ hạn_mức = _hạnMức_s[token][từ][đến];  
    Allowance storage allowance = _allowances[token][from][to];  
    // trả_về (số_nguyên_không_dấu_256(hạn_mức.số_lượng), hạn_mức.hợpLệĐến);  
    return (uint256(allowance.amount), allowance.validUntil);  
  // }  
  }  
  
  /// @inheritdoc ITrustedSpender  
  // Kế_thừa từ ITrustedSpender  
  // hàm làĐạiDiện(địa_chỉ safe, địa_chỉ đại_diện) bên_ngoài xem trả_về (bool) {  
  function isDelegate(address safe, address delegate) external view returns (bool) {  
    // trả_về đại_diện_s[safe][đại_diện];  
    return delegates[safe][delegate];  
  // }  
  }  
  
  /// @inheritdoc ITrustedSpender  
  // Kế_thừa từ ITrustedSpender  
  // hàm đặtHạnMứcNFT(  
  function setNFTAllowance(  
    // địa_chỉ bộ_sưu_tập,  
    address collection,  
    // địa_chỉ từ,  
    address from,  
    // địa_chỉ đến,  
    address to,  
    // bool được_phép,  
    bool allowed,  
    // số_nguyên_không_dấu_48 hợpLệĐến  
    uint48 validUntil  
  // ) bên_ngoài safeHoặcNgườiGiámHộ(từ) {  
  ) external safeOrGuardian(from) {  
    // yêu_cầu(bộ_sưu_tập != địa_chỉ(0) && từ != địa_chỉ(0) && đến != địa_chỉ(0), ĐịaChỉKhông());  
    require(collection != address(0) && from != address(0) && to != address(0), ZeroAddress());  
    // yêu_cầu(hợpLệĐến > block.dấu_thời_gian, HạnChótHạnMứcKhôngHợpLệ());  
    require(validUntil > block.timestamp, InvalidAllowanceDeadline());  
  
    // _hạnMứcNFT_s[bộ_sưu_tập][từ][đến] = HạnMứcNFT({được_phép: được_phép, hợpLệĐến: hợpLệĐến});  
    _nftAllowances[collection][from][to] = NFTAllowance({allowed: allowed, validUntil: validUntil});  
    // phát_sự_kiện HạnMứcNFTĐãĐặt(bộ_sưu_tập, từ, đến, được_phép, hợpLệĐến);  
    emit NFTAllowanceSet(collection, from, to, allowed, validUntil);  
  // }  
  }  
  
  /// @inheritdoc ITrustedSpender  
  // Kế_thừa từ ITrustedSpender  
  // hàm thựcThiChuyểnNFT(địa_chỉ bộ_sưu_tập, địa_chỉ từ, địa_chỉ đến, số_nguyên_không_dấu_256 mãToken) bên_ngoài khiKhôngDừng {  
  function executeNFTTransfer(address collection, address from, address to, uint256 tokenId) external whenNotPaused {  
    // yêu_cầu(đại_diện_s[từ][msg.người_gửi], KhôngPhảiĐạiDiện());  
    require(delegates[from][msg.sender], NotADelegate());  
  
    // HạnMứcNFT lưu_trữ hạn_mức = _hạnMứcNFT_s[bộ_sưu_tập][từ][đến];  
    NFTAllowance storage allowance = _nftAllowances[collection][from][to];  
    // yêu_cầu(hạn_mức.được_phép, ChuyểnNFTKhôngĐượcPhép());  
    require(allowance.allowed, NFTTransferNotAllowed());  
    // yêu_cầu(block.dấu_thời_gian <= hạn_mức.hợpLệĐến, HạnMứcĐãHếtHạn());  
    require(block.timestamp <= allowance.validUntil, AllowanceExpired());  
  
    // IERC721(bộ_sưu_tập).chuyểnAnToànTừ(từ, đến, mãToken);  
    IERC721(collection).safeTransferFrom(from, to, tokenId);  
    // phát_sự_kiện ChuyểnNFTĐãThựcThi(bộ_sưu_tập, từ, đến, mãToken, msg.người_gửi);  
    emit NFTTransferExecuted(collection, from, to, tokenId, msg.sender);  
  // }  
  }  
  
  /// @inheritdoc ITrustedSpender  
  // Kế_thừa từ ITrustedSpender  
  // hàm lấyHạnMứcNFT(  
  function getNFTAllowance(  
    // địa_chỉ bộ_sưu_tập,  
    address collection,  
    // địa_chỉ từ,  
    address from,  
    // địa_chỉ đến  
    address to  
  // ) bên_ngoài xem trả_về (bool được_phép, số_nguyên_không_dấu_48 hợpLệĐến) {  
  ) external view returns (bool allowed, uint48 validUntil) {  
    // HạnMứcNFT lưu_trữ hạn_mức = _hạnMứcNFT_s[bộ_sưu_tập][từ][đến];  
    NFTAllowance storage allowance = _nftAllowances[collection][from][to];  
    // trả_về (hạn_mức.được_phép, hạn_mức.hợpLệĐến);  
    return (allowance.allowed, allowance.validUntil);  
  // }  
  }  
  
  /// @inheritdoc ITrustedSpender  
  // Kế_thừa từ ITrustedSpender  
  // hàm làChuyểnNFTĐượcPhép(địa_chỉ bộ_sưu_tập, địa_chỉ từ, địa_chỉ đến) bên_ngoài xem trả_về (bool) {  
  function isNFTTransferAllowed(address collection, address from, address to) external view returns (bool) {  
    // HạnMứcNFT lưu_trữ hạn_mức = _hạnMứcNFT_s[bộ_sưu_tập][từ][đến];  
    NFTAllowance storage allowance = _nftAllowances[collection][from][to];  
    // trả_về hạn_mức.được_phép && block.dấu_thời_gian <= hạn_mức.hợpLệĐến;  
    return allowance.allowed && block.timestamp <= allowance.validUntil;  
  // }  
  }
}
