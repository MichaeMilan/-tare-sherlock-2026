// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ILoansNFT} from "contracts/interfaces/ILoansNFT.sol";
import {Rescuable} from "contracts/misc/Rescuable.sol";
import {LoansLedger} from "./LoansLedger.sol";
import {
  ILoans,
  LoanData,
  LoanTerms,
  LoanStatus,
  Roles,
  InvestorWithdrawalResult,
  LoanValue,
  OriginatorWithdrawalResult,
  ServicerWithdrawalResult,
  LedgerEntryInput
} from "contracts/interfaces/ILoans.sol";
import {
  ENTRY_LOAN_COMMITMENT,
  ENTRY_INVESTOR_CAPITAL_RECEIVED,
  ENTRY_BORROWER_PAYMENT,
  ENTRY_INTEREST_ACCRUAL,
  ENTRY_BORROWER_PRINCIPAL_PAYMENT,
  ENTRY_DISBURSEMENT_TO_BORROWER,
  ENTRY_ORIGINATOR_FEE_WITHHOLDING,
  ENTRY_SERVICER_FEE_ALLOCATION,
  ENTRY_INVESTOR_INTEREST_ALLOCATION,
  ENTRY_BORROWER_INTEREST_DEBT_CLEARANCE,
  ENTRY_SERVICER_FEE_WITHDRAWAL,
  ENTRY_INVESTOR_INTEREST_WITHDRAWAL,
  ENTRY_INVESTOR_PRINCIPAL_WITHDRAWAL,
  ENTRY_MISC_FEE_CHARGE,
  ENTRY_MISC_FEE_DEBT_CLEARANCE,
  ENTRY_MISC_FEE_WITHDRAWAL,
  ENTRY_ORIGINATOR_FEE_WITHDRAWAL
} from "contracts/interfaces/LedgerEntries.sol";
import {
  ACC_BORROWER_INTEREST_PAID,
  ACC_BORROWER_MISC_FEE_PAID,
  ACC_BORROWER_INTEREST_RECEIVABLE,
  ACC_BORROWER_MISC_FEE_RECEIVABLE,
  ACC_BORROWER_PAYMENT_CLEARING,
  ACC_BORROWER_PRINCIPAL_RECEIVABLE,
  ACC_BORROWER_PRINCIPAL_REPAID,
  ACC_CASH,
  ACC_INVESTOR_INTEREST_PAID,
  ACC_INVESTOR_INTEREST_PAYABLE,
  ACC_INVESTOR_PRINCIPAL_PAYABLE,
  ACC_INVESTOR_PRINCIPAL_REPAID,
  ACC_ORIGINATOR_FEE_PAID,
  ACC_ORIGINATOR_FEE_PAYABLE,
  ACC_SERVICER_ADJUSTMENT,
  ACC_SERVICER_FEE_PAID,
  ACC_SERVICER_FEE_PAYABLE,
  ACC_SERVICER_MISC_FEE_PAID,
  ACC_SERVICER_MISC_FEE_PAYABLE,
  ACC_UNALLOCATED_BORROWER_INTEREST_PAYABLE,
  ACC_UNFUNDED_COMMITMENT
} from "contracts/interfaces/Accounts.sol";

/**  
 * @tieu_de KhoảnVay  
 * @thông_báo Sổ cái bút toán kép theo từng khoản vay và vòng đời được kiểm soát bởi vai trò:  
 *            khởi tạo, tài trợ, giải ngân, tích lũy, thanh toán, waterfall, và rút tiền.  
 * @dev Lưu ký tất cả tiền mặt tiền tệ khoản vay. Các địa chỉ vai trò (nguoiVay, nguoiKhoiTao,  
 *      nguoiDichVu) là theo từng khoản vay; nhà đầu tư khoản vay là người nắm giữ NFT được đúc  
 *      bởi `nftKhoảnVay`.  
 */  
/**  
 * @title Loans  
 * @notice Per-loan double-entry ledger and role-gated lifecycle: origination,  
 *         funding, disbursement, accrual, payments, waterfall, and withdrawals.  
 * @dev Custodies all loan-currency cash. Role addresses (borrower, originator,  
 *      servicer) are per-loan; the loan investor is the holder of the NFT minted  
 *      by `loansNFT`.  
 */  
