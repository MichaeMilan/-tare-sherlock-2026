// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;

import {GuardianAccessControl} from "contracts/misc/GuardianAccessControl.sol";
import {ILoans, LoanValue, LoanStatus} from "contracts/interfaces/ILoans.sol";
import {INavCalculator, ValuationBucket} from "contracts/interfaces/INavCalculator.sol";

/**  
 * @title NavCalculator  
 * Tiêu_đề NavCalculator  
 * @notice Default loan valuation strategy for the Portfolio Vault.  
 * @notice Chiến_lược định_giá khoản_vay mặc_định cho Portfolio Vault.  
 * Fetches loan data from the Loans contract and applies configurable  
 * Lấy dữ_liệu khoản_vay từ hợp_đồng Loans và áp_dụng các hệ_số chiết_khấu  
 * DPD-based discount factors to loan face values. Each of 6 buckets  
 * dựa_trên DPD có_thể_cấu_hình cho giá_trị mệnh_giá khoản_vay. Mỗi trong số 6 nhóm  
 * (Current, DQ30, DQ60, DQ90, DQ120, ChargedOff) has an independently  
 * (Hiện_tại, DQ30, DQ60, DQ90, DQ120, ĐãXóaNợ) có một  
 * configurable factor in WAD (1e18 = 100%).  
 * hệ_số có_thể_cấu_hình độc_lập theo WAD (1e18 = 100%).  
 * Additionally, it supports a portfolio-level adjustment factor that can be applied to  
 * Ngoài_ra, nó hỗ_trợ một hệ_số điều_chỉnh cấp danh_mục có_thể được áp_dụng cho  
 * the aggregated NAV after summing individual loan values, allowing for manual adjustments  
 * NAV tổng_hợp sau khi cộng các giá_trị khoản_vay riêng_lẻ, cho phép điều_chỉnh thủ_công  
 * to the overall portfolio valuation.  
 * đối_với định_giá danh_mục tổng_thể.  
 */  
