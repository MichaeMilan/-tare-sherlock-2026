// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import {Rescuable} from "contracts/misc/Rescuable.sol";
import {ILoansExchange, SaleOffer} from "contracts/interfaces/ILoansExchange.sol";
import {ILoansNFT} from "contracts/interfaces/ILoansNFT.sol";
import {ILoans, Roles} from "contracts/interfaces/ILoans.sol";
import {ILoansAuth} from "contracts/misc/interfaces/ILoansAuth.sol";

/**  
 * @title LoansExchange  
 * Tiêu_đề LoansExchange  
 * @notice Peer-to-peer marketplace for transferring Loan NFTs between registered  
 * @notice Thị_trường ngang_hàng để chuyển NFT Khoản_vay giữa các  
 *         investors against an ERC20 payment.  
 *         nhà_đầu_tư đã_đăng_ký đổi lấy khoản_thanh_toán ERC20.  
 * @dev Sellers create directed offers naming a specific buyer, locking the Loan  
 * @dev Người_bán tạo các đề_nghị có_hướng đặt_tên một người_mua cụ_thể, khóa các  
 *      NFTs to the exchange for the offer's lifetime. The named buyer atomically  
 *      NFT Khoản_vay vào sàn_giao_dịch trong suốt thời_gian tồn_tại của đề_nghị. Người_mua được_đặt_tên nguyên_tử  
 *      pays the seller and receives the NFTs by calling `acceptOffer`. Sellers  
 *      thanh_toán cho người_bán và nhận NFT bằng cách gọi `chấpNhậnĐềNghị`. Người_bán  
 *      can `cancelOffer` to unlock their NFTs; the guardian can `forceCancelOffer`  
 *      có_thể `hủyĐềNghị` để mở_khóa NFT của họ; người_giám_hộ có_thể `buộcHủyĐềNghị`  
 *      as a recovery action. Both buyer and seller must be registered as  
 *      như một hành_động khôi_phục. Cả người_mua và người_bán phải được đăng_ký là  
 *      `Investor` for each other under the loans contract's auth registry.  
 *      `NhàĐầuTư` cho nhau trong sổ_đăng_ký xác_thực của hợp_đồng khoản_vay.  
 */  
