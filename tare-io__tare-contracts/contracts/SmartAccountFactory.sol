// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeProxy} from "safe-smart-account/proxies/SafeProxy.sol";
import {SafeProxyFactory} from "safe-smart-account/proxies/SafeProxyFactory.sol";

import {ISmartAccountFactory} from "contracts/interfaces/ISmartAccountFactory.sol";
import {ITrustedCalls} from "contracts/interfaces/ITrustedCalls.sol";
import {ITrustedSpender} from "contracts/interfaces/ITrustedSpender.sol";
import {IModuleManager} from "contracts/misc/interfaces/IModuleManager.sol";
import {ISafe} from "contracts/misc/interfaces/ISafe.sol";

/**  
 * @title SmartAccountFactory  
 * Tiêu_đề SmartAccountFactory  
 * @notice Deploys Gnosis Safe smart accounts with the `TrustedCalls` module enabled, the  
 * @notice Triển_khai các tài_khoản thông_minh Gnosis Safe với module `TrustedCalls` được bật,  
 *         `TrustedSpender` contract pre-approved for the requested tokens, and per-route  
 *         hợp_đồng `TrustedSpender` được phê_duyệt trước cho các token được yêu_cầu, và  
 *         allowances set up so delegates can act on the Safe's behalf from day one.  
 *         các hạn_mức theo từng tuyến được thiết_lập để đại_diện có_thể hành_động thay_mặt Safe từ ngày đầu_tiên.  
 */  