// hợp_đồng NavCalculator là INavCalculator, GuardianAccessControl {  
contract NavCalculator is INavCalculator, GuardianAccessControl {  
  // số_nguyên_không_dấu_256 nội_bộ constant ĐƠN_VỊ_WAD = 1e18; // 100% theo WAD  
  uint256 internal constant WAD_UNIT = 1e18; // 100% in WAD  
  // số_nguyên_không_dấu_256 nội_bộ constant HỆ_SỐ_DANH_MỤC_TỐI_ĐA_BAN_ĐẦU = 2e18;  
  uint256 internal constant INITIAL_MAX_PORTFOLIO_FACTOR = 2e18;  
  
  // bytes32 public constant ĐẠI_LÝ_TÍNH_TOÁN = keccak256("CALCULATING_AGENT");  
  bytes32 public constant CALCULATING_AGENT = keccak256("CALCULATING_AGENT");  
  
  // mapping(NhómĐịnhGiá nhóm => số_nguyên_không_dấu_256 hệ_số) public hệSốChiếtKhấu_s;  
  mapping(ValuationBucket bucket => uint256 factor) public discountFactors;  
  // số_nguyên_không_dấu_256 public hệSốDanhMục;  
  uint256 public portfolioFactor;  
  // số_nguyên_không_dấu_256 public hệSốDanhMụcTốiĐa;  
  uint256 public maxPortfolioFactor;  
  
  /// @inheritdoc INavCalculator  
  // Kế_thừa từ INavCalculator  
  // số_nguyên_không_dấu_256 public phiênBảnCấuHình;  
  uint256 public configurationVersion;  
  
  // ─────────────────────── Modifiers ────────────────  
  // ─────────────────────── Bộ_biến_đổi ────────────────  
  
  /**  
   * @dev Bumps `configurationVersion` after the decorated function runs so external  
   * @dev Tăng `phiênBảnCấuHình` sau khi hàm được_trang_trí chạy để các  
   *      consumers (e.g. `PortfolioVault`) detect that any cached NAV computed  
   *      người_dùng bên_ngoài (ví_dụ `PortfolioVault`) phát_hiện rằng bất_kỳ NAV đã_lưu_vào_bộ_nhớ_đệm nào được tính_toán  
   *      against the previous configuration is now stale.  
   *      dựa_trên cấu_hình trước đó hiện đã lỗi_thời.  
   */  
  // bộ_biến_đổi tăngPhiênBảnCấuHình() {  
  modifier bumpsConfigurationVersion() {  
    // _;  
    _;  
    // _tăngPhiênBảnCấuHình();  
    _bumpConfigurationVersion();  
  // }  
  }  
  
  /**  
   * @notice Deploys the NavCalculator with initial discount factors  
   * @notice Triển_khai NavCalculator với các hệ_số chiết_khấu ban_đầu  
   * @param initialGuardian Address that receives GUARDIAN_ROLE  
   * @param initialGuardian Địa_chỉ nhận VAI_TRÒ_NGƯỜI_GIÁM_HỘ  
   * @param initialFactors Array of 8 discount factors ordered by ValuationBucket enum:  
   * @param initialFactors Mảng gồm 8 hệ_số chiết_khấu được sắp_xếp theo enum ValuationBucket:  
   *   [Current, DQ30, DQ60, DQ90, DQ120, ChargedOff, Closed, Cancelled]  
   *   [Hiện_tại, DQ30, DQ60, DQ90, DQ120, ĐãXóaNợ, ĐãĐóng, ĐãHủy]  
   */  
  // constructor(địa_chỉ người_giám_hộ_ban_đầu, số_nguyên_không_dấu_256[8] bộ_nhớ hệSốBanĐầu_s) {  
  constructor(address initialGuardian, uint256[8] memory initialFactors) {  
    // yêu_cầu(người_giám_hộ_ban_đầu != địa_chỉ(0), ĐịaChỉKhông());  
    require(initialGuardian != address(0), ZeroAddress());  
  
    // _khởiTạoNgườiGiámHộ(người_giám_hộ_ban_đầu);  
    _initGuardian(initialGuardian);  
    // _đặtQuảnTrịVaiTrò(ĐẠI_LÝ_TÍNH_TOÁN, VAI_TRÒ_NGƯỜI_GIÁM_HỘ);  
    _setRoleAdmin(CALCULATING_AGENT, GUARDIAN_ROLE);  
  
    // for (số_nguyên_không_dấu_256 i; i < 8; ++i) {  
    for (uint256 i; i < 8; ++i) {  
      // yêu_cầu(hệSốBanĐầu_s[i] <= ĐƠN_VỊ_WAD, HệSốVượtWad());  
      require(initialFactors[i] <= WAD_UNIT, FactorExceedsWad());  
      // hệSốChiếtKhấu_s[NhómĐịnhGiá(i)] = hệSốBanĐầu_s[i];  
      discountFactors[ValuationBucket(i)] = initialFactors[i];  
    // }  
    }  
  
    // hệSốDanhMục = ĐƠN_VỊ_WAD; // mặc_định là 1.0 (không điều_chỉnh)  
    portfolioFactor = WAD_UNIT; // default to 1.0 (no adjustment)  
    // hệSốDanhMụcTốiĐa = HỆ_SỐ_DANH_MỤC_TỐI_ĐA_BAN_ĐẦU;  
    maxPortfolioFactor = INITIAL_MAX_PORTFOLIO_FACTOR;  
    // phiênBảnCấuHình = 1;  
    configurationVersion = 1;  
  // }  
  }  
  
  // ──────────────────────── External Functions ────────────────────  
  // ──────────────────────── Hàm Bên_ngoài ────────────────────  
  
  /// @inheritdoc INavCalculator  
  // Kế_thừa từ INavCalculator  
  // hàm lấyGiáTrịKhoảnVay_s(ILoans khoản_vay_s, số_nguyên_không_dấu_64[] dữ_liệu_gọi mãKhoảnVay_s) bên_ngoài xem trả_về (số_nguyên_không_dấu_256 tổngGiáTrị) {  
  function getLoansValue(ILoans loans, uint64[] calldata loanIds) external view returns (uint256 totalValue) {  
    // GiáTrịKhoảnVay[] bộ_nhớ giáTrịKhoảnVay_s = khoản_vay_s.lấyGiáTrịKhoảnVay(mãKhoảnVay_s);  
    LoanValue[] memory loanValues = loans.getLoanValues(loanIds);  
    // số_nguyên_không_dấu_256 độ_dài = giáTrịKhoảnVay_s.độ_dài;  
    uint256 len = loanValues.length;  
  
    // for (số_nguyên_không_dấu_256 i; i < độ_dài; ++i) {  
    for (uint256 i; i < len; ++i) {  
      // GiáTrịKhoảnVay bộ_nhớ dữLiệuKhoảnVay = giáTrịKhoảnVay_s[i];  
      LoanValue memory loanData = loanValues[i];  
  
      // nếu (dữLiệuKhoảnVay.trạng_thái == TrạngTháiKhoảnVay.KhôngTồnTại) tiếp_tục;  
      if (loanData.status == LoanStatus.DoesNotExist) continue;  
  
      // Cash already collected for the investor — principal and waterfall-allocated interest sitting  
      // Tiền_mặt đã_thu_thập cho nhà_đầu_tư — vốn_gốc và lãi được phân_bổ theo thác_nước đang nằm  
      // in Loans.sol awaiting withdrawal — has no credit risk and contributes at par.  
      // trong Loans.sol chờ rút — không có rủi_ro tín_dụng và đóng_góp theo mệnh_giá.  
      // số_nguyên_256 tiềnMặtĐãThu = số_nguyên_256(dữLiệuKhoảnVay.vốnGốcNhàĐầuTưCóThểRút) +  
      int256 collectedCash = int256(loanData.investorPrincipalWithdrawable) +  
        // số_nguyên_256(dữLiệuKhoảnVay.lãiNhàĐầuTưCóThểRút);  
        int256(loanData.investorInterestWithdrawable);  
      // nếu (tiềnMặtĐãThu < 0) tiềnMặtĐãThu = 0;  
      if (collectedCash < 0) collectedCash = 0;  
  
      // Investor principal still out with the borrower — the only portion exposed to credit risk  
      // Vốn_gốc nhà_đầu_tư vẫn còn với người_vay — phần duy_nhất chịu rủi_ro tín_dụng  
      // and the only portion the bucket factor applies to.  
      // và phần duy_nhất mà hệ_số nhóm áp_dụng cho.  
      // số_nguyên_256 vốnGốcNhàĐầuTưChưaHoànTrả = số_nguyên_256(dữLiệuKhoảnVay.vốnGốcNhàĐầuTưCòn_lại) -  
      int256 unreturnedInvestorPrincipal = int256(loanData.outstandingInvestorPrincipal) -  
        // số_nguyên_256(dữLiệuKhoảnVay.vốnGốcNhàĐầuTưCóThểRút);  
        int256(loanData.investorPrincipalWithdrawable);  
      // nếu (vốnGốcNhàĐầuTưChưaHoànTrả < 0) vốnGốcNhàĐầuTưChưaHoànTrả = 0;  
      if (unreturnedInvestorPrincipal < 0) unreturnedInvestorPrincipal = 0;  
  
      // số_nguyên_không_dấu_256 vốnGốcĐãÁpHệSố = (số_nguyên_không_dấu_256(vốnGốcNhàĐầuTưChưaHoànTrả) *  
      uint256 factoredPrincipal = (uint256(unreturnedInvestorPrincipal) *  
        // _hệSốNhóm(dữLiệuKhoảnVay.trạng_thái, dữLiệuKhoảnVay.ngàyĐếnHạnTiếpTheo)) / ĐƠN_VỊ_WAD;  
        _bucketFactor(loanData.status, loanData.nextDueDate)) / WAD_UNIT;  
  
      // tổngGiáTrị += vốnGốcĐãÁpHệSố + số_nguyên_không_dấu_256(tiềnMặtĐãThu);  
      totalValue += factoredPrincipal + uint256(collectedCash);  
    // }  
    }  
  // }  
  }  
  
  /// @inheritdoc INavCalculator  
  // Kế_thừa từ INavCalculator  
  // hàm áp_dụngĐiềuChỉnhDanhMục(số_nguyên_không_dấu_256 giáTrịThô) bên_ngoài xem trả_về (số_nguyên_không_dấu_256) {  
  function applyPortfolioAdjustment(uint256 rawValue) external view returns (uint256) {  
    // trả_về (giáTrịThô * hệSốDanhMục) / ĐƠN_VỊ_WAD;  
    return (rawValue * portfolioFactor) / WAD_UNIT;  
  // }  
  }




  /// @inheritdoc INavCalculator  
  // Kế_thừa từ INavCalculator  
  // hàm đặtHệSốDanhMục(số_nguyên_không_dấu_256 hệSố) bên_ngoài chỉVaiTrò(ĐẠI_LÝ_TÍNH_TOÁN) tăngPhiênBảnCấuHình {  
  function setPortfolioFactor(uint256 factor) external onlyRole(CALCULATING_AGENT) bumpsConfigurationVersion {  
    // yêu_cầu(hệSố <= hệSốDanhMụcTốiĐa, HệSốVượtGiớiHạn());  
    require(factor <= maxPortfolioFactor, FactorExceedsCap());  
    // hệSốDanhMục = hệSố;  
    portfolioFactor = factor;  
    // phát_sự_kiện HệSốDanhMụcĐãCậpNhật(hệSố);  
    emit PortfolioFactorUpdated(factor);  
  // }  
  }  
  
  /// @inheritdoc INavCalculator  
  // Kế_thừa từ INavCalculator  
  // hàm đặtHệSốDanhMụcTốiĐa(số_nguyên_không_dấu_256 tốiĐaMới) bên_ngoài chỉVaiTrò(VAI_TRÒ_NGƯỜI_GIÁM_HỘ) {  
  function setMaxPortfolioFactor(uint256 newMax) external onlyRole(GUARDIAN_ROLE) {  
    // hệSốDanhMụcTốiĐa = tốiĐaMới;  
    maxPortfolioFactor = newMax;  
    // phát_sự_kiện HệSốDanhMụcTốiĐaĐãCậpNhật(tốiĐaMới);  
    emit MaxPortfolioFactorUpdated(newMax);  
  
    // Clamp current portfolio factor if it now exceeds the new cap.  
    // Kẹp hệ_số danh_mục hiện_tại nếu nó vượt_quá giới_hạn mới.  
    // nếu (hệSốDanhMục > tốiĐaMới) {  
    if (portfolioFactor > newMax) {  
      // hệSốDanhMục = tốiĐaMới;  
      portfolioFactor = newMax;  
      // _tăngPhiênBảnCấuHình();  
      _bumpConfigurationVersion();  
      // phát_sự_kiện HệSốDanhMụcĐãCậpNhật(tốiĐaMới);  
      emit PortfolioFactorUpdated(newMax);  
    // }  
    }  
  // }  
  }  
  
  /// @inheritdoc INavCalculator  
  // Kế_thừa từ INavCalculator  
  // hàm đặtHệSốChiếtKhấu(  
  function setDiscountFactor(  
    // NhómĐịnhGiá nhóm,  
    ValuationBucket bucket,  
    // số_nguyên_không_dấu_256 hệSố  
    uint256 factor  
  // ) bên_ngoài chỉVaiTrò(ĐẠI_LÝ_TÍNH_TOÁN) tăngPhiênBảnCấuHình {  
  ) external onlyRole(CALCULATING_AGENT) bumpsConfigurationVersion {  
    // yêu_cầu(hệSố <= ĐƠN_VỊ_WAD, HệSốVượtWad());  
    require(factor <= WAD_UNIT, FactorExceedsWad());  
    // hệSốChiếtKhấu_s[nhóm] = hệSố;  
    discountFactors[bucket] = factor;  
    // phát_sự_kiện HệSốChiếtKhấuĐãCậpNhật(nhóm, hệSố);  
    emit DiscountFactorUpdated(bucket, factor);  
  // }  
  }  
  
  // ─────────────────────── View Functions ─────────────────────────  
  // ─────────────────────── Các Hàm Xem ─────────────────────────  
  
  /// @inheritdoc INavCalculator  
  // Kế_thừa từ INavCalculator  
  // hàm lấyHệSốChiếtKhấu(NhómĐịnhGiá nhóm) bên_ngoài xem trả_về (số_nguyên_không_dấu_256) {  
  function getDiscountFactor(ValuationBucket bucket) external view returns (uint256) {  
    // trả_về hệSốChiếtKhấu_s[nhóm];  
    return discountFactors[bucket];  
  // }  
  }  
  
  // ───────────────────── Internal Functions ─────────────────────  
  // ───────────────────── Các Hàm Nội_Bộ ─────────────────────  
  
  /**  
   * @dev Returns the discount factor for a given loan status and next-due date.  
   * @dev Trả_về hệ_số chiết_khấu cho một trạng_thái khoản_vay và ngày đến_hạn tiếp_theo nhất_định.  
   *      Active loans use a DPD-based bucket (Current, or DQ30 through DQ120 when  
   *      Các khoản_vay ĐangHoạtĐộng sử_dụng nhóm dựa_trên DPD (Hiện_tại, hoặc DQ30 đến DQ120 khi  
   *      overdue); ChargedOff, Closed and Cancelled loans use their matching status  
   *      quá_hạn); các khoản_vay ĐãXóaNợ, ĐãĐóng và ĐãHủy sử_dụng nhóm trạng_thái tương_ứng;  
   *      bucket; all other statuses (Created, FullyFunded, FullyPaid) are valued at  
   *      tất_cả các trạng_thái khác (ĐãTạo, ĐãGiảiNgânĐầyĐủ, ĐãThanhToánĐầyĐủ) được định_giá theo  
   *      par (1.0 in WAD).  
   *      mệnh_giá (1.0 theo WAD).  
   */  
  // hàm _hệSốNhóm(TrạngTháiKhoảnVay trạng_thái, số_nguyên_không_dấu_48 ngàyĐếnHạnTiếpTheo) nội_bộ xem trả_về (số_nguyên_không_dấu_256) {  
  function _bucketFactor(LoanStatus status, uint48 nextDueDate) internal view returns (uint256) {  
    // nếu (trạng_thái == TrạngTháiKhoảnVay.ĐangHoạtĐộng) {  
    if (status == LoanStatus.Active) {  
      // NhómĐịnhGiá nhóm = NhómĐịnhGiá.Hiện_tại;  
      ValuationBucket bucket = ValuationBucket.Current;  
      // nếu (ngàyĐếnHạnTiếpTheo != 0 && block.dấu_thời_gian > ngàyĐếnHạnTiếpTheo) {  
      if (nextDueDate != 0 && block.timestamp > nextDueDate) {  
        // số_nguyên_không_dấu_256 dpd = (block.dấu_thời_gian - ngàyĐếnHạnTiếpTheo) / 1 ngày;  
        uint256 dpd = (block.timestamp - nextDueDate) / 1 days;  
        // nếu (dpd > 120) nhóm = NhómĐịnhGiá.DQ120;  
        if (dpd > 120) bucket = ValuationBucket.DQ120;  
        // ngược_lại nếu (dpd > 90) nhóm = NhómĐịnhGiá.DQ90;  
        else if (dpd > 90) bucket = ValuationBucket.DQ90;  
        // ngược_lại nếu (dpd > 60) nhóm = NhómĐịnhGiá.DQ60;  
        else if (dpd > 60) bucket = ValuationBucket.DQ60;  
        // ngược_lại nếu (dpd > 30) nhóm = NhómĐịnhGiá.DQ30;  
        else if (dpd > 30) bucket = ValuationBucket.DQ30;  
      // }  
      }  
      // trả_về hệSốChiếtKhấu_s[nhóm];  
      return discountFactors[bucket];  
    // }  
    }  
    // nếu (trạng_thái == TrạngTháiKhoảnVay.ĐãXóaNợ) trả_về hệSốChiếtKhấu_s[NhómĐịnhGiá.ĐãXóaNợ];  
    if (status == LoanStatus.ChargedOff) return discountFactors[ValuationBucket.ChargedOff];  
    // nếu (trạng_thái == TrạngTháiKhoảnVay.ĐãĐóng) trả_về hệSốChiếtKhấu_s[NhómĐịnhGiá.ĐãĐóng];  
    if (status == LoanStatus.Closed) return discountFactors[ValuationBucket.Closed];  
    // nếu (trạng_thái == TrạngTháiKhoảnVay.ĐãHủy) trả_về hệSốChiếtKhấu_s[NhómĐịnhGiá.ĐãHủy];  
    if (status == LoanStatus.Cancelled) return discountFactors[ValuationBucket.Cancelled];  
    // trả_về ĐƠN_VỊ_WAD;  
    return WAD_UNIT;  
  // }  
  }  
  
  /**  
   * @dev Increments `configurationVersion` and emits `ConfigurationVersionBumped`.  
   * @dev Tăng `phiênBảnCấuHình` và phát `PhiênBảnCấuHìnhĐãTăng`.  
   *      Called by `bumpsConfigurationVersion` and directly by `setMaxPortfolioFactor`  
   *      Được gọi bởi `tăngPhiênBảnCấuHình` và trực_tiếp bởi `đặtHệSốDanhMụcTốiĐa`  
   *      when clamping forces a factor change.  
   *      khi kẹp buộc thay_đổi hệ_số.  
   */  
  // hàm _tăngPhiênBảnCấuHình() nội_bộ {  
  function _bumpConfigurationVersion() internal {  
    // unchecked {  
    unchecked {  
      // ++phiênBảnCấuHình;  
      ++configurationVersion;  
    // }  
    }  
    // phát_sự_kiện PhiênBảnCấuHìnhĐãTăng(phiênBảnCấuHình);  
    emit ConfigurationVersionBumped(configurationVersion);  
  // }  
  }
}