// hợp_đồng LoansExchange là ILoansExchange, Rescuable, ReentrancyGuardTransient {  
contract LoansExchange is ILoansExchange, Rescuable, ReentrancyGuardTransient {  
  // sử_dụng SafeERC20 cho IERC20;  
  using SafeERC20 for IERC20;  
  
  /// @notice The `Loans` contract whose NFTs are tradable here.  
  // Hợp_đồng `Loans` có NFT có_thể giao_dịch ở đây.  
  // ILoans public immutable KHOẢN_VAY;  
  ILoans public immutable LOANS;  
  
  /// @notice The `LoansNFT` contract that tokenises loan ownership.  
  // Hợp_đồng `LoansNFT` mã_hóa_token quyền_sở_hữu khoản_vay.  
  // ILoansNFT public immutable NFT_KHOẢN_VAY;  
  ILoansNFT public immutable LOANS_NFT;  
  
  /// @notice The ERC20 used to settle offers (matches `LOANS.currency()`).  
  // ERC20 được dùng để thanh_toán đề_nghị (khớp với `KHOẢN_VAY.tiền_tệ()`).  
  // IERC20 public immutable TIỀN_TỆ;  
  IERC20 public immutable CURRENCY;  
  
  /// @notice Monotonic counter of created offers. The next offer's id is `offerCount + 1`.  
  // Bộ_đếm đơn_điệu của các đề_nghị đã_tạo. Id của đề_nghị tiếp_theo là `sốLượngĐềNghị + 1`.  
  // số_nguyên_không_dấu_64 public sốLượngĐềNghị;  
  uint64 public offerCount;  
  
  /// @inheritdoc ILoansExchange  
  // Kế_thừa từ ILoansExchange  
  // số_nguyên_không_dấu_64 public sốKhoảnVayTốiĐaChoMỗiĐềNghị = 100;  
  uint64 public maxLoansPerOffer = 100;  
  
  // mapping(số_nguyên_không_dấu_64 mãĐềNghị => ĐềNghịBán đềNghị) internal _đềNghị_s;  
  mapping(uint64 offerId => SaleOffer offer) internal _offers;  
  
  // constructor(ILoansNFT _NFT_khoản_vay, ILoans _khoản_vay, địa_chỉ người_giám_hộ_ban_đầu, địa_chỉ địa_chỉ_khôi_phục_ban_đầu) {  
  constructor(ILoansNFT _loansNFT, ILoans _loans, address initialGuardian, address initialRecoveryAddress) {  
    // yêu_cầu(địa_chỉ(_NFT_khoản_vay) != địa_chỉ(0), ĐịaChỉKhông());  
    require(address(_loansNFT) != address(0), ZeroAddress());  
    // yêu_cầu(địa_chỉ(_khoản_vay) != địa_chỉ(0), ĐịaChỉKhông());  
    require(address(_loans) != address(0), ZeroAddress());  
    // _khởiTạoNgườiGiámHộ(người_giám_hộ_ban_đầu);  
    _initGuardian(initialGuardian);  
    // _khởiTạoĐịaChỉKhôiPhục(địa_chỉ_khôi_phục_ban_đầu);  
    _initRecoveryAddress(initialRecoveryAddress);  
    // NFT_KHOẢN_VAY = _NFT_khoản_vay;  
    LOANS_NFT = _loansNFT;  
    // KHOẢN_VAY = _khoản_vay;  
    LOANS = _loans;  
    // TIỀN_TỆ = _khoản_vay.tiền_tệ();  
    CURRENCY = _loans.currency();  
  // }  
  }  
  
  /// @inheritdoc ILoansExchange  
  // Kế_thừa từ ILoansExchange  
  // hàm đặtSốKhoảnVayTốiĐaChoMỗiĐềNghị(số_nguyên_không_dấu_64 tốiĐaMới) bên_ngoài chỉQuảnTrịViênHoặcNgườiGiámHộ {  
  function setMaxLoansPerOffer(uint64 newMax) external onlyAdminOrGuardian {  
    // yêu_cầu(tốiĐaMới > 0, SốKhoảnVayTốiĐaChoMỗiĐềNghịKhôngHợpLệ());  
    require(newMax > 0, InvalidMaxLoansPerOffer());  
    // sốKhoảnVayTốiĐaChoMỗiĐềNghị = tốiĐaMới;  
    maxLoansPerOffer = newMax;  
    // phát_sự_kiện SốKhoảnVayTốiĐaChoMỗiĐềNghịĐãCậpNhật(tốiĐaMới);  
    emit MaxLoansPerOfferUpdated(newMax);  
  // }  
  }  
  
  /// @inheritdoc ILoansExchange  
  // Kế_thừa từ ILoansExchange  
  // hàm lấyĐềNghị(số_nguyên_không_dấu_64 mãĐềNghị) bên_ngoài xem trả_về (ĐềNghịBán bộ_nhớ) {  
  function getOffer(uint64 offerId) external view returns (SaleOffer memory) {  
    // trả_về _đềNghị_s[mãĐềNghị];  
    return _offers[offerId];  
  // }  
  }  
  
  /// @inheritdoc ILoansExchange  
  // Kế_thừa từ ILoansExchange  
  // hàm tạoĐềNghị(  
  function createOffer(  
    // địa_chỉ người_mua,  
    address buyer,  
    // số_nguyên_không_dấu_128 giá,  
    uint128 price,  
    // số_nguyên_không_dấu_48 hạnChót,  
    uint48 deadline,  
    // số_nguyên_không_dấu_64[] dữ_liệu_gọi mãKhoảnVay_s  
    uint64[] calldata loanIds  
  // ) bên_ngoài khiKhôngDừng khôngTáiNhậpCảnh trả_về (số_nguyên_không_dấu_64 mãĐềNghị) {  
  ) external whenNotPaused nonReentrant returns (uint64 offerId) {  
    // số_nguyên_không_dấu_256 độDàiMãKhoảnVay = mãKhoảnVay_s.độ_dài;  
    uint256 loanIdsLength = loanIds.length;  
    // yêu_cầu(độDàiMãKhoảnVay > 0 && độDàiMãKhoảnVay <= sốKhoảnVayTốiĐaChoMỗiĐềNghị, ĐộDàiMãKhoảnVayKhôngHợpLệ());  
    require(loanIdsLength > 0 && loanIdsLength <= maxLoansPerOffer, InvalidLoanIdsLength());  
    // yêu_cầu(msg.người_gửi != người_mua && người_mua != địa_chỉ(0), NgườiMuaKhôngHợpLệ());  
    require(msg.sender != buyer && buyer != address(0), InvalidBuyer());  
    // yêu_cầu(hạnChót > block.dấu_thời_gian, HạnChótKhôngHợpLệ());  
    require(deadline > block.timestamp, InvalidDeadline());  
    // yêu_cầu(ILoansAuth(địa_chỉ(KHOẢN_VAY)).đãĐăngKýChoVaiTrò(msg.người_gửi, VaiTrò.NhàĐầuTư, người_mua), NgườiMuaChưaĐăngKý());  
    require(ILoansAuth(address(LOANS)).isRegisteredForRole(msg.sender, Roles.Investor, buyer), BuyerNotRegistered());  
  
    // mãĐềNghị = ++sốLượngĐềNghị;  
    offerId = ++offerCount;  
  
    // for (số_nguyên_không_dấu_256 i = 0; i < độDàiMãKhoảnVay; ++i) {  
    for (uint256 i = 0; i < loanIdsLength; ++i) {  
      // số_nguyên_không_dấu_64 mã_khoản_vay = mãKhoảnVay_s[i];  
      uint64 loanId = loanIds[i];  
      // yêu_cầu(NFT_KHOẢN_VAY.chủSởHữuCủa(số_nguyên_không_dấu_256(mã_khoản_vay)) == msg.người_gửi, KhôngPhảiChủSởHữuKhoảnVay());  
      require(LOANS_NFT.ownerOf(uint256(loanId)) == msg.sender, NotLoanOwner());  
      // yêu_cầu(NFT_KHOẢN_VAY.lấyĐãKhóa(số_nguyên_không_dấu_256(mã_khoản_vay)) == địa_chỉ(0), KhoảnVayĐãKhóa());  
      require(LOANS_NFT.getLocked(uint256(loanId)) == address(0), LoanLocked());  
  
      // NFT_KHOẢN_VAY.khóa(địa_chỉ(this), số_nguyên_không_dấu_256(mã_khoản_vay));  
      LOANS_NFT.lock(address(this), uint256(loanId));  
    // }  
    }  
  
    // _đềNghị_s[mãĐềNghị] = ĐềNghịBán({  
    _offers[offerId] = SaleOffer({  
      // người_bán: msg.người_gửi,  
      seller: msg.sender,  
      // người_mua: người_mua,  
      buyer: buyer,  
      // giá: giá,  
      price: price,  
      // hạnChót: hạnChót,  
      deadline: deadline,  
      // mãKhoảnVay_s: mãKhoảnVay_s  
      loanIds: loanIds  
    // });  
    });  
  
    // phát_sự_kiện ĐềNghịĐãTạo(mãĐềNghị, msg.người_gửi, người_mua, giá, hạnChót, mãKhoảnVay_s);  
    emit OfferCreated(offerId, msg.sender, buyer, price, deadline, loanIds);  
  // }  
  }  
  
  /// @inheritdoc ILoansExchange  
  // Kế_thừa từ ILoansExchange  
  // hàm chấpNhậnĐềNghị(số_nguyên_không_dấu_64 mãĐềNghị) bên_ngoài khiKhôngDừng khôngTáiNhậpCảnh {  
  function acceptOffer(uint64 offerId) external whenNotPaused nonReentrant {  
    // ĐềNghịBán lưu_trữ đềNghị = _đềNghị_s[mãĐềNghị];  
    SaleOffer storage offer = _offers[offerId];  
  
    // An inactive offer has `buyer == address(0)`, which `msg.sender` can never equal.  
    // Một đề_nghị không_hoạt_động có `người_mua == địa_chỉ(0)`, mà `msg.người_gửi` không_bao_giờ có_thể bằng.  
    // yêu_cầu(msg.người_gửi == đềNghị.người_mua, KhôngPhảiNgườiNhậnĐềNghị());  
    require(msg.sender == offer.buyer, NotOfferRecipient());  
    // yêu_cầu(block.dấu_thời_gian <= đềNghị.hạnChót, ĐềNghịĐãHếtHạn());  
    require(block.timestamp <= offer.deadline, OfferExpired());  
  
    // địa_chỉ người_bán = đềNghị.người_bán;  
    address seller = offer.seller;  
    // số_nguyên_không_dấu_128 giá = đềNghị.giá;  
    uint128 price = offer.price;  
  
    // yêu_cầu(ILoansAuth(địa_chỉ(KHOẢN_VAY)).đãĐăngKýChoVaiTrò(người_bán, VaiTrò.NhàĐầuTư, msg.người_gửi), NgườiMuaChưaĐăngKý());  
    require(ILoansAuth(address(LOANS)).isRegisteredForRole(seller, Roles.Investor, msg.sender), BuyerNotRegistered());  
    // yêu_cầu(ILoansAuth(địa_chỉ(KHOẢN_VAY)).đãĐăngKýChoVaiTrò(msg.người_gửi, VaiTrò.NhàĐầuTư, người_bán), NgườiBánChưaĐăngKý());  
    require(ILoansAuth(address(LOANS)).isRegisteredForRole(msg.sender, Roles.Investor, seller), SellerNotRegistered());  
  
    // số_nguyên_không_dấu_64[] bộ_nhớ mãKhoảnVay_s = _xóaĐềNghị(mãĐềNghị);  
    uint64[] memory loanIds = _removeOffer(offerId);  
  
    // Send Loan NFTs to the buyer first, before any cash moves.  
    // Gửi NFT Khoản_vay cho người_mua trước, trước khi bất_kỳ tiền_mặt nào di_chuyển.  
    // số_nguyên_không_dấu_256 độDàiMãKhoảnVay = mãKhoảnVay_s.độ_dài;  
    uint256 loanIdsLength = loanIds.length;  
    // for (số_nguyên_không_dấu_256 i = 0; i < độDàiMãKhoảnVay; ++i) {  
    for (uint256 i = 0; i < loanIdsLength; ++i) {  
      // NFT_KHOẢN_VAY.chuyểnTừ(người_bán, msg.người_gửi, số_nguyên_không_dấu_256(mãKhoảnVay_s[i]));  
      LOANS_NFT.transferFrom(seller, msg.sender, uint256(loanIds[i]));  
    // }  
    }  
  
    // Pull currency from the buyer to the seller last.  
    // Kéo tiền_tệ từ người_mua đến người_bán cuối_cùng.  
    // nếu (giá > 0) {  
    if (price > 0) {  
      // TIỀN_TỆ.chuyểnAnToànTừ(msg.người_gửi, người_bán, số_nguyên_không_dấu_256(giá));  
      CURRENCY.safeTransferFrom(msg.sender, seller, uint256(price));  
    // }  
    }  
  
    // phát_sự_kiện ĐềNghịĐãChấpNhận(mãĐềNghị, người_bán, msg.người_gửi, giá);  
    emit OfferAccepted(offerId, seller, msg.sender, price);  
  // }  
  }

   /// @inheritdoc ILoansExchange  
  // Kế_thừa từ ILoansExchange  
  // hàm buộcHủyĐềNghị(số_nguyên_không_dấu_64 mãĐềNghị) bên_ngoài chỉVaiTrò(VAI_TRÒ_NGƯỜI_GIÁM_HỘ) khôngTáiNhậpCảnh {  
  function forceCancelOffer(uint64 offerId) external onlyRole(GUARDIAN_ROLE) nonReentrant {  
    // địa_chỉ người_bán = _đềNghị_s[mãĐềNghị].người_bán;  
    address seller = _offers[offerId].seller;  
    // số_nguyên_không_dấu_64[] bộ_nhớ mãKhoảnVay_s = _xóaĐềNghị(mãĐềNghị);  
    uint64[] memory loanIds = _removeOffer(offerId);  
  
    // _mởKhóaKhoảnVay_s(mãKhoảnVay_s);  
    _unlockLoans(loanIds);  
  
    // phát_sự_kiện ĐềNghịBịBuộcHủy(mãĐềNghị, người_bán);  
    emit OfferForceCancelled(offerId, seller);  
  // }  
  }  
  
  /// @inheritdoc ILoansExchange  
  // Kế_thừa từ ILoansExchange  
  // hàm hủyĐềNghị(số_nguyên_không_dấu_64 mãĐềNghị) bên_ngoài khiKhôngDừng khôngTáiNhậpCảnh {  
  function cancelOffer(uint64 offerId) external whenNotPaused nonReentrant {  
    // yêu_cầu(_đềNghị_s[mãĐềNghị].người_bán == msg.người_gửi, KhôngPhảiNgườiBán());  
    require(_offers[offerId].seller == msg.sender, NotSeller());  
  
    // số_nguyên_không_dấu_64[] bộ_nhớ mãKhoảnVay_s = _xóaĐềNghị(mãĐềNghị);  
    uint64[] memory loanIds = _removeOffer(offerId);  
    // _mởKhóaKhoảnVay_s(mãKhoảnVay_s);  
    _unlockLoans(loanIds);  
  
    // phát_sự_kiện ĐềNghịĐãHủy(mãĐềNghị);  
    emit OfferCancelled(offerId);  
  // }  
  }  
  
  /**  
   * @dev Validates an offer is active, reads its fields, then deletes the offer struct.  
   * @dev Xác_thực một đề_nghị đang_hoạt_động, đọc các trường của nó, sau đó xóa struct đề_nghị.  
   *      Does not perform caller authorization — each call site handles its own auth  
   *      Không thực_hiện ủy_quyền người_gọi — mỗi vị_trí gọi xử_lý xác_thực của riêng mình  
   *      before calling this helper. Does not unlock loans — callers handle the unlock  
   *      trước khi gọi hàm_trợ_giúp này. Không mở_khóa khoản_vay — người_gọi xử_lý chiến_lược  
   *      strategy (explicit unlock for cancellation, implicit via transfer for acceptance).  
   *      mở_khóa (mở_khóa rõ_ràng để hủy, ngầm_định qua chuyển để chấp_nhận).  
   */  
  // hàm _xóaĐềNghị(số_nguyên_không_dấu_64 mãĐềNghị) nội_bộ trả_về (số_nguyên_không_dấu_64[] bộ_nhớ mãKhoảnVay_s) {  
  function _removeOffer(uint64 offerId) internal returns (uint64[] memory loanIds) {  
    // ĐềNghịBán lưu_trữ đềNghị = _đềNghị_s[mãĐềNghị];  
    SaleOffer storage offer = _offers[offerId];  
  
    // yêu_cầu(đềNghị.người_mua != địa_chỉ(0), ĐềNghịKhôngHoạtĐộng());  
    require(offer.buyer != address(0), OfferInactive());  
  
    // mãKhoảnVay_s = đềNghị.mãKhoảnVay_s;  
    loanIds = offer.loanIds;  
  
    // delete _đềNghị_s[mãĐềNghị];  
    delete _offers[offerId];  
  // }  
  }  
  
  /**  
   * @dev Unlocks every loan in `loanIds` from the exchange. Assumes the caller has  
   * @dev Mở_khóa mọi khoản_vay trong `mãKhoảnVay_s` khỏi sàn_giao_dịch. Giả_định người_gọi đã  
   *      already removed the offer from storage; while an offer is active every listed  
   *      xóa đề_nghị khỏi lưu_trữ; trong khi đề_nghị đang_hoạt_động mọi khoản_vay được_liệt_kê  
   *      loan is locked with the exchange as unlocker, so the unlock cannot revert.  
   *      bị khóa với sàn_giao_dịch là người_mở_khóa, vì vậy việc mở_khóa không_thể hoàn_tác.  
   */  
  // hàm _mởKhóaKhoảnVay_s(số_nguyên_không_dấu_64[] bộ_nhớ mãKhoảnVay_s) nội_bộ {  
  function _unlockLoans(uint64[] memory loanIds) internal {  
    // số_nguyên_không_dấu_256 độDàiMãKhoảnVay = mãKhoảnVay_s.độ_dài;  
    uint256 loanIdsLength = loanIds.length;  
  
    // for (số_nguyên_không_dấu_256 i = 0; i < độDàiMãKhoảnVay; ++i) {  
    for (uint256 i = 0; i < loanIdsLength; ++i) {  
      // NFT_KHOẢN_VAY.mởKhóa(số_nguyên_không_dấu_256(mãKhoảnVay_s[i]));  
      LOANS_NFT.unlock(uint256(loanIds[i]));  
    // }  
    }  
  // }  
}