// hợp_đồng KhoảnVay là SoCaiKhoảnVay, CoTheCuuHo, BaoVeReentrancyTamThoi {  
contract Loans is LoansLedger, Rescuable, ReentrancyGuardTransient {  
  // su_dung SafeERC20 cho IERC20;  
  using SafeERC20 for IERC20;  
  
  /// @ke_thua_tai_lieu ILoans  
  /// @inheritdoc ILoans  
  // anh_xa(uint64 maKhoảnVay => DuLieuKhoảnVay duLieuKhoảnVay) cong_khai duLieu;  
  mapping(uint64 loanId => LoanData loanData) public data;  
  
  /// @ke_thua_tai_lieu ILoans  
  /// @inheritdoc ILoans  
  // anh_xa(uint64 maKhoảnVay => DieuKhoanKhoảnVay dieuKhoan) cong_khai dieuKhoanKhoảnVay;  
  mapping(uint64 loanId => LoanTerms terms) public loanTerms;  
  
  /// @ke_thua_tai_lieu ILoans  
  /// @inheritdoc ILoans  
  // anh_xa(uint64 maKhoảnVay => address nguoiVay) cong_khai nguoiVay;  
  mapping(uint64 loanId => address borrower) public borrowers;  
  /// @ke_thua_tai_lieu ILoans  
  /// @inheritdoc ILoans  
  // anh_xa(uint64 maKhoảnVay => address nguoiKhoiTao) cong_khai nguoiKhoiTao;  
  mapping(uint64 loanId => address originator) public originators;  
  /// @ke_thua_tai_lieu ILoans  
  /// @inheritdoc ILoans  
  // anh_xa(uint64 maKhoảnVay => address nguoiDichVu) cong_khai nguoiDichVu;  
  mapping(uint64 loanId => address servicer) public servicers;  
  
  /// @ke_thua_tai_lieu ILoans  
  /// @inheritdoc ILoans  
  // ILoansNFT cong_khai nftKhoảnVay;  
  ILoansNFT public loansNFT;  
  
  // bo_sua_doi chiNguoiDichVuHoacQuanTriVien(uint64 maKhoảnVay) {  
  modifier onlyServicerOrAdmin(uint64 loanId) {  
    _onlyServicerOrAdmin(loanId);  
    _;  
  }  
  
  // bo_sua_doi chiNguoiVayHoacQuanTriVien(uint64 maKhoảnVay) {  
  modifier onlyBorrowerOrAdmin(uint64 loanId) {  
    _onlyBorrowerOrAdmin(loanId);  
    _;  
  }  
  
  // bo_sua_doi voiCapNhatKhoảnVay(uint64 maKhoảnVay, uint48 dấuThoiGian) {  
  modifier withLoanUpdate(uint64 loanId, uint48 timestamp) {  
    _;  
    _withLoanUpdate(loanId, timestamp);  
  }  
  
  // bo_sua_doi chiDangConNo(uint64 maKhoảnVay) {  
  modifier onlyOutstanding(uint64 loanId) {  
    _onlyOutstanding(loanId);  
    _;  
  }  
  
  // bo_sua_doi chiDangConNoHoacDaThanhToanDayDu(uint64 maKhoảnVay) {  
  modifier onlyOutstandingOrFullyPaid(uint64 loanId) {  
    _onlyOutstandingOrFullyPaid(loanId);  
    _;  
  }  
  
  // bo_sua_doi khongKetThuc(uint64 maKhoảnVay) {  
  modifier notTerminal(uint64 loanId) {  
    _notTerminal(loanId);  
    _;  
  }


  constructor(  
    IERC20 _currency,  
    address initialGuardian,  
    address initialRecoveryAddress  
  ) LoansLedger(_currency, initialGuardian) {  
    _initRecoveryAddress(initialRecoveryAddress);  
  }  
  

  /// @inheritdoc ILoans
  // hàm đặt_NFT_khoản_vay(địa_chỉ _NFT_khoản_vay) bên_ngoài chỉ_quản_trị_hoặc_người_giám_hộ {
  function setLoansNFT(address _loansNFT) external onlyAdminOrGuardian {
    // yêu_cầu(địa_chỉ(NFT_khoản_vay) == địa_chỉ(0), ĐãKhởiTạo());
    require(address(loansNFT) == address(0), AlreadyInitialized());
    // yêu_cầu(_NFT_khoản_vay != địa_chỉ(0), ĐịaChỉKhông());
    require(_loansNFT != address(0), ZeroAddress());
    // NFT_khoản_vay = INFTKhoảnVay(_NFT_khoản_vay);
    loansNFT = ILoansNFT(_loansNFT);
  }

  // hàm _tạo(  
function _create(  
    // địa_chỉ người_vay,  
    address borrower,  
    // địa_chỉ nhà_đầu_tư,  
    address investor,  
    // địa_chỉ đơn_vị_dịch_vụ,  
    address servicer,  
    // địa_chỉ đơn_vị_khởi_tạo,  
    address originator,  
    // số_nguyên_128 số_tiền_gốc,  
    int128 principalAmount,  
    // số_nguyên_không_dấu_48 dấu_thời_gian  
    uint48 timestamp  
  // ) nội_bộ trả_về (số_nguyên_không_dấu_64 mã_khoản_vay) {  
  ) internal returns (uint64 loanId) {  
    // yêu_cầu(người_vay != địa_chỉ(0), ĐịaChỉKhông());  
    require(borrower != address(0), ZeroAddress());  
    // yêu_cầu(nhà_đầu_tư != địa_chỉ(0), ĐịaChỉKhông());  
    require(investor != address(0), ZeroAddress());  
    // yêu_cầu(đơn_vị_dịch_vụ != địa_chỉ(0), ĐịaChỉKhông());  
    require(servicer != address(0), ZeroAddress());  
    // yêu_cầu(đơn_vị_khởi_tạo != địa_chỉ(0), ĐịaChỉKhông());  
    require(originator != address(0), ZeroAddress());  
    // yêu_cầu(số_tiền_gốc > 0, SốTiềnKhôngHợpLệ());  
    require(principalAmount > 0, InvalidAmount());  
  
    // Validate addresses against originator's address book  
    // Xác_thực địa_chỉ với sổ_địa_chỉ của đơn_vị_khởi_tạo  
    // yêu_cầu(đãĐăngKýChoVaiTrò(đơn_vị_khởi_tạo, VaiTrò.NhườiVay, người_vay), ĐịaChỉChưaĐăngKý(người_vay));  
    require(isRegisteredForRole(originator, Roles.Borrower, borrower), UnregisteredAddress(borrower));  
    // yêu_cầu(đãĐăngKýChoVaiTrò(đơn_vị_khởi_tạo, VaiTrò.NhàĐầuTư, nhà_đầu_tư), ĐịaChỉChưaĐăngKý(nhà_đầu_tư));  
    require(isRegisteredForRole(originator, Roles.Investor, investor), UnregisteredAddress(investor));  
    // yêu_cầu(đãĐăngKýChoVaiTrò(đơn_vị_khởi_tạo, VaiTrò.ĐơnVịDịchVụ, đơn_vị_dịch_vụ), ĐịaChỉChưaĐăngKý(đơn_vị_dịch_vụ));  
    require(isRegisteredForRole(originator, Roles.Servicer, servicer), UnregisteredAddress(servicer));  
  
    // mã_khoản_vay = ++số_lượng_khoản_vay;  
    loanId = ++loanCount;  
    // dữ_liệu[mã_khoản_vay].trạng_thái = TrạngTháiKhoảnVay.ĐãTạo;  
    data[loanId].status = LoanStatus.Created;  
    // dữ_liệu[mã_khoản_vay].cậpNhậtLúc = dấu_thời_gian;  
    data[loanId].updatedAt = timestamp;  
  
    // người_vay_s[mã_khoản_vay] = người_vay;  
    borrowers[loanId] = borrower;  
    // đơn_vị_dịch_vụ_s[mã_khoản_vay] = đơn_vị_dịch_vụ;  
    servicers[loanId] = servicer;  
    // đơn_vị_khởi_tạo_s[mã_khoản_vay] = đơn_vị_khởi_tạo;  
    originators[loanId] = originator;  
  
    // NFT_khoản_vay.đúc(nhà_đầu_tư, mã_khoản_vay);  
    loansNFT.mint(investor, loanId);  
  
    // _tạoMụcNộiBộ(  
    _createInternalEntry(  
      // mã_khoản_vay,  
      loanId,  
      // TÀI_KHOẢN_CAM_KẾT_CHƯA_GIẢI_NGÂN,  
      ACC_UNFUNDED_COMMITMENT,  
      // TÀI_KHOẢN_PHẢI_THU_GỐC_NGƯỜI_VAY,  
      ACC_BORROWER_PRINCIPAL_RECEIVABLE,  
      // số_tiền_gốc,  
      principalAmount,  
      // dấu_thời_gian,  
      timestamp,  
      // MỤC_CAM_KẾT_KHOẢN_VAY,  
      ENTRY_LOAN_COMMITMENT,  
      // bytes32("cam_kết_khoản_vay_ban_đầu")  
      bytes32("initial_loan_commitment")  
    // );  
    );  
  
    // phát_sự_kiện KhoảnVayĐãTạo(mã_khoản_vay);  
    emit LoanCreated(loanId);  
  // }  
  }  
  
  /// @inheritdoc ILoans  
  // Kế_thừa từ ILoans  
  // hàm tạo(  
  function create(  
    // địa_chỉ người_vay,  
    address borrower,  
    // địa_chỉ nhà_đầu_tư,  
    address investor,  
    // địa_chỉ đơn_vị_dịch_vụ,  
    address servicer,  
    // địa_chỉ đơn_vị_khởi_tạo,  
    address originator,  
    // số_nguyên_128 số_tiền_gốc,  
    int128 principalAmount,  
    // số_nguyên_không_dấu_48 dấu_thời_gian  
    uint48 timestamp  
  // ) bên_ngoài khiKhôngDừng trả_về (số_nguyên_không_dấu_64 mã_khoản_vay) {  
  ) external whenNotPaused returns (uint64 loanId) {  
    // Admin/guardian may originate on behalf of any approved originator.  
    // Quản_trị_viên/người_giám_hộ có_thể khởi_tạo thay_mặt cho bất_kỳ đơn_vị_khởi_tạo đã_được_phê_duyệt nào.  
    // Otherwise msg.sender must be the named originator AND an approved one,  
    // Nếu_không msg.người_gửi phải là đơn_vị_khởi_tạo được_đặt_tên VÀ là một đơn_vị đã_được_phê_duyệt,  
    // ensuring an approved originator cannot impersonate another originator.  
    // đảm_bảo một đơn_vị_khởi_tạo đã_được_phê_duyệt không_thể mạo_danh đơn_vị_khởi_tạo khác.  
    // yêu_cầu(_làQuảnTrịViênHoặcNgườiGiámHộ(msg.người_gửi) || msg.người_gửi == đơn_vị_khởi_tạo, KhôngĐượcPhép());  
    require(_isAdminOrGuardian(msg.sender) || msg.sender == originator, Unauthorized());  
    // yêu_cầu(đãĐăngKýChoVaiTrò(địa_chỉ(this), VaiTrò.ĐơnVịKhởiTạo, đơn_vị_khởi_tạo), ĐịaChỉChưaĐăngKý(đơn_vị_khởi_tạo));  
    require(isRegisteredForRole(address(this), Roles.Originator, originator), UnregisteredAddress(originator));  
  
    // trả_về _tạo(người_vay, nhà_đầu_tư, đơn_vị_dịch_vụ, đơn_vị_khởi_tạo, số_tiền_gốc, dấu_thời_gian);  
    return _create(borrower, investor, servicer, originator, principalAmount, timestamp);  
  // }  
  }  
  
  
  /**  
   * @inheritdoc ILoans  
   * Kế_thừa từ ILoans  
   * @dev Uses block.timestamp because the role change IS the onchain event,  
   * @dev Sử_dụng block.dấu_thời_gian vì thay_đổi vai_trò LÀ sự_kiện trên_chuỗi,  
   *      unlike ledger functions which record offchain facts at a caller-supplied date.  
   *      không_giống các hàm sổ_cái ghi_lại các sự_kiện ngoài_chuỗi tại ngày do người_gọi cung_cấp.  
   */  
  // hàm cậpNhậtNgườiVay(  
  function updateBorrower(  
    // số_nguyên_không_dấu_64 mã_khoản_vay,  
    uint64 loanId,  
    // địa_chỉ người_vay  
    address borrower  
  // ) bên_ngoài khiKhôngDừng chỉĐơnVịDịchVụHoặcQuảnTrị(mã_khoản_vay) khôngKếtThúc(mã_khoản_vay) {  
  ) external whenNotPaused onlyServicerOrAdmin(loanId) notTerminal(loanId) {  
    // yêu_cầu(người_vay != địa_chỉ(0), ĐịaChỉKhông());  
    require(borrower != address(0), ZeroAddress());  
    // yêu_cầu(đãĐăngKýChoVaiTrò(đơn_vị_dịch_vụ_s[mã_khoản_vay], VaiTrò.NhườiVay, người_vay), ĐịaChỉChưaĐăngKý(người_vay));  
    require(isRegisteredForRole(servicers[loanId], Roles.Borrower, borrower), UnregisteredAddress(borrower));  
  
    // người_vay_s[mã_khoản_vay] = người_vay;  
    borrowers[loanId] = borrower;  
    // dữ_liệu[mã_khoản_vay].cậpNhậtLúc = số_nguyên_không_dấu_48(block.dấu_thời_gian);  
    data[loanId].updatedAt = uint48(block.timestamp);  
  
    // phát_sự_kiện KhoảnVayNgườiVayĐãCậpNhật(mã_khoản_vay, người_vay);  
    emit LoanBorrowerUpdated(loanId, borrower);  
  // }  
  }

   /**  
   * @inheritdoc ILoans  
   * Kế_thừa từ ILoans  
   * @dev Uses block.timestamp because the role change IS the onchain event,  
   * @dev Sử_dụng block.dấu_thời_gian vì thay_đổi vai_trò LÀ sự_kiện trên_chuỗi,  
   *      unlike ledger functions which record offchain facts at a caller-supplied date.  
   *      không_giống các hàm sổ_cái ghi_lại các sự_kiện ngoài_chuỗi tại ngày do người_gọi cung_cấp.  
   */  
  // hàm cậpNhậtĐơnVịDịchVụ(  
  function updateServicer(  
    // số_nguyên_không_dấu_64 mã_khoản_vay,  
    uint64 loanId,  
    // địa_chỉ đơn_vị_dịch_vụ  
    address servicer  
  // ) bên_ngoài khiKhôngDừng chỉVaiTrò(VAI_TRÒ_NGƯỜI_GIÁM_HỘ) khôngKếtThúc(mã_khoản_vay) {  
  ) external whenNotPaused onlyRole(GUARDIAN_ROLE) notTerminal(loanId) {  
    // yêu_cầu(đơn_vị_dịch_vụ != địa_chỉ(0), ĐịaChỉKhông());  
    require(servicer != address(0), ZeroAddress());  
    // yêu_cầu(đãĐăngKýChoVaiTrò(địa_chỉ(this), VaiTrò.ĐơnVịDịchVụ, đơn_vị_dịch_vụ), ĐịaChỉChưaĐăngKý(đơn_vị_dịch_vụ));  
    require(isRegisteredForRole(address(this), Roles.Servicer, servicer), UnregisteredAddress(servicer));  
  
    // đơn_vị_dịch_vụ_s[mã_khoản_vay] = đơn_vị_dịch_vụ;  
    servicers[loanId] = servicer;  
    // dữ_liệu[mã_khoản_vay].cậpNhậtLúc = số_nguyên_không_dấu_48(block.dấu_thời_gian);  
    data[loanId].updatedAt = uint48(block.timestamp);  
  
    // phát_sự_kiện KhoảnVayĐơnVịDịchVụĐãCậpNhật(mã_khoản_vay, đơn_vị_dịch_vụ);  
    emit LoanServicerUpdated(loanId, servicer);  
  // }  
  }  
  
  /// @inheritdoc ILoans  
  // Kế_thừa từ ILoans  
  // hàm cậpNhậtDữLiệuKhoảnVay(  
  function updateLoanData(  
    // số_nguyên_không_dấu_64 mã_khoản_vay,  
    uint64 loanId,  
    // TrạngTháiKhoảnVay trạng_thái,  
    LoanStatus status,  
    // số_nguyên_không_dấu_48 ngàyĐếnHạnTiếpTheo,  
    uint48 nextDueDate,  
    // số_nguyên_không_dấu_48 ngàyĐáoHạn,  
    uint48 maturityDate,  
    // số_nguyên_không_dấu_48 dấu_thời_gian  
    uint48 timestamp  
  // ) bên_ngoài khiKhôngDừng chỉĐơnVịDịchVụHoặcQuảnTrị(mã_khoản_vay) khoảnVayTồnTại(mã_khoản_vay) vớiCậpNhậtKhoảnVay(mã_khoản_vay, dấu_thời_gian) {  
  ) external whenNotPaused onlyServicerOrAdmin(loanId) loanExists(loanId) withLoanUpdate(loanId, timestamp) {  
    // _cậpNhậtDữLiệuKhoảnVay(mã_khoản_vay, trạng_thái, ngàyĐếnHạnTiếpTheo, ngàyĐáoHạn);  
    _updateLoanData(loanId, status, nextDueDate, maturityDate);  
  // }  
  }  
  
  /**  
   * @dev Updates mutable loan-data fields. Pass `DoesNotExist` as `status` or 0 as a date  
   * @dev Cập_nhật các trường dữ_liệu khoản_vay có_thể_thay_đổi. Truyền `KhôngTồnTại` làm `trạng_thái` hoặc 0 làm ngày  
   *      to leave that field unchanged. Emits `LoanStatusUpdated`, `LoanNextDueDateUpdated`,  
   *      để giữ_nguyên trường đó. Phát_sự_kiện `KhoảnVayTrạngTháiĐãCậpNhật`, `KhoảnVayNgàyĐếnHạnTiếpTheoĐãCậpNhật`,  
   *      and `LoanMaturityDateUpdated` for each field that actually changed.  
   *      và `KhoảnVayNgàyĐáoHạnĐãCậpNhật` cho mỗi trường thực_sự thay_đổi.  
   */  
  // hàm _cậpNhậtDữLiệuKhoảnVay(số_nguyên_không_dấu_64 mã_khoản_vay, TrạngTháiKhoảnVay trạng_thái, số_nguyên_không_dấu_48 ngàyĐếnHạnTiếpTheo, số_nguyên_không_dấu_48 ngàyĐáoHạn) nội_bộ {  
  function _updateLoanData(uint64 loanId, LoanStatus status, uint48 nextDueDate, uint48 maturityDate) internal {  
    // DữLiệuKhoảnVay lưu_trữ dữLiệuKhoảnVay = dữ_liệu[mã_khoản_vay];  
    LoanData storage loanData = data[loanId];  
  
    // Only update if a valid status is provided (DoesNotExist is used as a sentinel value to indicate no change)  
    // Chỉ cập_nhật nếu trạng_thái hợp_lệ được cung_cấp (KhôngTồnTại được dùng làm giá_trị_canh_gác để chỉ_ra không_thay_đổi)  
    // nếu (trạng_thái != TrạngTháiKhoảnVay.KhôngTồnTại) {  
    if (status != LoanStatus.DoesNotExist) {  
      // TrạngTháiKhoảnVay trạngTháiCũ = dữLiệuKhoảnVay.trạng_thái;  
      LoanStatus oldStatus = loanData.status;  
      // dữLiệuKhoảnVay.trạng_thái = trạng_thái;  
      loanData.status = status;  
      // phát_sự_kiện KhoảnVayTrạngTháiĐãCậpNhật(mã_khoản_vay, trạngTháiCũ, trạng_thái);  
      emit LoanStatusUpdated(loanId, oldStatus, status);  
    // }  
    }  
  
    // nếu (ngàyĐếnHạnTiếpTheo > 0) {  
    if (nextDueDate > 0) {  
      // dữLiệuKhoảnVay.ngàyĐếnHạnTiếpTheo = ngàyĐếnHạnTiếpTheo;  
      loanData.nextDueDate = nextDueDate;  
      // phát_sự_kiện KhoảnVayNgàyĐếnHạnTiếpTheoĐãCậpNhật(mã_khoản_vay, ngàyĐếnHạnTiếpTheo);  
      emit LoanNextDueDateUpdated(loanId, nextDueDate);  
    // }  
    }  
  
    // nếu (ngàyĐáoHạn > 0) {  
    if (maturityDate > 0) {  
      // dữLiệuKhoảnVay.ngàyĐáoHạn = ngàyĐáoHạn;  
      loanData.maturityDate = maturityDate;  
      // phát_sự_kiện KhoảnVayNgàyĐáoHạnĐãCậpNhật(mã_khoản_vay, ngàyĐáoHạn);  
      emit LoanMaturityDateUpdated(loanId, maturityDate);  
    // }  
    }  
  // }  
  }  
  
  /**  
   * @inheritdoc ILoans  
   * Kế_thừa từ ILoans  
   * @dev Uses block.timestamp to update the loan's `updatedAt` field.  
   * @dev Sử_dụng block.dấu_thời_gian để cập_nhật trường `cậpNhậtLúc` của khoản_vay.  
   */  
  // hàm cậpNhậtĐiềuKhoảnKhoảnVay(  
  function updateLoanTerms(  
    // số_nguyên_không_dấu_64 mã_khoản_vay,  
    uint64 loanId,  
    // số_nguyên_không_dấu_48 ngàyKhởiTạo,  
    uint48 originationDate,  
    // số_nguyên_không_dấu_32 lãiSuất,  
    uint32 interestRate,  
    // số_nguyên_128 thanhToánHàngThángDựKiến  
    int128 expectedMonthlyPayment  
  // ) bên_ngoài khiKhôngDừng chỉĐơnVịDịchVụHoặcQuảnTrị(mã_khoản_vay) khoảnVayTồnTại(mã_khoản_vay) khôngKếtThúc(mã_khoản_vay) {  
  ) external whenNotPaused onlyServicerOrAdmin(loanId) loanExists(loanId) notTerminal(loanId) {  
    // ĐiềuKhoảnKhoảnVay lưu_trữ điềuKhoản = điềuKhoảnKhoảnVay[mã_khoản_vay];  
    LoanTerms storage terms = loanTerms[loanId];  
  
    // 0 is a sentinel meaning "no change" for each field.  
    // 0 là giá_trị_canh_gác có_nghĩa_là "không_thay_đổi" cho mỗi trường.  
    // nếu (ngàyKhởiTạo > 0) điềuKhoản.ngàyKhởiTạo = ngàyKhởiTạo;  
    if (originationDate > 0) terms.originationDate = originationDate;  
    // nếu (lãiSuất > 0) điềuKhoản.lãiSuất = lãiSuất;  
    if (interestRate > 0) terms.interestRate = interestRate;  
    // nếu (thanhToánHàngThángDựKiến > 0) điềuKhoản.thanhToánHàngThángDựKiến = thanhToánHàngThángDựKiến;  
    if (expectedMonthlyPayment > 0) terms.expectedMonthlyPayment = expectedMonthlyPayment;  
  
    // dữ_liệu[mã_khoản_vay].cậpNhậtLúc = số_nguyên_không_dấu_48(block.dấu_thời_gian);  
    data[loanId].updatedAt = uint48(block.timestamp);  
  
    // phát_sự_kiện ĐiềuKhoảnKhoảnVayĐãĐặt(mã_khoản_vay, điềuKhoản.ngàyKhởiTạo, điềuKhoản.lãiSuất, điềuKhoản.thanhToánHàngThángDựKiến);  
    emit LoanTermsSet(loanId, terms.originationDate, terms.interestRate, terms.expectedMonthlyPayment);  
  // }  
  }  
  
  /**  
   * @inheritdoc ILoans  
   * Kế_thừa từ ILoans  
   * @dev Caller must be the loan's registered borrower (`borrowers[loanId]`) or an admin.  
   * @dev Người_gọi phải là người_vay đã_đăng_ký của khoản_vay (`người_vay_s[mã_khoản_vay]`) hoặc quản_trị_viên.  
   *      Tokens are pulled from the registered borrower address regardless of caller.  
   *      Token được lấy từ địa_chỉ người_vay đã_đăng_ký bất_kể người_gọi là ai.  
   */  
  // hàm thanh_toán(  
  function pay(  
    // số_nguyên_không_dấu_64 mã_khoản_vay,  
    uint64 loanId,  
    // số_nguyên_128 số_tiền,  
    int128 amount,  
    // số_nguyên_không_dấu_48 dấu_thời_gian,  
    uint48 timestamp,  
    // bytes32 tham_chiếu  
    bytes32 ref  
  // )  
  )  
    // bên_ngoài  
    external  
    // khiKhôngDừng  
    whenNotPaused  
    // chỉNgườiVayHoặcQuảnTrị(mã_khoản_vay)  
    onlyBorrowerOrAdmin(loanId)  
    // chỉĐangHoạtĐộng(mã_khoản_vay)  
    onlyOutstanding(loanId)  
    // khôngTáiNhậpCảnh  
    nonReentrant  
    // vớiCậpNhậtKhoảnVay(mã_khoản_vay, dấu_thời_gian)  
    withLoanUpdate(loanId, timestamp)  
    // trả_về (số_nguyên_không_dấu_128 chỉSốMục)  
    returns (uint128 entryIndex)  
  // {  
  {  
    // dữ_liệu[mã_khoản_vay].ngàyThanhToánCuối = dấu_thời_gian;  
    data[loanId].lastPaymentDate = timestamp;  
    // phát_sự_kiện KhoảnVayNgàyThanhToánCuốiĐãCậpNhật(mã_khoản_vay, dấu_thời_gian);  
    emit LoanLastPaymentDateUpdated(loanId, timestamp);  
  
    // trả_về  
    return  
      // _nạpTiền(  
      _deposit(  
        // mã_khoản_vay,  
        loanId,  
        // TÀI_KHOẢN_THANH_TOÁN_NGƯỜI_VAY,  
        ACC_BORROWER_PAYMENT_CLEARING,  
        // số_tiền,  
        amount,  
        // người_vay_s[mã_khoản_vay],  
        borrowers[loanId],  
        // dấu_thời_gian,  
        timestamp,  
        // MỤC_THANH_TOÁN_NGƯỜI_VAY,  
        ENTRY_BORROWER_PAYMENT,  
        // tham_chiếu  
        ref  
      // );  
      );  
  // }  
  }


 /// @inheritdoc ILoans  
  // Kế_thừa từ ILoans  
  // hàm lấyGiáTrịKhoảnVay(số_nguyên_không_dấu_64[] dữ_liệu_gọi mãKhoảnVay_s) bên_ngoài xem trả_về (GiáTrịKhoảnVay[] bộ_nhớ kết_quả) {  
  function getLoanValues(uint64[] calldata loanIds) external view returns (LoanValue[] memory results) {  
    // số_nguyên_không_dấu_256 sốKhoảnVay = mãKhoảnVay_s.độ_dài;  
    uint256 numLoans = loanIds.length;  
    // kết_quả = new GiáTrịKhoảnVay[](sốKhoảnVay);  
    results = new LoanValue[](numLoans);  
  
    // for (số_nguyên_không_dấu_256 i = 0; i < sốKhoảnVay; ++i) {  
    for (uint256 i = 0; i < numLoans; ++i) {  
      // số_nguyên_không_dấu_64 mã_khoản_vay = mãKhoảnVay_s[i];  
      uint64 loanId = loanIds[i];  
      // nếu (mã_khoản_vay == 0 || mã_khoản_vay > số_lượng_khoản_vay) tiếp_tục;  
      if (loanId == 0 || loanId > loanCount) continue;  
  
      // DữLiệuKhoảnVay lưu_trữ dữLiệuKhoảnVay = dữ_liệu[mã_khoản_vay];  
      LoanData storage loanData = data[loanId];  
      // kết_quả[i] = GiáTrịKhoảnVay({  
      results[i] = LoanValue({  
        // vốnGốcNhàĐầuTưCònLại: -_lấySốDưTàiKhoản(mã_khoản_vay, TÀI_KHOẢN_PHẢI_TRẢ_VỐN_GỐC_NHÀ_ĐẦU_TƯ) -  
        outstandingInvestorPrincipal: -_getAccountBalance(loanId, ACC_INVESTOR_PRINCIPAL_PAYABLE) -  
          // _lấySốDưTàiKhoản(mã_khoản_vay, TÀI_KHOẢN_VỐN_GỐC_NHÀ_ĐẦU_TƯ_ĐÃ_HOÀN_TRẢ),  
          _getAccountBalance(loanId, ACC_INVESTOR_PRINCIPAL_REPAID),  
        // vốnGốcNhàĐầuTưCóThểRút: _lấyVốnGốcRòngPhảiTrảChoNhàĐầuTư(mã_khoản_vay),  
        investorPrincipalWithdrawable: _getNetPrincipalPayableToInvestor(loanId),  
        // lãiNhàĐầuTưCóThểRút: _lấyLãiRòngPhảiTrảChoNhàĐầuTư(mã_khoản_vay),  
        investorInterestWithdrawable: _getNetInterestPayableToInvestor(loanId),  
        // trạng_thái: dữLiệuKhoảnVay.trạng_thái,  
        status: loanData.status,  
        // ngàyĐếnHạnTiếpTheo: dữLiệuKhoảnVay.ngàyĐếnHạnTiếpTheo  
        nextDueDate: loanData.nextDueDate  
      // });  
      });  
    // }  
    }  
  // }  
  }  
  
  /**  
   * @dev Creates a single entry from Unallocated Borrower Interest Payable to  
   * @dev Tạo một mục đơn từ Lãi Người Vay Chưa Phân Bổ Phải Trả đến  
   *      Borrower Interest Receivable. The split into servicer fees vs investor  
   *      Lãi Người Vay Phải Thu. Việc phân_chia thành phí đơn_vị_dịch_vụ so với lãi nhà_đầu_tư  
   *      interest happens later during `applyWaterfall`.  
   *      xảy_ra sau trong `áp_dụngThácNước`.  
   */  
  // hàm _tíchLũy(số_nguyên_không_dấu_64 mã_khoản_vay, số_nguyên_128 số_tiền, số_nguyên_không_dấu_48 dấu_thời_gian, bytes32 tham_chiếu) nội_bộ {  
  function _accrue(uint64 loanId, int128 amount, uint48 timestamp, bytes32 ref) internal {  
    // nếu (số_tiền != 0) {  
    if (amount != 0) {  
      // _tạoMụcNộiBộ(  
      _createInternalEntry(  
        // mã_khoản_vay,  
        loanId,  
        // TÀI_KHOẢN_LÃI_NGƯỜI_VAY_CHƯA_PHÂN_BỔ_PHẢI_TRẢ,  
        ACC_UNALLOCATED_BORROWER_INTEREST_PAYABLE,  
        // TÀI_KHOẢN_LÃI_NGƯỜI_VAY_PHẢI_THU,  
        ACC_BORROWER_INTEREST_RECEIVABLE,  
        // số_tiền,  
        amount,  
        // dấu_thời_gian,  
        timestamp,  
        // MỤC_TÍCH_LŨY_LÃI,  
        ENTRY_INTEREST_ACCRUAL,  
        // tham_chiếu  
        ref  
      // );  
      );  
    // }  
    }  
  // }  
  }  
  
  /// @inheritdoc ILoans  
  // Kế_thừa từ ILoans  
  // hàm tíchLũy(  
  function accrue(  
    // số_nguyên_không_dấu_64 mã_khoản_vay,  
    uint64 loanId,  
    // số_nguyên_128 số_tiền,  
    int128 amount,  
    // số_nguyên_không_dấu_48 dấu_thời_gian,  
    uint48 timestamp,  
    // bytes32 tham_chiếu  
    bytes32 ref  
  // ) bên_ngoài khiKhôngDừng chỉĐơnVịDịchVụHoặcQuảnTrị(mã_khoản_vay) chỉĐangHoạtĐộng(mã_khoản_vay) vớiCậpNhậtKhoảnVay(mã_khoản_vay, dấu_thời_gian) {  
  ) external whenNotPaused onlyServicerOrAdmin(loanId) onlyOutstanding(loanId) withLoanUpdate(loanId, timestamp) {  
    // _tíchLũy(mã_khoản_vay, số_tiền, dấu_thời_gian, tham_chiếu);  
    _accrue(loanId, amount, timestamp, ref);  
  // }  
  }  
  
  /// @inheritdoc ILoans  
  // Kế_thừa từ ILoans  
  // hàm tínhPhíKhác(  
  function chargeMiscFee(  
    // số_nguyên_không_dấu_64 mã_khoản_vay,  
    uint64 loanId,  
    // số_nguyên_128 số_tiền,  
    int128 amount,  
    // số_nguyên_không_dấu_48 dấu_thời_gian,  
    uint48 timestamp,  
    // bytes32 tham_chiếu  
    bytes32 ref  
  // ) bên_ngoài khiKhôngDừng chỉĐơnVịDịchVụHoặcQuảnTrị(mã_khoản_vay) chỉĐangHoạtĐộng(mã_khoản_vay) vớiCậpNhậtKhoảnVay(mã_khoản_vay, dấu_thời_gian) {  
  ) external whenNotPaused onlyServicerOrAdmin(loanId) onlyOutstanding(loanId) withLoanUpdate(loanId, timestamp) {  
    // yêu_cầu(số_tiền > 0, SốTiềnKhôngHợpLệ());  
    require(amount > 0, InvalidAmount());  
  
    // _tạoMụcNộiBộ(  
    _createInternalEntry(  
      // mã_khoản_vay,  
      loanId,  
      // TÀI_KHOẢN_PHÍ_KHÁC_ĐƠN_VỊ_DỊCH_VỤ_PHẢI_TRẢ,  
      ACC_SERVICER_MISC_FEE_PAYABLE,  
      // TÀI_KHOẢN_PHÍ_KHÁC_NGƯỜI_VAY_PHẢI_THU,  
      ACC_BORROWER_MISC_FEE_RECEIVABLE,  
      // số_tiền,  
      amount,  
      // dấu_thời_gian,  
      timestamp,  
      // MỤC_TÍNH_PHÍ_KHÁC,  
      ENTRY_MISC_FEE_CHARGE,  
      // tham_chiếu  
      ref  
    // );  
    );  
  // }  
  }  
  
  /**  
   * @inheritdoc ILoans  
   * Kế_thừa từ ILoans  
   * @dev Tokens are transferred from the loan's investor address (the current NFT holder).  
   * @dev Token được chuyển từ địa_chỉ nhà_đầu_tư của khoản_vay (người_nắm_giữ NFT hiện_tại).  
   */  
  // hàm giảiNgân(  
  function fund(  
    // số_nguyên_không_dấu_64 mã_khoản_vay,  
    uint64 loanId,  
    // số_nguyên_128 số_tiền,  
    int128 amount,  
    // số_nguyên_không_dấu_48 dấu_thời_gian,  
    uint48 timestamp,  
    // bytes32 tham_chiếu  
    bytes32 ref  
  // ) bên_ngoài khiKhôngDừng khôngTáiNhậpCảnh vớiCậpNhậtKhoảnVay(mã_khoản_vay, dấu_thời_gian) trả_về (số_nguyên_không_dấu_128 chỉSốMục) {  
  ) external whenNotPaused nonReentrant withLoanUpdate(loanId, timestamp) returns (uint128 entryIndex) {  
    // địa_chỉ địaChỉNhàĐầuTư = NFT_khoản_vay.chủSởHữuCủa(mã_khoản_vay);  
    address investorAddress = loansNFT.ownerOf(loanId);  
  
    // _yêuCầuNgườiGọiHoặcQuảnTrị(địaChỉNhàĐầuTư);  
    _requireCallerOrAdmin(investorAddress);  
    // yêu_cầu(số_tiền > 0, SốTiềnKhôngHợpLệ());  
    require(amount > 0, InvalidAmount());  
    // yêu_cầu(dữ_liệu[mã_khoản_vay].trạng_thái == TrạngTháiKhoảnVay.ĐãTạo, TrạngTháiKhôngHợpLệ());  
    require(data[loanId].status == LoanStatus.Created, InvalidStatus());  
  
    // Funding must be a single full-commitment deposit.  
    // Giải_ngân phải là một khoản nạp đầy_đủ cam_kết duy_nhất.  
    // BorrowerPrincipalReceivable = commitment (positive)  
    // VốnGốcNgườiVayPhảiThu = cam_kết (dương)  
    // InvestorPrincipalPayable = funded amount (negative, as liability)  
    // VốnGốcNhàĐầuTưPhảiTrả = số_tiền đã_giải_ngân (âm, là nợ_phải_trả)  
    // số_nguyên_128 camKết = _lấySốDưTàiKhoản(mã_khoản_vay, TÀI_KHOẢN_PHẢI_THU_VỐN_GỐC_NGƯỜI_VAY);  
    int128 commitment = _getAccountBalance(loanId, ACC_BORROWER_PRINCIPAL_RECEIVABLE);  
    // số_nguyên_128 đãGiảiNgân = -_lấySốDưTàiKhoản(mã_khoản_vay, TÀI_KHOẢN_PHẢI_TRẢ_VỐN_GỐC_NHÀ_ĐẦU_TƯ);  
    int128 alreadyFunded = -_getAccountBalance(loanId, ACC_INVESTOR_PRINCIPAL_PAYABLE);  
  
    // yêu_cầu(đãGiảiNgân == 0, SốTiềnKhôngHợpLệ());  
    require(alreadyFunded == 0, InvalidAmount());  
    // yêu_cầu(số_tiền == camKết, SốTiềnKhôngHợpLệ());  
    require(amount == commitment, InvalidAmount());  
  
    // _cậpNhậtDữLiệuKhoảnVay(mã_khoản_vay, TrạngTháiKhoảnVay.ĐãGiảiNgânĐầyĐủ, 0, 0);  
    _updateLoanData(loanId, LoanStatus.FullyFunded, 0, 0);  
  
    // trả_về  
    return  
      // _nạpTiền(  
      _deposit(  
        // mã_khoản_vay,  
        loanId,  
        // TÀI_KHOẢN_PHẢI_TRẢ_VỐN_GỐC_NHÀ_ĐẦU_TƯ,  
        ACC_INVESTOR_PRINCIPAL_PAYABLE,  
        // số_tiền,  
        amount,  
        // địaChỉNhàĐầuTư,  
        investorAddress,  
        // dấu_thời_gian,  
        timestamp,  
        // MỤC_VỐN_NHÀ_ĐẦU_TƯ_ĐÃ_NHẬN,  
        ENTRY_INVESTOR_CAPITAL_RECEIVED,  
        // tham_chiếu  
        ref  
      // );  
      );  
  // }  
  }




 // hàm _giảiNgân(  
  function _disburse(  
    // số_nguyên_không_dấu_64 mã_khoản_vay,  
    uint64 loanId,  
    // số_nguyên_128 sốTiềnGiảiNgânRòng,  
    int128 netDisbursedAmount,  
    // số_nguyên_128 phíKhởiTạo,  
    int128 originationFee,  
    // số_nguyên_không_dấu_48 dấu_thời_gian,  
    uint48 timestamp,  
    // bytes32 tham_chiếu  
    bytes32 ref  
  // ) nội_bộ trả_về (số_nguyên_không_dấu_128 chỉSốMục) {  
  ) internal returns (uint128 entryIndex) {  
    // Entry 1: Withhold origination fee (OriginatorFeePayable -> UnfundedCommitment)  
    // Mục 1: Giữ_lại phí khởi_tạo (PhíKhởiTạoPhảiTrả -> CamKếtChưaGiảiNgân)  
    // Creates originator fee liability, settles part of commitment  
    // Tạo nợ_phải_trả phí khởi_tạo, thanh_toán một phần cam_kết  
    // nếu (phíKhởiTạo > 0) {  
    if (originationFee > 0) {  
      // _tạoMụcNộiBộ(  
      _createInternalEntry(  
        // mã_khoản_vay,  
        loanId,  
        // TÀI_KHOẢN_PHÍ_KHỞI_TẠO_PHẢI_TRẢ,  
        ACC_ORIGINATOR_FEE_PAYABLE,  
        // TÀI_KHOẢN_CAM_KẾT_CHƯA_GIẢI_NGÂN,  
        ACC_UNFUNDED_COMMITMENT,  
        // phíKhởiTạo,  
        originationFee,  
        // dấu_thời_gian,  
        timestamp,  
        // MỤC_GIỮ_LẠI_PHÍ_KHỞI_TẠO,  
        ENTRY_ORIGINATOR_FEE_WITHHOLDING,  
        // tham_chiếu  
        ref  
      // );  
      );  
    // }  
    }  
  
    // Entry 2: Disburse to borrower (Cash -> UnfundedCommitment)  
    // Mục 2: Giải_ngân cho người_vay (Tiền_mặt -> CamKếtChưaGiảiNgân)  
    // Settles remaining commitment liability, decreases Cash  
    // Thanh_toán nợ_phải_trả cam_kết còn_lại, giảm Tiền_mặt  
    // chỉSốMục = _tạoMụcNộiBộ(  
    entryIndex = _createInternalEntry(  
      // mã_khoản_vay,  
      loanId,  
      // TÀI_KHOẢN_TIỀN_MẶT,  
      ACC_CASH,  
      // TÀI_KHOẢN_CAM_KẾT_CHƯA_GIẢI_NGÂN,  
      ACC_UNFUNDED_COMMITMENT,  
      // sốTiềnGiảiNgânRòng,  
      netDisbursedAmount,  
      // dấu_thời_gian,  
      timestamp,  
      // MỤC_GIẢI_NGÂN_CHO_NGƯỜI_VAY,  
      ENTRY_DISBURSEMENT_TO_BORROWER,  
      // tham_chiếu  
      ref  
    // );  
    );  
  
    // Transfer netDisbursedAmount to borrower  
    // Chuyển sốTiềnGiảiNgânRòng cho người_vay  
    // tiền_tệ.chuyểnAnToàn(người_vay_s[mã_khoản_vay], số_nguyên_không_dấu_256(số_nguyên_256(sốTiềnGiảiNgânRòng)));  
    currency.safeTransfer(borrowers[loanId], uint256(int256(netDisbursedAmount)));  
  // }  
  }  
  
  /**  
   * @inheritdoc ILoans  
   * Kế_thừa từ ILoans  
   * @dev Settles the unfunded commitment liability. Must disburse the full commitment  
   * @dev Thanh_toán nợ_phải_trả cam_kết chưa_giải_ngân. Phải giải_ngân toàn_bộ số_tiền cam_kết  
   *      amount (`netDisbursedAmount + originationFee`). Origination fee is withheld  
   *      (`sốTiềnGiảiNgânRòng + phíKhởiTạo`). Phí khởi_tạo được giữ_lại  
   *      from the commitment before the borrower transfer.  
   *      từ cam_kết trước khi chuyển cho người_vay.  
   */  
  // hàm giảiNgân(  
  function disburse(  
    // số_nguyên_không_dấu_64 mã_khoản_vay,  
    uint64 loanId,  
    // số_nguyên_128 sốTiềnGiảiNgânRòng,  
    int128 netDisbursedAmount,  
    // số_nguyên_128 phíKhởiTạo,  
    int128 originationFee,  
    // số_nguyên_không_dấu_48 ngàyKhởiTạo,  
    uint48 originationDate,  
    // số_nguyên_không_dấu_48 ngàyĐếnHạnTiếpTheo,  
    uint48 nextDueDate,  
    // số_nguyên_không_dấu_48 ngàyĐáoHạn,  
    uint48 maturityDate,  
    // số_nguyên_không_dấu_32 lãiSuất,  
    uint32 interestRate,  
    // số_nguyên_128 thanhToánHàngThángDựKiến,  
    int128 expectedMonthlyPayment,  
    // số_nguyên_không_dấu_48 dấu_thời_gian,  
    uint48 timestamp,  
    // bytes32 tham_chiếu  
    bytes32 ref  
  // )  
  )  
    // bên_ngoài  
    external  
    // khiKhôngDừng  
    whenNotPaused  
    // khôngTáiNhậpCảnh  
    nonReentrant  
    // khoảnVayTồnTại(mã_khoản_vay)  
    loanExists(loanId)  
    // vớiCậpNhậtKhoảnVay(mã_khoản_vay, dấu_thời_gian)  
    withLoanUpdate(loanId, timestamp)  
    // trả_về (số_nguyên_không_dấu_128 chỉSốMục)  
    returns (uint128 entryIndex)  
  // {  
  {  
    // _yêuCầuNgườiGọiHoặcQuảnTrị(đơn_vị_khởi_tạo_s[mã_khoản_vay]);  
    _requireCallerOrAdmin(originators[loanId]);  
    // yêu_cầu(sốTiềnGiảiNgânRòng > 0, SốTiềnKhôngHợpLệ());  
    require(netDisbursedAmount > 0, InvalidAmount());  
    // yêu_cầu(phíKhởiTạo >= 0, SốTiềnKhôngHợpLệ());  
    require(originationFee >= 0, InvalidAmount());  
  
    // DữLiệuKhoảnVay lưu_trữ dữLiệuKhoảnVay = dữ_liệu[mã_khoản_vay];  
    LoanData storage loanData = data[loanId];  
    // yêu_cầu(dữLiệuKhoảnVay.trạng_thái == TrạngTháiKhoảnVay.ĐãGiảiNgânĐầyĐủ, TrạngTháiKhôngHợpLệ());  
    require(loanData.status == LoanStatus.FullyFunded, InvalidStatus());  
  
    // full amount committed = netDisbursedAmount + originationFee  
    // tổng_số_tiền cam_kết = sốTiềnGiảiNgânRòng + phíKhởiTạo  
    // số_nguyên_128 camKết = -_lấySốDưTàiKhoản(mã_khoản_vay, TÀI_KHOẢN_CAM_KẾT_CHƯA_GIẢI_NGÂN);  
    int128 commitment = -_getAccountBalance(loanId, ACC_UNFUNDED_COMMITMENT);  
    // yêu_cầu(sốTiềnGiảiNgânRòng + phíKhởiTạo == camKết, SốTiềnGiảiNgânKhôngHợpLệ());  
    require(netDisbursedAmount + originationFee == commitment, InvalidAmountDisbursed());  
  
    // Verify investor funding actually reached the commitment.  
    // Xác_minh việc giải_ngân của nhà_đầu_tư thực_sự đạt đến cam_kết.  
    // Status alone is not authoritative because updateLoanData can set it directly.  
    // Trạng_thái đơn_thuần không có thẩm_quyền vì cậpNhậtDữLiệuKhoảnVay có_thể đặt trực_tiếp.  
    // số_nguyên_128 đãGiảiNgân = -_lấySốDưTàiKhoản(mã_khoản_vay, TÀI_KHOẢN_PHẢI_TRẢ_VỐN_GỐC_NHÀ_ĐẦU_TƯ);  
    int128 funded = -_getAccountBalance(loanId, ACC_INVESTOR_PRINCIPAL_PAYABLE);  
    // yêu_cầu(đãGiảiNgân == camKết, ChưaGiảiNgânĐầyĐủ());  
    require(funded == commitment, NotFullyFunded());  
  
    // _cậpNhậtDữLiệuKhoảnVay(mã_khoản_vay, TrạngTháiKhoảnVay.ĐangHoạtĐộng, ngàyĐếnHạnTiếpTheo, ngàyĐáoHạn);  
    _updateLoanData(loanId, LoanStatus.Active, nextDueDate, maturityDate);  
  
    // điềuKhoảnKhoảnVay[mã_khoản_vay] = ĐiềuKhoảnKhoảnVay({  
    loanTerms[loanId] = LoanTerms({  
      // ngàyKhởiTạo: ngàyKhởiTạo,  
      originationDate: originationDate,  
      // lãiSuất: lãiSuất,  
      interestRate: interestRate,  
      // thanhToánHàngThángDựKiến: thanhToánHàngThángDựKiến  
      expectedMonthlyPayment: expectedMonthlyPayment  
    // });  
    });  
    // phát_sự_kiện ĐiềuKhoảnKhoảnVayĐãĐặt(mã_khoản_vay, ngàyKhởiTạo, lãiSuất, thanhToánHàngThángDựKiến);  
    emit LoanTermsSet(loanId, originationDate, interestRate, expectedMonthlyPayment);  
  
    // trả_về _giảiNgân(mã_khoản_vay, sốTiềnGiảiNgânRòng, phíKhởiTạo, dấu_thời_gian, tham_chiếu);  
    return _disburse(loanId, netDisbursedAmount, originationFee, timestamp, ref);  
  // }  
  }  
  
  /**  
   * @dev Records partial repayment of a borrower receivable. Credits `paidAcc`  
   * @dev Ghi_lại việc hoàn_trả một phần khoản_phải_thu của người_vay. Ghi_có `tàiKhoảnĐãThanhToán`  
   *      and debits the payment clearing account. `amount` must not exceed the  
   *      và ghi_nợ tài_khoản thanh_toán bù_trừ. `số_tiền` không được vượt_quá  
   *      net outstanding receivable (receivable + any already-applied payment).  
   *      khoản_phải_thu ròng còn_lại (khoản_phải_thu + bất_kỳ khoản_thanh_toán đã_áp_dụng nào).  
   */  
  // hàm _xóaNợPhảiThu(  
  function _clearReceivableDebt(  
    // số_nguyên_không_dấu_64 mã_khoản_vay,  
    uint64 loanId,  
    // số_nguyên_không_dấu_8 tàiKhoảnĐãThanhToán,  
    uint8 paidAcc,  
    // số_nguyên_không_dấu_8 tàiKhoảnPhảiThu,  
    uint8 receivableAcc,  
    // số_nguyên_128 số_tiền,  
    int128 amount,  
    // số_nguyên_không_dấu_48 dấu_thời_gian,  
    uint48 timestamp,  
    // số_nguyên_không_dấu_16 loạiMục,  
    uint16 entryType,  
    // bytes32 tham_chiếu  
    bytes32 ref  
  // ) riêng_tư {  
  ) private {  
    // nếu (số_tiền == 0) trả_về;  
    if (amount == 0) return;  
    // số_nguyên_128 đãThanhToán = _lấySốDưTàiKhoản(mã_khoản_vay, tàiKhoảnĐãThanhToán);  
    int128 paid = _getAccountBalance(loanId, paidAcc);  
    // số_nguyên_128 còn_lại = _lấySốDưTàiKhoản(mã_khoản_vay, tàiKhoảnPhảiThu) + (đãThanhToán < 0 ? đãThanhToán : số_nguyên_128(0));  
    int128 outstanding = _getAccountBalance(loanId, receivableAcc) + (paid < 0 ? paid : int128(0));  
    // yêu_cầu(số_tiền <= còn_lại, SốTiềnKhôngHợpLệ());  
    require(amount <= outstanding, InvalidAmount());  
    // _tạoMụcNộiBộ(mã_khoản_vay, tàiKhoảnĐãThanhToán, TÀI_KHOẢN_THANH_TOÁN_NGƯỜI_VAY, số_tiền, dấu_thời_gian, loạiMục, tham_chiếu);  
    _createInternalEntry(loanId, paidAcc, ACC_BORROWER_PAYMENT_CLEARING, amount, timestamp, entryType, ref);  
  // }  
  }




    /**  
   * @dev Splits a borrower interest payment into servicer-fee and investor-interest  
   * @dev Chia một khoản thanh_toán lãi của người_vay thành phân_bổ phí đơn_vị_dịch_vụ và lãi nhà_đầu_tư  
   *      allocations (moving each from the unallocated pool to the corresponding  
   *      (chuyển mỗi khoản từ nhóm chưa_phân_bổ sang khoản_phải_trả tương_ứng)  
   *      payable) and clears the matching interest receivable. Reverts if the  
   *      và xóa khoản_phải_thu lãi tương_ứng. Hoàn_tác nếu  
   *      total exceeds the net outstanding interest receivable.  
   *      tổng vượt_quá khoản_phải_thu lãi ròng còn_lại.  
   */  
  // hàm _xửLýPhầnLãi(  
  function _processInterestPortion(  
    // số_nguyên_không_dấu_64 mã_khoản_vay,  
    uint64 loanId,  
    // số_nguyên_128 phíDịchVụ,  
    int128 servicingFees,  
    // số_nguyên_128 lãiNhàĐầuTư,  
    int128 investorInterest,  
    // số_nguyên_không_dấu_48 dấu_thời_gian,  
    uint48 timestamp,  
    // bytes32 tham_chiếu  
    bytes32 ref  
  // ) riêng_tư {  
  ) private {  
    // số_nguyên_128 tổngLãiVàPhí = phíDịchVụ + lãiNhàĐầuTư;  
    int128 totalInterestAndFees = servicingFees + investorInterest;  
    // nếu (tổngLãiVàPhí == 0) trả_về;  
    if (totalInterestAndFees == 0) return;  
  
    // số_nguyên_128 lãiĐãThanhToán = _lấySốDưTàiKhoản(mã_khoản_vay, TÀI_KHOẢN_LÃI_NGƯỜI_VAY_ĐÃ_THANH_TOÁN);  
    int128 interestPaid = _getAccountBalance(loanId, ACC_BORROWER_INTEREST_PAID);  
    // số_nguyên_128 còn_lại = _lấySốDưTàiKhoản(mã_khoản_vay, TÀI_KHOẢN_LÃI_NGƯỜI_VAY_PHẢI_THU) +  
    int128 outstanding = _getAccountBalance(loanId, ACC_BORROWER_INTEREST_RECEIVABLE) +  
      // (lãiĐãThanhToán < 0 ? lãiĐãThanhToán : số_nguyên_128(0));  
      (interestPaid < 0 ? interestPaid : int128(0));  
    // yêu_cầu(tổngLãiVàPhí <= còn_lại, SốTiềnKhôngHợpLệ());  
    require(totalInterestAndFees <= outstanding, InvalidAmount());  
  
    // nếu (phíDịchVụ > 0) {  
    if (servicingFees > 0) {  
      // _tạoMụcNộiBộ(  
      _createInternalEntry(  
        // mã_khoản_vay,  
        loanId,  
        // TÀI_KHOẢN_PHÍ_DỊCH_VỤ_PHẢI_TRẢ,  
        ACC_SERVICER_FEE_PAYABLE,  
        // TÀI_KHOẢN_LÃI_NGƯỜI_VAY_CHƯA_PHÂN_BỔ_PHẢI_TRẢ,  
        ACC_UNALLOCATED_BORROWER_INTEREST_PAYABLE,  
        // phíDịchVụ,  
        servicingFees,  
        // dấu_thời_gian,  
        timestamp,  
        // MỤC_PHÂN_BỔ_PHÍ_DỊCH_VỤ,  
        ENTRY_SERVICER_FEE_ALLOCATION,  
        // tham_chiếu  
        ref  
      // );  
      );  
    // }  
    }  
    // nếu (lãiNhàĐầuTư > 0) {  
    if (investorInterest > 0) {  
      // _tạoMụcNộiBộ(  
      _createInternalEntry(  
        // mã_khoản_vay,  
        loanId,  
        // TÀI_KHOẢN_LÃI_NHÀ_ĐẦU_TƯ_PHẢI_TRẢ,  
        ACC_INVESTOR_INTEREST_PAYABLE,  
        // TÀI_KHOẢN_LÃI_NGƯỜI_VAY_CHƯA_PHÂN_BỔ_PHẢI_TRẢ,  
        ACC_UNALLOCATED_BORROWER_INTEREST_PAYABLE,  
        // lãiNhàĐầuTư,  
        investorInterest,  
        // dấu_thời_gian,  
        timestamp,  
        // MỤC_PHÂN_BỔ_LÃI_NHÀ_ĐẦU_TƯ,  
        ENTRY_INVESTOR_INTEREST_ALLOCATION,  
        // tham_chiếu  
        ref  
      // );  
      );  
    // }  
    }  
    // _tạoMụcNộiBộ(  
    _createInternalEntry(  
      // mã_khoản_vay,  
      loanId,  
      // TÀI_KHOẢN_LÃI_NGƯỜI_VAY_ĐÃ_THANH_TOÁN,  
      ACC_BORROWER_INTEREST_PAID,  
      // TÀI_KHOẢN_THANH_TOÁN_NGƯỜI_VAY,  
      ACC_BORROWER_PAYMENT_CLEARING,  
      // tổngLãiVàPhí,  
      totalInterestAndFees,  
      // dấu_thời_gian,  
      timestamp,  
      // MỤC_XÓA_NỢ_LÃI_NGƯỜI_VAY,  
      ENTRY_BORROWER_INTEREST_DEBT_CLEARANCE,  
      // tham_chiếu  
      ref  
    // );  
    );  
  // }  
  }  
  
  /// @inheritdoc ILoans  
  // Kế_thừa từ ILoans  
  // hàm áp_dụngThácNước(  
  function applyWaterfall(  
    // số_nguyên_không_dấu_64 mã_khoản_vay,  
    uint64 loanId,  
    // số_nguyên_128 phíKhác,  
    int128 miscFees,  
    // số_nguyên_128 phíDịchVụ,  
    int128 servicingFees,  
    // số_nguyên_128 lãiNhàĐầuTư,  
    int128 investorInterest,  
    // số_nguyên_128 vốnGốc,  
    int128 principal,  
    // số_nguyên_không_dấu_48 ngàyĐếnHạnTiếpTheo,  
    uint48 nextDueDate,  
    // số_nguyên_không_dấu_48 dấu_thời_gian,  
    uint48 timestamp,  
    // bytes32 tham_chiếu  
    bytes32 ref  
  // )  
  )  
    // bên_ngoài  
    external  
    // khiKhôngDừng  
    whenNotPaused  
    // chỉĐơnVịDịchVụHoặcQuảnTrị(mã_khoản_vay)  
    onlyServicerOrAdmin(loanId)  
    // chỉĐangHoạtĐộngHoặcĐãThanhToánĐầyĐủ(mã_khoản_vay)  
    onlyOutstandingOrFullyPaid(loanId)  
    // vớiCậpNhậtKhoảnVay(mã_khoản_vay, dấu_thời_gian)  
    withLoanUpdate(loanId, timestamp)  
  // {  
  {  
    // yêu_cầu(phíKhác >= 0 && phíDịchVụ >= 0 && lãiNhàĐầuTư >= 0 && vốnGốc >= 0, SốTiềnKhôngHợpLệ());  
    require(miscFees >= 0 && servicingFees >= 0 && investorInterest >= 0 && principal >= 0, InvalidAmount());  
  
    // nếu (ngàyĐếnHạnTiếpTheo > 0) {  
    if (nextDueDate > 0) {  
      // dữ_liệu[mã_khoản_vay].ngàyĐếnHạnTiếpTheo = ngàyĐếnHạnTiếpTheo;  
      data[loanId].nextDueDate = nextDueDate;  
      // phát_sự_kiện KhoảnVayNgàyĐếnHạnTiếpTheoĐãCậpNhật(mã_khoản_vay, ngàyĐếnHạnTiếpTheo);  
      emit LoanNextDueDateUpdated(loanId, nextDueDate);  
    // }  
    }  
  
    // yêu_cầu(  
    require(  
      // phíKhác + phíDịchVụ + lãiNhàĐầuTư + vốnGốc <=  
      miscFees + servicingFees + investorInterest + principal <=  
        // -_lấySốDưTàiKhoản(mã_khoản_vay, TÀI_KHOẢN_THANH_TOÁN_NGƯỜI_VAY),  
        -_getAccountBalance(loanId, ACC_BORROWER_PAYMENT_CLEARING),  
      // SốTiềnKhôngHợpLệ()  
      InvalidAmount()  
    // );  
    );  
  
    // _xóaNợPhảiThu(  
    _clearReceivableDebt(  
      // mã_khoản_vay,  
      loanId,  
      // TÀI_KHOẢN_PHÍ_KHÁC_NGƯỜI_VAY_ĐÃ_THANH_TOÁN,  
      ACC_BORROWER_MISC_FEE_PAID,  
      // TÀI_KHOẢN_PHÍ_KHÁC_NGƯỜI_VAY_PHẢI_THU,  
      ACC_BORROWER_MISC_FEE_RECEIVABLE,  
      // phíKhác,  
      miscFees,  
      // dấu_thời_gian,  
      timestamp,  
      // MỤC_XÓA_NỢ_PHÍ_KHÁC,  
      ENTRY_MISC_FEE_DEBT_CLEARANCE,  
      // tham_chiếu  
      ref  
    // );  
    );  
  
    // _xửLýPhầnLãi(mã_khoản_vay, phíDịchVụ, lãiNhàĐầuTư, dấu_thời_gian, tham_chiếu);  
    _processInterestPortion(loanId, servicingFees, investorInterest, timestamp, ref);  
  
    // _xóaNợPhảiThu(  
    _clearReceivableDebt(  
      // mã_khoản_vay,  
      loanId,  
      // TÀI_KHOẢN_VỐN_GỐC_NGƯỜI_VAY_ĐÃ_HOÀN_TRẢ,  
      ACC_BORROWER_PRINCIPAL_REPAID,  
      // TÀI_KHOẢN_PHẢI_THU_VỐN_GỐC_NGƯỜI_VAY,  
      ACC_BORROWER_PRINCIPAL_RECEIVABLE,  
      // vốnGốc,  
      principal,  
      // dấu_thời_gian,  
      timestamp,  
      // MỤC_THANH_TOÁN_VỐN_GỐC_NGƯỜI_VAY,  
      ENTRY_BORROWER_PRINCIPAL_PAYMENT,  
      // tham_chiếu  
      ref  
    // );  
    );  
  // }  
  }  
  
  /**  
   * @inheritdoc ILoans  
   * Kế_thừa từ ILoans  
   * @dev All loans must share the same servicer address (caller or admin acting on  
   * @dev Tất_cả khoản_vay phải chia_sẻ cùng địa_chỉ đơn_vị_dịch_vụ (người_gọi hoặc quản_trị_viên hành_động thay_mặt  
   *      their behalf). Per-loan ledger entries are written individually but the  
   *      họ). Các mục sổ_cái theo từng khoản_vay được ghi riêng_lẻ nhưng  
   *      payouts are consolidated into a single ERC20 transfer. Automatically  
   *      các khoản_chi_trả được hợp_nhất thành một lần chuyển ERC20 duy_nhất. Tự_động  
   *      withdraws all available servicing fees and misc fees per loan.  
   *      rút tất_cả phí dịch_vụ và phí khác có_sẵn theo từng khoản_vay.  
   */  
  // hàm rútTiềnĐơnVịDịchVụ(  
  function servicerWithdraw(  
    // số_nguyên_không_dấu_64[] dữ_liệu_gọi mãKhoảnVay_s,  
    uint64[] calldata loanIds,  
    // số_nguyên_không_dấu_48 dấu_thời_gian,  
    uint48 timestamp,  
    // bytes32 tham_chiếu  
    bytes32 ref  
  // ) bên_ngoài khiKhôngDừng khôngTáiNhậpCảnh trả_về (KếtQuảRútTiềnĐơnVịDịchVụ[] bộ_nhớ kết_quả) {  
  ) external whenNotPaused nonReentrant returns (ServicerWithdrawalResult[] memory results) {  
    // số_nguyên_không_dấu_256 sốKhoảnVay = mãKhoảnVay_s.độ_dài;  
    uint256 numLoans = loanIds.length;  
    // kết_quả = new KếtQuảRútTiềnĐơnVịDịchVụ[](sốKhoảnVay);  
    results = new ServicerWithdrawalResult[](numLoans);  
  
    // số_nguyên_128 tổngChuyển = 0;  
    int128 totalTransfer = 0;  
    // địa_chỉ địaChỉĐơnVịDịchVụ;  
    address servicerAddress;  
    // số_nguyên_không_dấu_64 sốLượngKhoảnVayHiệnTại = số_lượng_khoản_vay;  
    uint64 currentLoanCount = loanCount;  
  
    // for (số_nguyên_không_dấu_256 i = 0; i < sốKhoảnVay; ++i) {  
    for (uint256 i = 0; i < numLoans; ++i) {  
      // số_nguyên_không_dấu_64 mã_khoản_vay = mãKhoảnVay_s[i];  
      uint64 loanId = loanIds[i];  
  
      // yêu_cầu(mã_khoản_vay != 0 && mã_khoản_vay <= sốLượngKhoảnVayHiệnTại, KhôngTồnTại());  
      require(loanId != 0 && loanId <= currentLoanCount, DoesNotExist());  
  
      // địaChỉĐơnVịDịchVụ = _yêuCầuNgườiGọiLô(đơn_vị_dịch_vụ_s[mã_khoản_vay], i, địaChỉĐơnVịDịchVụ);  
      servicerAddress = _requireBatchCaller(servicers[loanId], i, servicerAddress);  
  
      // số_nguyên_128 phíDịchVụ = _lấyPhảiTrảRòng(mã_khoản_vay, TÀI_KHOẢN_PHÍ_DỊCH_VỤ_PHẢI_TRẢ, TÀI_KHOẢN_PHÍ_DỊCH_VỤ_ĐÃ_THANH_TOÁN);  
      int128 servicingFee = _getNetPayable(loanId, ACC_SERVICER_FEE_PAYABLE, ACC_SERVICER_FEE_PAID);  
      // số_nguyên_128 phíKhác = _lấyPhảiTrảRòng(mã_khoản_vay, TÀI_KHOẢN_PHÍ_KHÁC_ĐƠN_VỊ_DỊCH_VỤ_PHẢI_TRẢ, TÀI_KHOẢN_PHÍ_KHÁC_ĐƠN_VỊ_DỊCH_VỤ_ĐÃ_THANH_TOÁN);  
      int128 miscFee = _getNetPayable(loanId, ACC_SERVICER_MISC_FEE_PAYABLE, ACC_SERVICER_MISC_FEE_PAID);  
  
      // tổngChuyển += _rútVàoTàiKhoản(  
      totalTransfer += _withdrawToAccount(  
        // mã_khoản_vay,  
        loanId,  
        // TÀI_KHOẢN_PHÍ_DỊCH_VỤ_ĐÃ_THANH_TOÁN,  
        ACC_SERVICER_FEE_PAID,  
        // phíDịchVụ,  
        servicingFee,  
        // dấu_thời_gian,  
        timestamp,  
        // MỤC_RÚT_PHÍ_DỊCH_VỤ,  
        ENTRY_SERVICER_FEE_WITHDRAWAL,  
        // tham_chiếu  
        ref  
      // );  
      );  
      // tổngChuyển += _rútVàoTàiKhoản(  
      totalTransfer += _withdrawToAccount(  
        // mã_khoản_vay,  
        loanId,  
        // TÀI_KHOẢN_PHÍ_KHÁC_ĐƠN_VỊ_DỊCH_VỤ_ĐÃ_THANH_TOÁN,  
        ACC_SERVICER_MISC_FEE_PAID,  
        // phíKhác,  
        miscFee,  
        // dấu_thời_gian,  
        timestamp,  
        // MỤC_RÚT_PHÍ_KHÁC,  
        ENTRY_MISC_FEE_WITHDRAWAL,  
        // tham_chiếu  
        ref  
      // );  
      );  
  
      // kết_quả[i] = KếtQuảRútTiềnĐơnVịDịchVụ({mã_khoản_vay: mã_khoản_vay, phíKhác: phíKhác, phíDịchVụ: phíDịchVụ});  
      results[i] = ServicerWithdrawalResult({loanId: loanId, miscFee: miscFee, servicingFee: servicingFee});  
  
      // dữ_liệu[mã_khoản_vay].cậpNhậtLúc = dấu_thời_gian;  
      data[loanId].updatedAt = timestamp;  
    // }  
    }  
  
    // tiền_tệ.chuyểnAnToàn(địaChỉĐơnVịDịchVụ, số_nguyên_không_dấu_256(số_nguyên_256(tổngChuyển)));  
    currency.safeTransfer(servicerAddress, uint256(int256(totalTransfer)));  
  // }  
  }
 
  /**  
   * @inheritdoc ILoans  
   * Kế_thừa từ ILoans  
   * @dev Inverse of `servicerWithdraw`. Pulls tokens from `msg.sender` into the  
   * @dev Ngược_lại của `rútTiềnĐơnVịDịchVụ`. Kéo token từ `msg.người_gửi` vào  
   *      loan's cash account. Only servicer-paid accounts (or `SERVICER_ADJUSTMENT`)  
   *      tài_khoản tiền_mặt của khoản_vay. Chỉ các tài_khoản đã_thanh_toán đơn_vị_dịch_vụ (hoặc `ĐIỀU_CHỈNH_ĐƠN_VỊ_DỊCH_VỤ`)  
   *      are allowed as the `from` account.  
   *      được phép làm tài_khoản `từ`.  
   */  
  // hàm trảLạiTiền(  
  function returnFunds(  
    // số_nguyên_không_dấu_64 mã_khoản_vay,  
    uint64 loanId,  
    // số_nguyên_không_dấu_8 từ,  
    uint8 from,  
    // số_nguyên_128 số_tiền,  
    int128 amount,  
    // số_nguyên_không_dấu_48 dấu_thời_gian,  
    uint48 timestamp,  
    // số_nguyên_không_dấu_16 loạiMục,  
    uint16 entryType,  
    // bytes32 tham_chiếu  
    bytes32 ref  
  // )  
  )  
    // bên_ngoài  
    external  
    // khiKhôngDừng  
    whenNotPaused  
    // chỉĐơnVịDịchVụHoặcQuảnTrị(mã_khoản_vay)  
    onlyServicerOrAdmin(loanId)  
    // khôngTáiNhậpCảnh  
    nonReentrant  
    // chỉĐangHoạtĐộngHoặcĐãThanhToánĐầyĐủ(mã_khoản_vay)  
    onlyOutstandingOrFullyPaid(loanId)  
    // vớiCậpNhậtKhoảnVay(mã_khoản_vay, dấu_thời_gian)  
    withLoanUpdate(loanId, timestamp)  
    // trả_về (số_nguyên_không_dấu_128 chỉSốMục)  
    returns (uint128 entryIndex)  
  // {  
  {  
    // yêu_cầu(  
    require(  
      // từ == TÀI_KHOẢN_ĐIỀU_CHỈNH_ĐƠN_VỊ_DỊCH_VỤ ||  
      from == ACC_SERVICER_ADJUSTMENT ||  
        // ((từ == TÀI_KHOẢN_PHÍ_DỊCH_VỤ_ĐÃ_THANH_TOÁN || từ == TÀI_KHOẢN_PHÍ_KHÁC_ĐƠN_VỊ_DỊCH_VỤ_ĐÃ_THANH_TOÁN) &&  
        ((from == ACC_SERVICER_FEE_PAID || from == ACC_SERVICER_MISC_FEE_PAID) &&  
          // số_tiền <= _lấySốDưTàiKhoản(mã_khoản_vay, từ)),  
          amount <= _getAccountBalance(loanId, from)),  
      // TàiKhoảnKhôngHợpLệ()  
      InvalidAccount()  
    // );  
    );  
  
    // trả_về _nạpTiền(mã_khoản_vay, từ, số_tiền, msg.người_gửi, dấu_thời_gian, loạiMục, tham_chiếu);  
    return _deposit(loanId, from, amount, msg.sender, timestamp, entryType, ref);  
  // }  
  }  
  
  /// @inheritdoc ILoans  
  // Kế_thừa từ ILoans  
  // hàm tạoMụcSổCái(  
  function createLedgerEntries(  
    // số_nguyên_không_dấu_64 mã_khoản_vay,  
    uint64 loanId,  
    // số_nguyên_không_dấu_48 dấu_thời_gian,  
    uint48 timestamp,  
    // ĐầuVàoMụcSổCái[] dữ_liệu_gọi mụcSổCái_s  
    LedgerEntryInput[] calldata ledgerEntries  
  // )  
  )  
    // bên_ngoài  
    external  
    // khiKhôngDừng  
    whenNotPaused  
    // chỉĐơnVịDịchVụHoặcQuảnTrị(mã_khoản_vay)  
    onlyServicerOrAdmin(loanId)  
    // khoảnVayTồnTại(mã_khoản_vay)  
    loanExists(loanId)  
    // vớiCậpNhậtKhoảnVay(mã_khoản_vay, dấu_thời_gian)  
    withLoanUpdate(loanId, timestamp)  
    // trả_về (số_nguyên_không_dấu_128[] bộ_nhớ chỉSốMục_s)  
    returns (uint128[] memory entryIndices)  
  // {  
  {  
    // số_nguyên_không_dấu_256 độ_dài = mụcSổCái_s.độ_dài;  
    uint256 length = ledgerEntries.length;  
    // chỉSốMục_s = new số_nguyên_không_dấu_128[](độ_dài);  
    entryIndices = new uint128[](length);  
  
    // for (số_nguyên_không_dấu_256 i = 0; i < độ_dài; ++i) {  
    for (uint256 i = 0; i < length; ++i) {  
      // ĐầuVàoMụcSổCái dữ_liệu_gọi e = mụcSổCái_s[i];  
      LedgerEntryInput calldata e = ledgerEntries[i];  
      // yêu_cầu(e.từ != TÀI_KHOẢN_TIỀN_MẶT && e.đến != TÀI_KHOẢN_TIỀN_MẶT, TàiKhoảnKhôngHợpLệ());  
      require(e.from != ACC_CASH && e.to != ACC_CASH, InvalidAccount());  
      // chỉSốMục_s[i] = _tạoMụcNộiBộ(mã_khoản_vay, e.từ, e.đến, e.số_tiền, dấu_thời_gian, e.loạiMục, e.tham_chiếu);  
      entryIndices[i] = _createInternalEntry(loanId, e.from, e.to, e.amount, timestamp, e.entryType, e.ref);  
    // }  
    }  
  // }  
  }  
  
  /// @inheritdoc ILoans  
  // Kế_thừa từ ILoans  
  // hàm hoànTiềnNgườiVay(  
  function refundBorrower(  
    // số_nguyên_không_dấu_64 mã_khoản_vay,  
    uint64 loanId,  
    // số_nguyên_không_dấu_8 tàiKhoảnĐến,  
    uint8 toAccount,  
    // số_nguyên_128 số_tiền,  
    int128 amount,  
    // số_nguyên_không_dấu_48 dấu_thời_gian,  
    uint48 timestamp,  
    // số_nguyên_không_dấu_16 loạiMục,  
    uint16 entryType,  
    // bytes32 tham_chiếu  
    bytes32 ref  
  // )  
  )  
    // bên_ngoài  
    external  
    // khiKhôngDừng  
    whenNotPaused  
    // chỉĐơnVịDịchVụHoặcQuảnTrị(mã_khoản_vay)  
    onlyServicerOrAdmin(loanId)  
    // khôngTáiNhậpCảnh  
    nonReentrant  
    // chỉĐangHoạtĐộngHoặcĐãThanhToánĐầyĐủ(mã_khoản_vay)  
    onlyOutstandingOrFullyPaid(loanId)  
    // vớiCậpNhậtKhoảnVay(mã_khoản_vay, dấu_thời_gian)  
    withLoanUpdate(loanId, timestamp)  
    // trả_về (số_nguyên_không_dấu_128 chỉSốMục)  
    returns (uint128 entryIndex)  
  // {  
  {  
    // yêu_cầu(  
    require(  
      // tàiKhoảnĐến == TÀI_KHOẢN_LÃI_NGƯỜI_VAY_ĐÃ_THANH_TOÁN ||  
      toAccount == ACC_BORROWER_INTEREST_PAID ||  
        // tàiKhoảnĐến == TÀI_KHOẢN_PHÍ_KHÁC_NGƯỜI_VAY_ĐÃ_THANH_TOÁN ||  
        toAccount == ACC_BORROWER_MISC_FEE_PAID ||  
        // tàiKhoảnĐến == TÀI_KHOẢN_THANH_TOÁN_NGƯỜI_VAY,  
        toAccount == ACC_BORROWER_PAYMENT_CLEARING,  
      // TàiKhoảnKhôngHợpLệ()  
      InvalidAccount()  
    // );  
    );  
  
    // số_nguyên_128 có_thể_hoàn_tiền = -_lấySốDưTàiKhoản(mã_khoản_vay, tàiKhoảnĐến);  
    int128 refundable = -_getAccountBalance(loanId, toAccount);  
    // nếu (tàiKhoảnĐến != TÀI_KHOẢN_THANH_TOÁN_NGƯỜI_VAY) {  
    if (toAccount != ACC_BORROWER_PAYMENT_CLEARING) {  
      // số_nguyên_không_dấu_8 phảiThu = tàiKhoảnĐến == TÀI_KHOẢN_LÃI_NGƯỜI_VAY_ĐÃ_THANH_TOÁN  
      uint8 receivable = toAccount == ACC_BORROWER_INTEREST_PAID  
        // ? TÀI_KHOẢN_LÃI_NGƯỜI_VAY_PHẢI_THU  
        ? ACC_BORROWER_INTEREST_RECEIVABLE  
        // : TÀI_KHOẢN_PHÍ_KHÁC_NGƯỜI_VAY_PHẢI_THU;  
        : ACC_BORROWER_MISC_FEE_RECEIVABLE;  
      // có_thể_hoàn_tiền -= _lấySốDưTàiKhoản(mã_khoản_vay, phảiThu);  
      refundable -= _getAccountBalance(loanId, receivable);  
    // }  
    }  
    // yêu_cầu(số_tiền <= có_thể_hoàn_tiền, SốTiềnKhôngHợpLệ());  
    require(amount <= refundable, InvalidAmount());  
  
    // trả_về _rút(mã_khoản_vay, tàiKhoảnĐến, số_tiền, người_vay_s[mã_khoản_vay], dấu_thời_gian, loạiMục, tham_chiếu);  
    return _withdraw(loanId, toAccount, amount, borrowers[loanId], timestamp, entryType, ref);  
  // }  
  }
  
  /**  
   * @inheritdoc ILoans  
   * Kế_thừa từ ILoans  
   * @dev All loans must share the same originator (caller or admin acting on their  
   * @dev Tất_cả khoản_vay phải chia_sẻ cùng đơn_vị_khởi_tạo (người_gọi hoặc quản_trị_viên hành_động thay_mặt  
   *      behalf). Per-loan ledger entries are written individually but payouts are  
   *      họ). Các mục sổ_cái theo từng khoản_vay được ghi riêng_lẻ nhưng các khoản_chi_trả  
   *      consolidated into a single ERC20 transfer. Automatically withdraws all  
   *      được hợp_nhất thành một lần chuyển ERC20 duy_nhất. Tự_động rút tất_cả  
   *      available originator fees per loan.  
   *      phí đơn_vị_khởi_tạo có_sẵn theo từng khoản_vay.  
   */  
  // hàm rútTiềnĐơnVịKhởiTạo(  
  function originatorWithdraw(  
    // số_nguyên_không_dấu_64[] dữ_liệu_gọi mãKhoảnVay_s,  
    uint64[] calldata loanIds,  
    // số_nguyên_không_dấu_48 dấu_thời_gian,  
    uint48 timestamp,  
    // bytes32 tham_chiếu  
    bytes32 ref  
  // ) bên_ngoài khiKhôngDừng khôngTáiNhậpCảnh trả_về (KếtQuảRútTiềnĐơnVịKhởiTạo[] bộ_nhớ kết_quả) {  
  ) external whenNotPaused nonReentrant returns (OriginatorWithdrawalResult[] memory results) {  
    // số_nguyên_không_dấu_256 sốKhoảnVay = mãKhoảnVay_s.độ_dài;  
    uint256 numLoans = loanIds.length;  
    // kết_quả = new KếtQuảRútTiềnĐơnVịKhởiTạo[](sốKhoảnVay);  
    results = new OriginatorWithdrawalResult[](numLoans);  
  
    // số_nguyên_128 tổngChuyển = 0;  
    int128 totalTransfer = 0;  
    // địa_chỉ địaChỉĐơnVịKhởiTạo;  
    address originatorAddress;  
    // số_nguyên_không_dấu_64 sốLượngKhoảnVayHiệnTại = số_lượng_khoản_vay;  
    uint64 currentLoanCount = loanCount;  
  
    // for (số_nguyên_không_dấu_256 i = 0; i < sốKhoảnVay; ++i) {  
    for (uint256 i = 0; i < numLoans; ++i) {  
      // số_nguyên_không_dấu_64 mã_khoản_vay = mãKhoảnVay_s[i];  
      uint64 loanId = loanIds[i];  
  
      // yêu_cầu(mã_khoản_vay != 0 && mã_khoản_vay <= sốLượngKhoảnVayHiệnTại, KhôngTồnTại());  
      require(loanId != 0 && loanId <= currentLoanCount, DoesNotExist());  
  
      // địaChỉĐơnVịKhởiTạo = _yêuCầuNgườiGọiLô(đơn_vị_khởi_tạo_s[mã_khoản_vay], i, địaChỉĐơnVịKhởiTạo);  
      originatorAddress = _requireBatchCaller(originators[loanId], i, originatorAddress);  
  
      // số_nguyên_128 số_tiền = _lấyPhảiTrảRòng(mã_khoản_vay, TÀI_KHOẢN_PHÍ_KHỞI_TẠO_PHẢI_TRẢ, TÀI_KHOẢN_PHÍ_KHỞI_TẠO_ĐÃ_THANH_TOÁN);  
      int128 amount = _getNetPayable(loanId, ACC_ORIGINATOR_FEE_PAYABLE, ACC_ORIGINATOR_FEE_PAID);  
  
      // tổngChuyển += _rútVàoTàiKhoản(  
      totalTransfer += _withdrawToAccount(  
        // mã_khoản_vay,  
        loanId,  
        // TÀI_KHOẢN_PHÍ_KHỞI_TẠO_ĐÃ_THANH_TOÁN,  
        ACC_ORIGINATOR_FEE_PAID,  
        // số_tiền,  
        amount,  
        // dấu_thời_gian,  
        timestamp,  
        // MỤC_RÚT_PHÍ_KHỞI_TẠO,  
        ENTRY_ORIGINATOR_FEE_WITHDRAWAL,  
        // tham_chiếu  
        ref  
      // );  
      );  
  
      // kết_quả[i] = KếtQuảRútTiềnĐơnVịKhởiTạo({mã_khoản_vay: mã_khoản_vay, số_tiền: số_tiền});  
      results[i] = OriginatorWithdrawalResult({loanId: loanId, amount: amount});  
  
      // dữ_liệu[mã_khoản_vay].cậpNhậtLúc = dấu_thời_gian;  
      data[loanId].updatedAt = timestamp;  
    // }  
    }  
  
    // tiền_tệ.chuyểnAnToàn(địaChỉĐơnVịKhởiTạo, số_nguyên_không_dấu_256(số_nguyên_256(tổngChuyển)));  
    currency.safeTransfer(originatorAddress, uint256(int256(totalTransfer)));  
  // }  
  }  
  
  /**  
   * @inheritdoc ILoans  
   * Kế_thừa từ ILoans  
   * @dev All loans must have the same investor (NFT owner) and the same lock state.  
   * @dev Tất_cả khoản_vay phải có cùng nhà_đầu_tư (chủ_sở_hữu NFT) và cùng trạng_thái khóa.  
   *      If the first loan is unlocked, every loan in the batch must be unlocked and  
   *      Nếu khoản_vay đầu_tiên được mở_khóa, mọi khoản_vay trong lô phải được mở_khóa và  
   *      the caller must be the investor or admin; funds go to the investor.  
   *      người_gọi phải là nhà_đầu_tư hoặc quản_trị_viên; tiền chuyển đến nhà_đầu_tư.  
   *      If the first loan is locked, every loan must be locked to the same address  
   *      Nếu khoản_vay đầu_tiên bị khóa, mọi khoản_vay phải bị khóa với cùng địa_chỉ  
   *      and the caller must be that unlocker; funds go to `msg.sender`.  
   *      và người_gọi phải là người_mở_khóa đó; tiền chuyển đến `msg.người_gửi`.  
   */  
  // hàm rútTiềnNhàĐầuTư(  
  function investorWithdraw(  
    // số_nguyên_không_dấu_64[] dữ_liệu_gọi mãKhoảnVay_s,  
    uint64[] calldata loanIds,  
    // số_nguyên_không_dấu_48 dấu_thời_gian,  
    uint48 timestamp,  
    // bytes32 tham_chiếu  
    bytes32 ref  
  // ) bên_ngoài khiKhôngDừng khôngTáiNhậpCảnh trả_về (KếtQuảRútTiềnNhàĐầuTư[] bộ_nhớ kết_quả) {  
  ) external whenNotPaused nonReentrant returns (InvestorWithdrawalResult[] memory results) {  
    // số_nguyên_không_dấu_256 sốKhoảnVay = mãKhoảnVay_s.độ_dài;  
    uint256 numLoans = loanIds.length;  
    // kết_quả = new KếtQuảRútTiềnNhàĐầuTư[](sốKhoảnVay);  
    results = new InvestorWithdrawalResult[](numLoans);  
    // nếu (sốKhoảnVay == 0) trả_về kết_quả;  
    if (numLoans == 0) return results;  
  
    // INFTKhoảnVay nft = NFT_khoản_vay;  
    ILoansNFT nft = loansNFT;  
    // số_nguyên_không_dấu_64 sốLượngKhoảnVayHiệnTại = số_lượng_khoản_vay;  
    uint64 currentLoanCount = loanCount;  
  
    // Handle the first loan outside the loop so the investor/unlocker check  
    // Xử_lý khoản_vay đầu_tiên bên_ngoài vòng_lặp để kiểm_tra nhà_đầu_tư/người_mở_khóa  
    // and caller authorization only happen once.  
    // và ủy_quyền người_gọi chỉ xảy_ra một lần.  
    // số_nguyên_không_dấu_64 mãKhoảnVayĐầuTiên = mãKhoảnVay_s[0];  
    uint64 firstLoanId = loanIds[0];  
    // yêu_cầu(mãKhoảnVayĐầuTiên != 0 && mãKhoảnVayĐầuTiên <= sốLượngKhoảnVayHiệnTại, KhôngTồnTại());  
    require(firstLoanId != 0 && firstLoanId <= currentLoanCount, DoesNotExist());  
  
    // (địa_chỉ địaChỉNhàĐầuTưĐãLưu, địa_chỉ người_mở_khóa_đã_lưu) = nft.chủSởHữuVàNgườiMởKhóa(số_nguyên_không_dấu_256(mãKhoảnVayĐầuTiên));  
    (address cachedInvestorAddress, address cachedUnlocker) = nft.ownerAndUnlocker(uint256(firstLoanId));  
    // địa_chỉ người_nhận;  
    address recipient;  
    // nếu (người_mở_khóa_đã_lưu == địa_chỉ(0)) {  
    if (cachedUnlocker == address(0)) {  
      // _yêuCầuNgườiGọiHoặcQuảnTrị(địaChỉNhàĐầuTưĐãLưu);  
      _requireCallerOrAdmin(cachedInvestorAddress);  
      // người_nhận = địaChỉNhàĐầuTưĐãLưu;  
      recipient = cachedInvestorAddress;  
    // } else {  
    } else {  
      // yêu_cầu(người_mở_khóa_đã_lưu == msg.người_gửi, KhôngĐượcPhép());  
      require(cachedUnlocker == msg.sender, Unauthorized());  
      // người_nhận = msg.người_gửi;  
      recipient = msg.sender;  
    // }  
    }  
  
    // số_nguyên_128 tổngChuyển = _xửLýRútTiềnNhàĐầuTư(mãKhoảnVayĐầuTiên, dấu_thời_gian, tham_chiếu, kết_quả, 0);  
    int128 totalTransfer = _processInvestorWithdrawal(firstLoanId, timestamp, ref, results, 0);  
  
    // for (số_nguyên_không_dấu_256 i = 1; i < sốKhoảnVay; ) {  
    for (uint256 i = 1; i < numLoans; ) {  
      // số_nguyên_không_dấu_64 mã_khoản_vay = mãKhoảnVay_s[i];  
      uint64 loanId = loanIds[i];  
      // yêu_cầu(mã_khoản_vay != 0 && mã_khoản_vay <= sốLượngKhoảnVayHiệnTại, KhôngTồnTại());  
      require(loanId != 0 && loanId <= currentLoanCount, DoesNotExist());  
      // (địa_chỉ nhàĐầuTưKhoảnVay, địa_chỉ người_mở_khóa_khoản_vay) = nft.chủSởHữuVàNgườiMởKhóa(số_nguyên_không_dấu_256(mã_khoản_vay));  
      (address loanInvestor, address loanUnlocker) = nft.ownerAndUnlocker(uint256(loanId));  
      // yêu_cầu(nhàĐầuTưKhoảnVay == địaChỉNhàĐầuTưĐãLưu, KhôngĐượcPhép());  
      require(loanInvestor == cachedInvestorAddress, Unauthorized());  
      // yêu_cầu(người_mở_khóa_khoản_vay == người_mở_khóa_đã_lưu, KhôngĐượcPhép());  
      require(loanUnlocker == cachedUnlocker, Unauthorized());  
  
      // số_nguyên_128 chuyển = _xửLýRútTiềnNhàĐầuTư(mã_khoản_vay, dấu_thời_gian, tham_chiếu, kết_quả, i);  
      int128 transfer = _processInvestorWithdrawal(loanId, timestamp, ref, results, i);  
      // không_kiểm_tra {  
      unchecked {  
        // tổngChuyển += chuyển;  
        totalTransfer += transfer;  
        // ++i;  
        ++i;  
      // }  
      }  
    // }  
    }  
  
    // tiền_tệ.chuyểnAnToàn(người_nhận, số_nguyên_không_dấu_256(số_nguyên_256(tổngChuyển)));  
    currency.safeTransfer(recipient, uint256(int256(totalTransfer)));  
  // }  
  }  
  
  /**  
   * @dev Per-loan helper used by `investorWithdraw`. Writes the per-loan result  
   * @dev Hàm_trợ_giúp theo từng khoản_vay được dùng bởi `rútTiềnNhàĐầuTư`. Ghi kết_quả theo từng khoản_vay  
   *      directly into the caller's `results` array slot to avoid an extra  
   *      trực_tiếp vào ô mảng `kết_quả` của người_gọi để tránh  
   *      memory struct allocation and copy. Returns the amount to add to the  
   *      cấp_phát và sao_chép struct bộ_nhớ thêm. Trả_về số_tiền để cộng vào  
   *      caller's running transfer total.  
   *      tổng chuyển đang_chạy của người_gọi.  
   */  
  // hàm _xửLýRútTiềnNhàĐầuTư(  
  function _processInvestorWithdrawal(  
    // số_nguyên_không_dấu_64 mã_khoản_vay,  
    uint64 loanId,  
    // số_nguyên_không_dấu_48 dấu_thời_gian,  
    uint48 timestamp,  
    // bytes32 tham_chiếu,  
    bytes32 ref,  
    // KếtQuảRútTiềnNhàĐầuTư[] bộ_nhớ kết_quả,  
    InvestorWithdrawalResult[] memory results,  
    // số_nguyên_không_dấu_256 chỉSốKếtQuả  
    uint256 resultIndex  
  // ) nội_bộ trả_về (số_nguyên_128 chuyển) {  
  ) internal returns (int128 transfer) {  
    // số_nguyên_128 lãi = _lấyLãiRòngPhảiTrảChoNhàĐầuTư(mã_khoản_vay);  
    int128 interest = _getNetInterestPayableToInvestor(loanId);  
    // số_nguyên_128 vốnGốc = _lấyVốnGốcRòngPhảiTrảChoNhàĐầuTư(mã_khoản_vay);  
    int128 principal = _getNetPrincipalPayableToInvestor(loanId);  
  
    // chuyển =  
    transfer =  
      // _rútVàoTàiKhoản(  
      _withdrawToAccount(  
        // mã_khoản_vay,  
        loanId,  
        // TÀI_KHOẢN_LÃI_NHÀ_ĐẦU_TƯ_ĐÃ_THANH_TOÁN,  
        ACC_INVESTOR_INTEREST_PAID,  
        // lãi,  
        interest,  
        // dấu_thời_gian,  
        timestamp,  
        // MỤC_RÚT_LÃI_NHÀ_ĐẦU_TƯ,  
        ENTRY_INVESTOR_INTEREST_WITHDRAWAL,  
        // tham_chiếu  
        ref  
      // ) +  
      ) +  
      // _rútVàoTàiKhoản(  
      _withdrawToAccount(  
        // mã_khoản_vay,  
        loanId,  
        // TÀI_KHOẢN_VỐN_GỐC_NHÀ_ĐẦU_TƯ_ĐÃ_HOÀN_TRẢ,  
        ACC_INVESTOR_PRINCIPAL_REPAID,  
        // vốnGốc,  
        principal,  
        // dấu_thời_gian,  
        timestamp,  
        // MỤC_RÚT_VỐN_GỐC_NHÀ_ĐẦU_TƯ,  
        ENTRY_INVESTOR_PRINCIPAL_WITHDRAWAL,  
        // tham_chiếu  
        ref  
      // );  
      );  
  
    // kết_quả[chỉSốKếtQuả] = KếtQuảRútTiềnNhàĐầuTư({mã_khoản_vay: mã_khoản_vay, vốnGốc: vốnGốc, lãi: lãi});  
    results[resultIndex] = InvestorWithdrawalResult({loanId: loanId, principal: principal, interest: interest});  
  
    // dữ_liệu[mã_khoản_vay].cậpNhậtLúc = dấu_thời_gian;  
    data[loanId].updatedAt = timestamp;  
  // }  
  }

  /**  
   * @dev Allows only Active and ChargedOff.  
   * @dev Chỉ cho phép ĐangHoạtĐộng và ĐãXóaNợ.  
   */  
  // hàm _chỉĐangHoạtĐộng(số_nguyên_không_dấu_64 mã_khoản_vay) nội_bộ xem {  
  function _onlyOutstanding(uint64 loanId) internal view {  
    // TrạngTháiKhoảnVay trạng_thái = dữ_liệu[mã_khoản_vay].trạng_thái;  
    LoanStatus status = data[loanId].status;  
    // yêu_cầu(trạng_thái == TrạngTháiKhoảnVay.ĐangHoạtĐộng || trạng_thái == TrạngTháiKhoảnVay.ĐãXóaNợ, TrạngTháiKhôngHợpLệ());  
    require(status == LoanStatus.Active || status == LoanStatus.ChargedOff, InvalidStatus());  
  // }  
  }  
  
  /**  
   * @dev Allows Active, ChargedOff, and FullyPaid. Used for ledger operations that may  
   * @dev Cho phép ĐangHoạtĐộng, ĐãXóaNợ, và ĐãThanhToánĐầyĐủ. Dùng cho các thao_tác sổ_cái có_thể  
   *      still occur after final payment (e.g. waterfall allocating a residual payment).  
   *      vẫn xảy_ra sau khoản_thanh_toán cuối (ví_dụ: thác_nước phân_bổ khoản_thanh_toán còn_lại).  
   */  
  // hàm _chỉĐangHoạtĐộngHoặcĐãThanhToánĐầyĐủ(số_nguyên_không_dấu_64 mã_khoản_vay) nội_bộ xem {  
  function _onlyOutstandingOrFullyPaid(uint64 loanId) internal view {  
    // TrạngTháiKhoảnVay trạng_thái = dữ_liệu[mã_khoản_vay].trạng_thái;  
    LoanStatus status = data[loanId].status;  
    // yêu_cầu(  
    require(  
      // trạng_thái == TrạngTháiKhoảnVay.ĐangHoạtĐộng || trạng_thái == TrạngTháiKhoảnVay.ĐãXóaNợ || trạng_thái == TrạngTháiKhoảnVay.ĐãThanhToánĐầyĐủ,  
      status == LoanStatus.Active || status == LoanStatus.ChargedOff || status == LoanStatus.FullyPaid,  
      // TrạngTháiKhôngHợpLệ()  
      InvalidStatus()  
    // );  
    );  
  // }  
  }  
  
  /**  
   * @dev Allows any status except DoesNotExist, Cancelled, Closed.  
   * @dev Cho phép bất_kỳ trạng_thái nào ngoại_trừ KhôngTồnTại, ĐãHủy, ĐãĐóng.  
   */  
  // hàm _khôngKếtThúc(số_nguyên_không_dấu_64 mã_khoản_vay) nội_bộ xem {  
  function _notTerminal(uint64 loanId) internal view {  
    // TrạngTháiKhoảnVay trạng_thái = dữ_liệu[mã_khoản_vay].trạng_thái;  
    LoanStatus status = data[loanId].status;  
    // yêu_cầu(  
    require(  
      // trạng_thái != TrạngTháiKhoảnVay.KhôngTồnTại && trạng_thái != TrạngTháiKhoảnVay.ĐãHủy && trạng_thái != TrạngTháiKhoảnVay.ĐãĐóng,  
      status != LoanStatus.DoesNotExist && status != LoanStatus.Cancelled && status != LoanStatus.Closed,  
      // TrạngTháiKhôngHợpLệ()  
      InvalidStatus()  
    // );  
    );  
  // }  
  }  
  
  // hàm _chỉĐơnVịDịchVụHoặcQuảnTrị(số_nguyên_không_dấu_64 mã_khoản_vay) nội_bộ xem {  
  function _onlyServicerOrAdmin(uint64 loanId) internal view {  
    // _yêuCầuNgườiGọiHoặcQuảnTrị(đơn_vị_dịch_vụ_s[mã_khoản_vay]);  
    _requireCallerOrAdmin(servicers[loanId]);  
  // }  
  }  
  
  // hàm _chỉNgườiVayHoặcQuảnTrị(số_nguyên_không_dấu_64 mã_khoản_vay) nội_bộ xem {  
  function _onlyBorrowerOrAdmin(uint64 loanId) internal view {  
    // _yêuCầuNgườiGọiHoặcQuảnTrị(người_vay_s[mã_khoản_vay]);  
    _requireCallerOrAdmin(borrowers[loanId]);  
  // }  
  }  
  
  // hàm _vớiCậpNhậtKhoảnVay(số_nguyên_không_dấu_64 mã_khoản_vay, số_nguyên_không_dấu_48 dấu_thời_gian) nội_bộ {  
  function _withLoanUpdate(uint64 loanId, uint48 timestamp) internal {  
    // dữ_liệu[mã_khoản_vay].cậpNhậtLúc = dấu_thời_gian;  
    data[loanId].updatedAt = timestamp;  
  // }  
  }  
  
  // hàm _yêuCầuNgườiGọiHoặcQuảnTrị(địa_chỉ địaChỉ) riêng_tư xem {  
  function _requireCallerOrAdmin(address addr) private view {  
    // yêu_cầu(địaChỉ == msg.người_gửi || _làQuảnTrịViênHoặcNgườiGiámHộ(msg.người_gửi), KhôngĐượcPhép());  
    require(addr == msg.sender || _isAdminOrGuardian(msg.sender), Unauthorized());  
  // }  
  }  
  
  // hàm _yêuCầuNgườiGọiLô(địa_chỉ địaChỉVaiTrò, số_nguyên_không_dấu_256 chỉSố, địa_chỉ chuẩn) riêng_tư xem trả_về (địa_chỉ) {  
  function _requireBatchCaller(address roleAddr, uint256 index, address canonical) private view returns (address) {  
    // chỉSố == 0 ? _yêuCầuNgườiGọiHoặcQuảnTrị(địaChỉVaiTrò) : yêu_cầu(địaChỉVaiTrò == chuẩn, KhôngĐượcPhép());  
    index == 0 ? _requireCallerOrAdmin(roleAddr) : require(roleAddr == canonical, Unauthorized());  
    // trả_về địaChỉVaiTrò;  
    return roleAddr;  
  // }  
  } 
}