// hợp_đồng SmartAccountFactory là ISmartAccountFactory {  
contract SmartAccountFactory is ISmartAccountFactory {  
  // sử_dụng SafeERC20 cho IERC20;  
  using SafeERC20 for IERC20;  
  
  // Immutable references to Safe infrastructure  
  // Các tham_chiếu bất_biến đến cơ_sở_hạ_tầng Safe  
  // SafeProxyFactory public immutable NHÀ_MÁY_PROXY_SAFE;  
  SafeProxyFactory public immutable SAFE_PROXY_FACTORY;  
  // địa_chỉ public immutable SAFE_ĐƠN_LẺ;  
  address public immutable SAFE_SINGLETON;  
  
  // TrustedCalls module reference for installation  
  // Tham_chiếu module TrustedCalls để cài_đặt  
  // địa_chỉ public immutable MODULE_CUỘC_GỌI_TIN_CẬY;  
  address public immutable TRUSTED_CALLS_MODULE;  
  
  // TrustedSpender contract reference (not a module, uses token approvals)  
  // Tham_chiếu hợp_đồng TrustedSpender (không phải module, sử_dụng phê_duyệt token)  
  // địa_chỉ public immutable NGƯỜI_CHI_TIÊU_TIN_CẬY;  
  address public immutable TRUSTED_SPENDER;  
  
  // địa_chỉ private immutable _BẢN_THÂN = địa_chỉ(this);  
  address private immutable _SELF = address(this);  
  
  // bytes32 private constant Ô_ĐÃ_CẤU_HÌNH = keccak256("Tare.SmartAccountFactory.configured");  
  bytes32 private constant CONFIGURED_SLOT = keccak256("Tare.SmartAccountFactory.configured");  
  
  /// @inheritdoc ISmartAccountFactory  
  // Kế_thừa từ ISmartAccountFactory  
  // mapping(địa_chỉ người_triển_khai => số_nguyên_không_dấu_256 số_thứ_tự) public số_thứ_tự_s;  
  mapping(address deployer => uint256 nonce) public nonces;  
  
  /// @inheritdoc ISmartAccountFactory  
  // Kế_thừa từ ISmartAccountFactory  
  // mapping(địa_chỉ tài_khoản => bool đã_triển_khai) public làTàiKhoảnThôngMinhĐãTriểnKhai;  
  mapping(address account => bool deployed) public isDeployedSmartAccount;  
  
  // constructor(địa_chỉ _nhàMáyProxySafe, địa_chỉ _safeĐơnLẻ, địa_chỉ _moduleCuộcGọiTinCậy, địa_chỉ _ngườiChiTiêuTinCậy) {  
  constructor(address _safeProxyFactory, address _safeSingleton, address _trustedCallsModule, address _trustedSpender) {  
    // NHÀ_MÁY_PROXY_SAFE = SafeProxyFactory(_nhàMáyProxySafe);  
    SAFE_PROXY_FACTORY = SafeProxyFactory(_safeProxyFactory);  
    // SAFE_ĐƠN_LẺ = _safeĐơnLẻ;  
    SAFE_SINGLETON = _safeSingleton;  
    // MODULE_CUỘC_GỌI_TIN_CẬY = _moduleCuộcGọiTinCậy;  
    TRUSTED_CALLS_MODULE = _trustedCallsModule;  
    // NGƯỜI_CHI_TIÊU_TIN_CẬY = _ngườiChiTiêuTinCậy;  
    TRUSTED_SPENDER = _trustedSpender;  
  // }  
  }  
  
  /// @inheritdoc ISmartAccountFactory  
  // Kế_thừa từ ISmartAccountFactory  
  // hàm triểnKhaiTàiKhoảnThôngMinh(  
  function deploySmartAccount(  
    // địa_chỉ[] bộ_nhớ đại_diện_s,  
    address[] memory delegates,  
    // địa_chỉ[] bộ_nhớ tiền_tệ_s,  
    address[] memory currencies,  
    // địa_chỉ[] bộ_nhớ bộSưuTậpNFT_s,  
    address[] memory nftCollections,  
    // địa_chỉ[] bộ_nhớ người_nhận_tin_cậy_s,  
    address[] memory trustedRecipients,  
    // số_nguyên_không_dấu_48 hợpLệĐến,  
    uint48 validUntil,  
    // địa_chỉ[] bộ_nhớ chủ_sở_hữu_s,  
    address[] memory owners,  
    // số_nguyên_không_dấu_256 ngưỡng  
    uint256 threshold  
  // ) bên_ngoài trả_về (địa_chỉ) {  
  ) external returns (address) {  
    // yêu_cầu(chủ_sở_hữu_s.độ_dài > 0, KhôngCóChủSởHữu());  
    require(owners.length > 0, NoOwners());  
    // yêu_cầu(ngưỡng > 0, NgưỡngKhôngHợpLệ());  
    require(threshold > 0, InvalidThreshold());  
    // yêu_cầu(ngưỡng <= chủ_sở_hữu_s.độ_dài, NgưỡngQuáCao());  
    require(threshold <= owners.length, ThresholdTooHigh());  
    // yêu_cầu(hợpLệĐến > block.dấu_thời_gian, HạnChótHạnMứcKhôngHợpLệ());  
    require(validUntil > block.timestamp, InvalidAllowanceDeadline());  
  
    // Calculate the salt nonce for deterministic address (scoped per deployer)  
    // Tính toán số_thứ_tự muối cho địa_chỉ xác_định (phạm_vi theo từng người_triển_khai)  
    // số_nguyên_không_dấu_256 sốThứTựNgườiTriểnKhai = số_thứ_tự_s[msg.người_gửi]++;  
    uint256 deployerNonce = nonces[msg.sender]++;  
    // số_nguyên_không_dấu_256 sốThứTựMuối = số_nguyên_không_dấu_256(keccak256(abi.mãHóaĐóngGói(msg.người_gửi, sốThứTựNgườiTriểnKhai)));  
    uint256 saltNonce = uint256(keccak256(abi.encodePacked(msg.sender, deployerNonce)));  
  
    // bytes bộ_nhớ khởiTạo = _xâyDựngKhởiTạo(  
    bytes memory initializer = _buildInitializer(  
      // đại_diện_s,  
      delegates,  
      // tiền_tệ_s,  
      currencies,  
      // bộSưuTậpNFT_s,  
      nftCollections,  
      // người_nhận_tin_cậy_s,  
      trustedRecipients,  
      // hợpLệĐến,  
      validUntil,  
      // chủ_sở_hữu_s,  
      owners,  
      // ngưỡng  
      threshold  
    // );  
    );  
  
    // SafeProxy proxy = NHÀ_MÁY_PROXY_SAFE.tạoProxyVớiSốThứTự(SAFE_ĐƠN_LẺ, khởiTạo, sốThứTựMuối);  
    SafeProxy proxy = SAFE_PROXY_FACTORY.createProxyWithNonce(SAFE_SINGLETON, initializer, saltNonce);  
  
    // địa_chỉ địaChỉSafe = địa_chỉ(proxy);  
    address safeAddress = address(proxy);  
    // làTàiKhoảnThôngMinhĐãTriểnKhai[địaChỉSafe] = true;  
    isDeployedSmartAccount[safeAddress] = true;  
    // phát_sự_kiện TàiKhoảnThôngMinhĐãTriểnKhai(địaChỉSafe, msg.người_gửi, chủ_sở_hữu_s, ngưỡng);  
    emit SmartAccountDeployed(safeAddress, msg.sender, owners, threshold);  
  
    // trả_về địaChỉSafe;  
    return safeAddress;  
  // }  
  }

  /// @inheritdoc ISmartAccountFactory  
  // Kế_thừa từ ISmartAccountFactory  
  // hàm cấuHìnhTàiKhoảnThôngMinh(  
  function configureSmartAccount(  
    // địa_chỉ[] bộ_nhớ đại_diện_s,  
    address[] memory delegates,  
    // địa_chỉ[] bộ_nhớ tiền_tệ_s,  
    address[] memory currencies,  
    // địa_chỉ[] bộ_nhớ bộSưuTậpNFT_s,  
    address[] memory nftCollections,  
    // địa_chỉ[] bộ_nhớ người_nhận_tin_cậy_s,  
    address[] memory trustedRecipients,  
    // số_nguyên_không_dấu_48 hợpLệĐến  
    uint48 validUntil  
  // ) bên_ngoài {  
  ) external {  
    // yêu_cầu(địa_chỉ(this) != _BẢN_THÂN, KhôngPhảiGọiỦyQuyền());  
    require(address(this) != _SELF, NotDelegateCall());  
    // _đặtĐãCấuHình();  
    _setConfigured();  
  
    // 1. Enable TrustedCalls module  
    // 1. Bật module TrustedCalls  
    // IModuleManager(payable(địa_chỉ(this))).bậtModule(MODULE_CUỘC_GỌI_TIN_CẬY);  
    IModuleManager(payable(address(this))).enableModule(TRUSTED_CALLS_MODULE);  
  
    // 2. Approve currencies for TrustedSpender (standard ERC20 approvals)  
    // 2. Phê_duyệt tiền_tệ cho TrustedSpender (phê_duyệt ERC20 tiêu_chuẩn)  
    // for (số_nguyên_không_dấu_256 i = 0; i < tiền_tệ_s.độ_dài; ++i) {  
    for (uint256 i = 0; i < currencies.length; ++i) {  
      // IERC20(tiền_tệ_s[i]).buộcPhêDuyệt(NGƯỜI_CHI_TIÊU_TIN_CẬY, type(số_nguyên_không_dấu_256).max);  
      IERC20(currencies[i]).forceApprove(TRUSTED_SPENDER, type(uint256).max);  
    // }  
    }  
  
    // 3. Approve NFT collections for TrustedSpender (blanket setApprovalForAll)  
    // 3. Phê_duyệt bộ_sưu_tập NFT cho TrustedSpender (đặtPhêDuyệtChoTất_cả toàn_diện)  
    // for (số_nguyên_không_dấu_256 i = 0; i < bộSưuTậpNFT_s.độ_dài; ++i) {  
    for (uint256 i = 0; i < nftCollections.length; ++i) {  
      // IERC721(bộSưuTậpNFT_s[i]).đặtPhêDuyệtChoTất_cả(NGƯỜI_CHI_TIÊU_TIN_CẬY, true);  
      IERC721(nftCollections[i]).setApprovalForAll(TRUSTED_SPENDER, true);  
    // }  
    }  
  
    // 4. Add delegates to both TrustedCalls module and TrustedSpender contract  
    // 4. Thêm đại_diện vào cả module TrustedCalls và hợp_đồng TrustedSpender  
    // for (số_nguyên_không_dấu_256 i = 0; i < đại_diện_s.độ_dài; ++i) {  
    for (uint256 i = 0; i < delegates.length; ++i) {  
      // Add to TrustedCalls module  
      // Thêm vào module TrustedCalls  
      // ITrustedCalls(MODULE_CUỘC_GỌI_TIN_CẬY).thêmĐạiDiện(địa_chỉ(this), đại_diện_s[i]);  
      ITrustedCalls(TRUSTED_CALLS_MODULE).addDelegate(address(this), delegates[i]);  
  
      // Add to TrustedSpender contract  
      // Thêm vào hợp_đồng TrustedSpender  
      // ITrustedSpender(NGƯỜI_CHI_TIÊU_TIN_CẬY).thêmĐạiDiện(địa_chỉ(this), đại_diện_s[i]);  
      ITrustedSpender(TRUSTED_SPENDER).addDelegate(address(this), delegates[i]);  
    // }  
    }  
  
    // 5. Set ERC20 allowances for trusted recipients in TrustedSpender.  
    // 5. Đặt hạn_mức ERC20 cho người_nhận tin_cậy trong TrustedSpender.  
    //    NFT per-route allowances are set lazily via TrustedSpender.setNFTAllowance.  
    //    Hạn_mức NFT theo từng tuyến được đặt lười_biếng qua TrustedSpender.đặtHạnMứcNFT.  
    // for (số_nguyên_không_dấu_256 i = 0; i < người_nhận_tin_cậy_s.độ_dài; ++i) {  
    for (uint256 i = 0; i < trustedRecipients.length; ++i) {  
      // for (số_nguyên_không_dấu_256 j = 0; j < tiền_tệ_s.độ_dài; ++j) {  
      for (uint256 j = 0; j < currencies.length; ++j) {  
        // ITrustedSpender(NGƯỜI_CHI_TIÊU_TIN_CẬY).đặtHạnMức(  
        ITrustedSpender(TRUSTED_SPENDER).setAllowance(  
          // tiền_tệ_s[j],  
          currencies[j],  
          // địa_chỉ(this),  
          address(this),  
          // người_nhận_tin_cậy_s[i],  
          trustedRecipients[i],  
          // type(số_nguyên_không_dấu_208).max,  
          type(uint208).max,  
          // hợpLệĐến  
          validUntil  
        // );  
        );  
      // }  
      }  
    // }  
    }  
  // }  
  }  
  
  /// @inheritdoc ISmartAccountFactory  
  // Kế_thừa từ ISmartAccountFactory  
  // hàm dựĐoánĐịaChỉTàiKhoảnThôngMinh(  
  function predictSmartAccountAddress(  
    // địa_chỉ người_triển_khai,  
    address deployer,  
    // số_nguyên_không_dấu_256 _sốThứTự,  
    uint256 _nonce,  
    // địa_chỉ[] bộ_nhớ đại_diện_s,  
    address[] memory delegates,  
    // địa_chỉ[] bộ_nhớ tiền_tệ_s,  
    address[] memory currencies,  
    // địa_chỉ[] bộ_nhớ bộSưuTậpNFT_s,  
    address[] memory nftCollections,  
    // địa_chỉ[] bộ_nhớ người_nhận_tin_cậy_s,  
    address[] memory trustedRecipients,  
    // số_nguyên_không_dấu_48 hợpLệĐến,  
    uint48 validUntil,  
    // địa_chỉ[] bộ_nhớ chủ_sở_hữu_s,  
    address[] memory owners,  
    // số_nguyên_không_dấu_256 ngưỡng  
    uint256 threshold  
  // ) public xem trả_về (địa_chỉ) {  
  ) public view returns (address) {  
    // số_nguyên_không_dấu_256 sốThứTựMuối = số_nguyên_không_dấu_256(keccak256(abi.mãHóaĐóngGói(người_triển_khai, _sốThứTự)));  
    uint256 saltNonce = uint256(keccak256(abi.encodePacked(deployer, _nonce)));  
  
    // bytes bộ_nhớ khởiTạo = _xâyDựngKhởiTạo(  
    bytes memory initializer = _buildInitializer(  
      // đại_diện_s,  
      delegates,  
      // tiền_tệ_s,  
      currencies,  
      // bộSưuTậpNFT_s,  
      nftCollections,  
      // người_nhận_tin_cậy_s,  
      trustedRecipients,  
      // hợpLệĐến,  
      validUntil,  
      // chủ_sở_hữu_s,  
      owners,  
      // ngưỡng  
      threshold  
    // );  
    );  
    // bytes32 muối = keccak256(abi.mãHóaĐóngGói(keccak256(khởiTạo), sốThứTựMuối));  
    bytes32 salt = keccak256(abi.encodePacked(keccak256(initializer), saltNonce));  
  
    // bytes bộ_nhớ dữLiệuTriểnKhai = abi.mãHóaĐóngGói(  
    bytes memory deploymentData = abi.encodePacked(  
      // NHÀ_MÁY_PROXY_SAFE.mãTạoProxy(),  
      SAFE_PROXY_FACTORY.proxyCreationCode(),  
      // số_nguyên_không_dấu_256(số_nguyên_không_dấu_160(SAFE_ĐƠN_LẺ))  
      uint256(uint160(SAFE_SINGLETON))  
    // );  
    );  
  
    // bytes32 băm = keccak256(  
    bytes32 hash = keccak256(  
      // abi.mãHóaĐóngGói(bytes1(0xff), địa_chỉ(NHÀ_MÁY_PROXY_SAFE), muối, keccak256(dữLiệuTriểnKhai))  
      abi.encodePacked(bytes1(0xff), address(SAFE_PROXY_FACTORY), salt, keccak256(deploymentData))  
    // );  
    );  
  
    // trả_về địa_chỉ(số_nguyên_không_dấu_160(số_nguyên_không_dấu_256(băm)));  
    return address(uint160(uint256(hash)));  
  // }  
  }  
  
   /**  
   * @notice One-shot guard that marks the Safe as configured by writing to a custom storage slot.  
   * @notice Bộ_bảo_vệ một_lần đánh_dấu Safe là đã_cấu_hình bằng cách ghi vào ô lưu_trữ tùy_chỉnh.  
   * @dev Reverts if the slot is already non-zero. Invoked from `configureSmartAccount` only.  
   * @dev Hoàn_tác nếu ô đã khác_không. Chỉ được gọi từ `cấuHìnhTàiKhoảnThôngMinh`.  
   */  
  // hàm _đặtĐãCấuHình() nội_bộ {  
  function _setConfigured() internal {  
    // bytes32 ô = Ô_ĐÃ_CẤU_HÌNH;  
    bytes32 slot = CONFIGURED_SLOT;  
    // số_nguyên_không_dấu_256 đãCấuHình;  
    uint256 configured;  
    // assembly {  
    assembly {  
      // đãCấuHình := sload(ô)  
      configured := sload(slot)  
    // }  
    }  
    // yêu_cầu(đãCấuHình == 0, ĐãCấuHìnhRồi());  
    require(configured == 0, AlreadyConfigured());  
    // assembly {  
    assembly {  
      // sstore(ô, 1)  
      sstore(slot, 1)  
    // }  
    }  
  // }  
  }  
  
  /**  
   * @notice Builds the `Safe.setup` initializer that runs `configureSmartAccount` via delegatecall.  
   * @notice Xây_dựng bộ_khởi_tạo `Safe.setup` chạy `cấuHìnhTàiKhoảnThôngMinh` qua gọi_ủy_quyền.  
   * @return The ABI-encoded `Safe.setup` calldata used by `SafeProxyFactory.createProxyWithNonce`.  
   * @return Dữ_liệu_gọi `Safe.setup` được mã_hóa ABI dùng bởi `SafeProxyFactory.tạoProxyVớiSốThứTự`.  
   */  
  // hàm _xâyDựngKhởiTạo(  
  function _buildInitializer(  
    // địa_chỉ[] bộ_nhớ đại_diện_s,  
    address[] memory delegates,  
    // địa_chỉ[] bộ_nhớ tiền_tệ_s,  
    address[] memory currencies,  
    // địa_chỉ[] bộ_nhớ bộSưuTậpNFT_s,  
    address[] memory nftCollections,  
    // địa_chỉ[] bộ_nhớ người_nhận_tin_cậy_s,  
    address[] memory trustedRecipients,  
    // số_nguyên_không_dấu_48 hợpLệĐến,  
    uint48 validUntil,  
    // địa_chỉ[] bộ_nhớ chủ_sở_hữu_s,  
    address[] memory owners,  
    // số_nguyên_không_dấu_256 ngưỡng  
    uint256 threshold  
  // ) nội_bộ xem trả_về (bytes bộ_nhớ) {  
  ) internal view returns (bytes memory) {  
    // bytes bộ_nhớ dữLiệuCấuHình = abi.mãHóaVớiBộChọn(  
    bytes memory configureData = abi.encodeWithSelector(  
      // this.cấuHìnhTàiKhoảnThôngMinh.selector,  
      this.configureSmartAccount.selector,  
      // đại_diện_s,  
      delegates,  
      // tiền_tệ_s,  
      currencies,  
      // bộSưuTậpNFT_s,  
      nftCollections,  
      // người_nhận_tin_cậy_s,  
      trustedRecipients,  
      // hợpLệĐến  
      validUntil  
    // );  
    );  
  
    // trả_về  
    return  
      // abi.mãHóaVớiBộChọn(  
      abi.encodeWithSelector(  
        // ISafe.setup.selector,  
        ISafe.setup.selector,  
        // chủ_sở_hữu_s, // chủ_sở_hữu cuối_cùng từ đầu  
        owners, // final owners from the start  
        // ngưỡng, // ngưỡng cuối_cùng  
        threshold, // final threshold  
        // địa_chỉ(this), // đến: hợp_đồng nhà_máy này để gọi_ủy_quyền  
        address(this), // to: this factory contract for delegatecall  
        // dữLiệuCấuHình, // dữ_liệu: cuộc_gọi cấu_hình  
        configureData, // data: configuration call  
        // địa_chỉ(0), // trìnhXửLýDựPhòng  
        address(0), // fallbackHandler  
        // địa_chỉ(0), // tokenThanhToán  
        address(0), // paymentToken  
        // 0, // thanh_toán  
        0, // payment  
        // địa_chỉ(0) // người_nhận_thanh_toán  
        address(0) // paymentReceiver  
      // );  
      );  
  // }  
  }
}
