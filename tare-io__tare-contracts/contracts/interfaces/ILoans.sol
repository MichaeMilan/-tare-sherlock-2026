// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ILoansNFT} from "contracts/interfaces/ILoansNFT.sol";

/**  
 * @thông_báo Định danh vai trò theo từng khoản vay được sử dụng bởi lớp ủy quyền sổ địa chỉ.  
 * @notice Per-loan role identifiers used by the address-book authorization layer.  
 * @nhà_phát_triển Vị trí bit của mỗi vai trò được xác định bởi thứ tự kiểu_liệt_kê  
 *                 và mặt_nạ_bit sổ địa chỉ được lưu trong `ILoansAuth.addressBook`.  
 * @dev Each role's bit position is determined by enum order and the address-book  
 *      bitmask stored in `ILoansAuth.addressBook`.  
 */  
// kiểu_liệt_kê VaiTrò {  
enum Roles {  
  // NguoiVay,  
  Borrower,  
  // DonViKhoiTao,  
  Originator,  
  // NhaDauTu,  
  Investor,  
  // DonViDichVu  
  Servicer  
}  
  
/**  
 * @thông_báo Trạng thái vòng đời khoản vay.  
 * @notice Loan lifecycle status.  
 */  
// kiểu_liệt_kê TrangThaiKhoanVay {  
enum LoanStatus {  
  KhongTonTai, // 0 - Giá trị canh gác (dùng như "không thay đổi" trong cap_nhat_du_lieu_khoan_vay)  
  DoesNotExist, // 0 - Sentinel value (used as "no change" in updateLoanData)  
  DaKhoiTao,   // 1 - Khoản vay đã tạo, chờ giải ngân  
  Created,     // 1 - Loan created, awaiting funding  
  DaNhanVonDayDu, // 2 - Đã nhận vốn đầy đủ, chờ giải phóng  
  FullyFunded,    // 2 - Fully funded, awaiting disbursement  
  DangHoatDong, // 3 - Đã giải phóng và đang hoạt động  
  Active,       // 3 - Disbursed and performing  
  DaThanhToanDayDu, // 4 - Người vay đã thanh toán đầy đủ  
  FullyPaid,        // 4 - Borrower paid in full  
  DaHuy,     // 5 - Đã hủy trước khi giải phóng  
  Cancelled, // 5 - Cancelled before disbursement  
  DaXoaNo,   // 6 - Đã xóa nợ xấu  
  ChargedOff, // 6 - Written off as bad debt  
  DaDong  // 7 - Không còn hoạt động nào được mong đợi  
  Closed  // 7 - No further activity expected  
}  
  
/**  
 * @thông_báo Bản ghi sổ cái bất biến của một lần chuyển nhượng từ tài khoản sang tài khoản.  
 * @notice Immutable ledger record of a single account-to-account transfer.  
 * @nhà_phát_triển Mọi hoạt động tài chính thay đổi trạng thái trong `Loans` đều tạo ra ít nhất một `BanGhi`.  
 * @dev Every state-changing financial operation in `Loans` produces at least one `Entry`.  
 *      `từ` và `đến` là các giá trị kiểu_liệt_kê `TaiKhoan` được ép kiểu sang `uint8`.  
 *      `from` and `to` are `Account` enum values cast to `uint8`.  
 *      `loai_ban_ghi` là một trong các hằng số trong `LedgerEntries.sol`.  
 *      `entryType` is one of the constants in `LedgerEntries.sol`.  
 */  
// cấu_trúc BanGhi {  
struct Entry {  
  // int128 so_luong;  
  int128 amount;  
  // uint48 dau_thoi_gian;  
  uint48 timestamp;  
  // uint8 tu;  
  uint8 from;  
  // uint8 den;  
  uint8 to;  
  // uint16 loai_ban_ghi;  
  uint16 entryType;  
  // bytes32 tham_chieu;  
  bytes32 ref;  
}  
  
/**  
 * @thông_báo Các trường trạng thái và ngày có thể thay đổi theo từng khoản vay,  
 *            được cập nhật qua vòng đời khoản vay.  
 * @notice Mutable per-loan status and date fields, updated through the loan lifecycle.  
 */  
// cấu_trúc DuLieuKhoanVay {  
struct LoanData {  
  // TrangThaiKhoanVay trang_thai;  
  LoanStatus status;  
  // uint48 cap_nhat_luc;  
  uint48 updatedAt;  
  // uint48 ngay_thanh_toan_cuoi;  
  uint48 lastPaymentDate;  
  // uint48 ngay_den_han_tiep;  
  uint48 nextDueDate;  
  // uint48 ngay_dao_han;  
  uint48 maturityDate;  
}

/**  
 * @thông_báo Điều khoản khoản vay, được đặt tại `giai_phong`.  
 * @notice Loan terms, set at `disburse`.  
 * Có thể chỉnh sửa sau đó qua `cap_nhat_dieu_khoan_khoan_vay` cho các trường hợp đặc biệt.  
 * Can be edited thereafter via `updateLoanTerms` for edge cases.  
 */  
// cấu_trúc DieuKhoanKhoanVay {  
struct LoanTerms {  
  /// @thông_báo Ngày khởi tạo khoản vay  
  /// @notice Loan origination date  
  // uint48 ngay_khoi_tao;  
  uint48 originationDate;  
  /// @thông_báo Lãi suất hàng năm tính bằng điểm cơ bản (500 = 5.00%), quy ước đếm ngày 30/360.  
  /// @notice Annual interest rate in basis points (500 = 5.00%), 30/360 day-count convention.  
  // uint32 lai_suat;  
  uint32 interestRate;  
  /// @thông_báo Số tiền thanh toán hàng tháng dự kiến (đơn vị tiền tệ cơ sở).  
  /// @notice Expected monthly payment amount (currency base units).  
  // int128 thanh_toan_hang_thang_du_kien;  
  int128 expectedMonthlyPayment;  
}  
  
/**  
 * @thông_báo Phân tích theo từng khoản vay được trả về bởi `rut_tien_nha_dau_tu` cho  
 *            mỗi lần rút dòng tiền khoản vay được xử lý.  
 * @notice Per-loan breakdown returned by `investorWithdraw` for  
 *         each loan cashflows withdrawal processed.  
 */  
// cấu_trúc KetQuaRutTienNhaDauTu {  
struct InvestorWithdrawalResult {  
  // uint64 ma_khoan_vay;  
  uint64 loanId;  
  // int128 goc;  
  int128 principal;  
  // int128 lai;  
  int128 interest;  
}  
  
/**  
 * @thông_báo Số tiền theo từng khoản vay được trả về bởi `rut_tien_don_vi_khoi_tao` cho mỗi khoản vay được xử lý.  
 * @notice Per-loan amount returned by `originatorWithdraw` for each loan processed.  
 */  
// cấu_trúc KetQuaRutTienDonViKhoiTao {  
struct OriginatorWithdrawalResult {  
  // uint64 ma_khoan_vay;  
  uint64 loanId;  
  // int128 so_luong;  
  int128 amount;  
}  
  
/**  
 * @thông_báo Phân tích theo từng khoản vay được trả về bởi `rut_tien_don_vi_dich_vu` cho mỗi khoản vay được xử lý.  
 * @notice Per-loan breakdown returned by `servicerWithdraw` for each loan processed.  
 */  
// cấu_trúc KetQuaRutTienDonViDichVu {  
struct ServicerWithdrawalResult {  
  // uint64 ma_khoan_vay;  
  uint64 loanId;  
  // int128 phi_khac;  
  int128 miscFee;  
  // int128 phi_dich_vu;  
  int128 servicingFee;  
}  
  
/**  
 * @thông_báo Ảnh chụp định giá tổng hợp được trả về bởi `lay_gia_tri_khoan_vay`.  
 * @notice Aggregated valuation snapshot returned by `getLoanValues`.  
 */  
// cấu_trúc GiaTriKhoanVay {  
struct LoanValue {  
  /**  
   * @thông_báo Vốn nhà đầu tư đã triển khai và chưa được hoàn trả:  
   *            `-TK_GỐC_PHẢI_TRẢ_NHÀ_ĐẦU_TƯ - TK_GỐC_ĐÃ_HOÀN_TRẢ_NHÀ_ĐẦU_TƯ`.  
   * @notice Investor capital deployed and not yet returned:  
   *         `-ACC_INVESTOR_PRINCIPAL_PAYABLE - ACC_INVESTOR_PRINCIPAL_REPAID`.  
   * @nhà_phát_triển Bao gồm cả phần vẫn còn với người vay và phần đã nằm dưới dạng  
   *                 tiền mặt có thể rút trong `Loans.sol`.  
   * @dev Includes both the portion still out with the borrower and the portion already sitting  
   *      as withdrawable cash in `Loans.sol`.  
   */  
  // int128 goc_nha_dau_tu_con_lai;  
  int128 outstandingInvestorPrincipal;  
  /// @thông_báo Tiền mặt gốc được giữ trong Loans.sol cho nhà đầu tư, chờ rút.  
  /// @notice Principal cash held in Loans.sol for the investor, awaiting withdrawal.  
  // int128 goc_nha_dau_tu_co_the_rut;  
  int128 investorPrincipalWithdrawable;  
  /// @thông_báo Tiền mặt lãi được phân bổ theo thác nước được giữ trong Loans.sol cho nhà đầu tư, chờ rút.  
  /// @notice Waterfall-allocated interest cash held in Loans.sol for the investor, awaiting withdrawal.  
  // int128 lai_nha_dau_tu_co_the_rut;  
  int128 investorInterestWithdrawable;  
  // TrangThaiKhoanVay trang_thai;  
  LoanStatus status;  
  // uint48 ngay_den_han_tiep;  
  uint48 nextDueDate;  
}  
  
/**  
 * @thông_báo Đầu vào mô tả một bản ghi sổ cái đơn lẻ được truyền vào `tao_ban_ghi_so_cai`.  
 * @notice Input describing a single ledger entry passed to `createLedgerEntries`.  
 */  
// cấu_trúc DauVaoBanGhiSoCai {  
struct LedgerEntryInput {  
  // uint8 tu;  
  uint8 from;  
  // uint8 den;  
  uint8 to;  
  // int128 so_luong;  
  int128 amount;  
  // uint16 loai_ban_ghi;  
  uint16 entryType;  
  // bytes32 tham_chieu;  
  bytes32 ref;  
}

/**  
 * @tiêu_đề IKhoanVay  
 * @title ILoans  
 * @thông_báo Giao diện giao thức cho vay Tare cốt lõi: vòng đời khoản vay,  
 *            bản ghi sổ cái bút toán kép, ủy quyền theo vai trò,  
 *            và quản lý tiền mặt cho mỗi khoản vay.  
 * @notice Core Tare lending protocol interface: loan lifecycle, double-entry ledger entries,  
 *         per-role authorization, and cash custody for each loan.  
 */  
// giao_diện IKhoanVay {  
interface ILoans {  
  /** @thông_báo Ném ra khi id khoản vay không tương ứng với khoản vay đã tạo. */  
  /** @notice Thrown when a loan id does not correspond to a created loan. */  
  // lỗi KhongTonTai();  
  error DoesNotExist();  
  
  /** @thông_báo Ném ra khi id tài khoản nằm ngoài phạm vi `TaiKhoan` được hỗ trợ. */  
  /** @notice Thrown when an account id is outside the supported `Account` range. */  
  // lỗi TaiKhoanKhongHopLe();  
  error InvalidAccount();  
  
  /** @thông_báo Ném ra khi số lượng bằng không, âm, hoặc nằm ngoài giới hạn cho phép. */  
  /** @notice Thrown when an amount is zero, negative, or otherwise outside the allowed bounds. */  
  // lỗi SoLuongKhongHopLe();  
  error InvalidAmount();  
  
  /** @thông_báo Ném ra khi ngày được cung cấp không hợp lệ (ví dụ: bằng không khi bắt buộc). */  
  /** @notice Thrown when a supplied date is invalid (e.g. zero where required). */  
  // lỗi NgayKhongHopLe();  
  error InvalidDate();  
  
  /** @thông_báo Ném ra khi số dư tài khoản tiền mặt của khoản vay không đủ cho một lần chuyển nhượng. */  
  /** @notice Thrown when the loan's cash account balance is insufficient for a transfer. */  
  // lỗi SoDuTienMatKhongDu();  
  error InsufficientCashBalance();  
  
  /** @thông_báo Ném ra khi `nguoi_gui_tin` không được ủy quyền cho thao tác đang thực hiện. */  
  /** @notice Thrown when `msg.sender` is not authorized for the attempted operation. */  
  // lỗi KhongDuocUyQuyen();  
  error Unauthorized();  
  
  /** @thông_báo Ném ra khi địa chỉ không được cung cấp ở nơi không được phép. */  
  /** @notice Thrown when a zero address is supplied where one is not permitted. */  
  // lỗi DiaChiKhong();  
  error ZeroAddress();  
  
  /** @thông_báo Ném ra khi vai trò được cung cấp không hợp lệ cho thao tác được yêu cầu. */  
  /** @notice Thrown when the supplied role is invalid for the requested operation. */  
  // lỗi VaiTroKhongHopLe();  
  error InvalidRole();  
  
  /** @thông_báo Ném ra khi trạng thái hiện tại của khoản vay không cho phép thao tác được yêu cầu. */  
  /** @notice Thrown when the loan's current status disallows the requested operation. */  
  // lỗi TrangThaiKhongHopLe();  
  error InvalidStatus();  
  
  /** @thông_báo Ném ra khi `so_luong_giai_phong_rong + phi_khoi_tao` không bằng cam kết khoản vay. */  
  /** @notice Thrown when `netDisbursedAmount + originationFee` does not equal the loan commitment. */  
  // lỗi SoLuongGiaiPhongKhongHopLe();  
  error InvalidAmountDisbursed();  
  
  /** @thông_báo Ném ra khi `giai_phong` được thực hiện trước khi khoản vay được nhận vốn đầy đủ. */  
  /** @notice Thrown when `disburse` is attempted before the loan has been fully funded. */  
  // lỗi ChuaNhanVonDayDu();  
  error NotFullyFunded();  
  
  /** @thông_báo Ném ra khi một khoản nạp sẽ vượt quá cam kết còn lại của khoản vay. */  
  /** @notice Thrown when a deposit would exceed the loan's outstanding commitment. */  
  // lỗi VuotQuaCamKet();  
  error ExceedsCommitment();  
  
  /** @thông_báo Ném ra khi một khoản phân bổ sẽ vượt quá số dư còn lại của tài khoản phải trả. */  
  /** @notice Thrown when an allocation would exceed a payable account's outstanding balance. */  
  // lỗi VuotQuaPhaiTra();  
  error ExceedsPayable();  
  
  /** @thông_báo Ném ra khi cố gắng khởi tạo một con trỏ kiểu singleton đã được đặt. */  
  /** @notice Thrown when attempting to initialize a singleton-style pointer that is already set. */  
  // lỗi DaKhoiTao();  
  error AlreadyInitialized();  
  
  /** @thông_báo Ném ra khi một hành động được thực hiện trên khoản vay có NFT hiện đang bị khóa. */  
  /** @notice Thrown when an action is attempted on a loan whose NFT is currently locked. */  
  // lỗi KhoanVayBiKhoa();  
  error LoanLocked();  
  
  /** @thông_báo Phát ra khi một khoản vay mới được tạo. */  
  /** @notice Emitted when a new loan is created. */  
  // sự_kiện KhoanVayDaTao(uint64 được_lập_chỉ_mục ma_khoan_vay);  
  event LoanCreated(uint64 indexed loanId);

    /**  
   * @thông_báo Phát ra cho mỗi mục sổ cái được ghi bởi hợp đồng.  
   * @tham_số chỉSốMục Id mục được đóng gói: `uint128(maKhoảnVay) << 64 | sốMục`.  
   * @tham_số từ Id tài khoản nguồn.  
   * @tham_số đến Id tài khoản đích.  
   * @tham_số sốTiền Số tiền có dấu được chuyển từ `từ` đến `đến`.  
   * @tham_số sốDưTừSauCapNhat Số dư của `từ` sau khi chuyển.  
   * @tham_số sốDưĐếnSauCapNhat Số dư của `đến` sau khi chuyển.  
   * @tham_số loạiMục Hằng số loại mục (xem `interfaces/LedgerEntries.sol`).  
   * @tham_số thamChieu Tham chiếu bên ngoài do người gọi cung cấp.  
   */  
  /**  
   * @notice Emitted for every ledger entry written by the contract.  
   * @param entryIndex Packed entry id: `uint128(loanId) << 64 | entryNumber`.  
   * @param from The source account id.  
   * @param to The destination account id.  
   * @param amount The signed amount transferred from `from` to `to`.  
   * @param updatedFromBalance Balance of `from` after the transfer.  
   * @param updatedToBalance Balance of `to` after the transfer.  
   * @param entryType Entry type constant (see `interfaces/LedgerEntries.sol`).  
   * @param ref Caller-supplied external reference.  
   */  
  // sự_kiện MụcĐượcTạo(  
  //   uint128 indexed chỉSốMục,  
  //   uint8 indexed từ,  
  //   uint8 đến,  
  //   int128 sốTiền,  
  //   int128 sốDưTừSauCapNhat,  
  //   int128 sốDưĐếnSauCapNhat,  
  //   uint16 loạiMục,  
  //   bytes32 thamChieu  
  // );  
  event EntryCreated(  
    uint128 indexed entryIndex,  
    uint8 indexed from,  
    uint8 to,  
    int128 amount,  
    int128 updatedFromBalance,  
    int128 updatedToBalance,  
    uint16 entryType,  
    bytes32 ref  
  );  
  
  // sự_kiện KhoảnVayNguoiVayCapNhat(uint64 indexed maKhoảnVay, address indexed nguoiVay);  
  event LoanBorrowerUpdated(uint64 indexed loanId, address indexed borrower);  
  
  // sự_kiện KhoảnVayNguoiDichVuCapNhat(uint64 indexed maKhoảnVay, address indexed nguoiDichVu);  
  event LoanServicerUpdated(uint64 indexed loanId, address indexed servicer);  
  
  /** @thông_báo Phát ra khi trạng thái khoản vay thay đổi qua `updateLoanData` hoặc một chuyển đổi tự động. */  
  /** @notice Emitted when the loan status changes via `updateLoanData` or an automatic transition. */  
  // sự_kiện KhoảnVayTrangThaiCapNhat(uint64 indexed maKhoảnVay, TrangThaiKhoảnVay trangThaiCu, TrangThaiKhoảnVay trangThaiMoi);  
  event LoanStatusUpdated(uint64 indexed loanId, LoanStatus oldStatus, LoanStatus newStatus);  
  
  // sự_kiện KhoảnVayNgayDaoHanTiepTheoCapNhat(uint64 indexed maKhoảnVay, uint48 ngayDaoHanTiepTheo);  
  event LoanNextDueDateUpdated(uint64 indexed loanId, uint48 nextDueDate);  
  
  // sự_kiện KhoảnVayNgayDaoHanCapNhat(uint64 indexed maKhoảnVay, uint48 ngayDaoHan);  
  event LoanMaturityDateUpdated(uint64 indexed loanId, uint48 maturityDate);  
  
  /** @thông_báo Phát ra khi các điều khoản khoản vay được đặt trong quá trình `giaiNgan` hoặc sau đó thay đổi qua `updateLoanTerms`. */  
  /** @notice Emitted when loan terms are set during `disburse` or subsequently changed via `updateLoanTerms`. */  
  // sự_kiện KhoảnVayDieuKhoanDuocDat(uint64 indexed maKhoảnVay, uint48 ngayKhoiTao, uint32 laiSuat, int128 thanhToanHangThangDuKien);  
  event LoanTermsSet(uint64 indexed loanId, uint48 originationDate, uint32 interestRate, int128 expectedMonthlyPayment);  
  
  /** @thông_báo Phát ra khi `pay` ghi lại một khoản thanh toán của người vay. */  
  /** @notice Emitted when `pay` records a borrower payment. */  
  // sự_kiện KhoảnVayNgayThanhToanCuoiCapNhat(uint64 indexed maKhoảnVay, uint48 ngayThanhToanCuoi);  
  event LoanLastPaymentDateUpdated(uint64 indexed loanId, uint48 lastPaymentDate);  
  
  /** @thông_báo Tổng số khoản vay từng được tạo. Bằng id khoản vay cao nhất, vì id bắt đầu từ 1. */  
  /** @notice Total number of loans ever created. Equals the highest loan id, since ids start at 1. */  
  // hàm demKhoảnVay() ngoại_vi xem trả_về (uint64);  
  function loanCount() external view returns (uint64);

  /**  
   * @thông_báo Trả về dữ liệu khoản vay có thể thay đổi cho `maKhoảnVay`.  
   * @tham_số maKhoảnVay Định danh khoản vay.  
   */  
  /**  
   * @notice Returns the mutable loan data for `loanId`.  
   * @param loanId The loan identifier.  
   */  
  // hàm duLieu(  
  //   uint64 maKhoảnVay  
  // )  
  //   ngoại_vi  
  //   xem  
  //   trả_về (TrangThaiKhoảnVay trangThai, uint48 capNhatLuc, uint48 ngayThanhToanCuoi, uint48 ngayDaoHanTiepTheo, uint48 ngayDaoHan);  
  function data(  
    uint64 loanId  
  )  
    external  
    view  
    returns (LoanStatus status, uint48 updatedAt, uint48 lastPaymentDate, uint48 nextDueDate, uint48 maturityDate);  
  
  /**  
   * @thông_báo Trả về các điều khoản khoản vay cho `maKhoảnVay`. Bằng không cho đến khi `giaiNgan` chạy; có thể thay đổi sau đó  
   *            qua `updateLoanTerms`.  
   * @tham_số maKhoảnVay Định danh khoản vay.  
   */  
  /**  
   * @notice Returns the loan terms for `loanId`. Zeroed until `disburse` runs; mutable thereafter  
   *         via `updateLoanTerms`.  
   * @param loanId The loan identifier.  
   */  
  // hàm dieuKhoanKhoảnVay(  
  //   uint64 maKhoảnVay  
  // ) ngoại_vi xem trả_về (uint48 ngayKhoiTao, uint32 laiSuat, int128 thanhToanHangThangDuKien);  
  function loanTerms(  
    uint64 loanId  
  ) external view returns (uint48 originationDate, uint32 interestRate, int128 expectedMonthlyPayment);  
  
  /** @thông_báo Trả về địa chỉ người vay đã đăng ký cho `maKhoảnVay`. */  
  /** @notice Returns the registered borrower address for `loanId`. */  
  // hàm nguoiVay(uint64 maKhoảnVay) ngoại_vi xem trả_về (address);  
  function borrowers(uint64 loanId) external view returns (address);  
  
  /** @thông_báo Trả về địa chỉ người khởi tạo đã đăng ký cho `maKhoảnVay`. */  
  /** @notice Returns the registered originator address for `loanId`. */  
  // hàm nguoiKhoiTao(uint64 maKhoảnVay) ngoại_vi xem trả_về (address);  
  function originators(uint64 loanId) external view returns (address);  
  
  /** @thông_báo Trả về địa chỉ người dịch vụ đã đăng ký cho `maKhoảnVay`. */  
  /** @notice Returns the registered servicer address for `loanId`. */  
  // hàm nguoiDichVu(uint64 maKhoảnVay) ngoại_vi xem trả_về (address);  
  function servicers(uint64 loanId) external view returns (address);  
  
  /** @thông_báo Trả về token ERC20 được sử dụng cho tất cả các hoạt động tài chính. */  
  /** @notice Returns the ERC20 token used for all financial operations. */  
  // hàm donViTienTe() ngoại_vi xem trả_về (IERC20);  
  function currency() external view returns (IERC20);  
  
  /**  
   * @thông_báo Trả về số dư có dấu cho một khóa `(maKhoảnVay, taiKhoan)` được đóng gói.  
   * @dev `khoa = uint72(maKhoảnVay) << 8 | uint8(taiKhoan)`. Ưu tiên `getLoanAccountBalance`.  
   */  
  /**  
   * @notice Returns the signed balance for a packed `(loanId, account)` key.  
   * @dev `key = uint72(loanId) << 8 | uint8(account)`. Prefer `getLoanAccountBalance`.  
   */  
  // hàm soDuTaiKhoan(uint72 khoa) ngoại_vi xem trả_về (int128);  
  function accountBalances(uint72 key) external view returns (int128);  
  
  /**  
   * @thông_báo Trả về mục bất biến được lưu trữ tại `chỉSốMục` được đóng gói.  
   * @tham_số chỉSốMục Id mục được đóng gói: `uint128(maKhoảnVay) << 64 | sốMục`.  
   */  
  /**  
   * @notice Returns the immutable entry stored at the packed `entryIndex`.  
   * @param entryIndex Packed entry id: `uint128(loanId) << 64 | entryNumber`.  
   */  
  // hàm cacMuc(  
  //   uint128 chỉSốMục  
  // ) ngoại_vi xem trả_về (int128 sốTiền, uint48 dấuThoiGian, uint8 từ, uint8 đến, uint16 loạiMục, bytes32 thamChieu);  
  function entries(  
    uint128 entryIndex  
  ) external view returns (int128 amount, uint48 timestamp, uint8 from, uint8 to, uint16 entryType, bytes32 ref);  
  
  /** @thông_báo Trả về số lượng mục được ghi lại cho `maKhoảnVay`. */  
  /** @notice Returns the number of entries recorded for `loanId`. */  
  // hàm soDemMuc(uint64 maKhoảnVay) ngoại_vi xem trả_về (uint64);  
  function entryCount(uint64 loanId) external view returns (uint64);  
  
  /** @thông_báo Trả về hợp đồng `LoansNFT` được liên kết dùng để theo dõi quyền sở hữu nhà đầu tư. */  
  /** @notice Returns the linked `LoansNFT` contract used to track investor ownership. */  
  // hàm nftKhoảnVay() ngoại_vi xem trả_về (ILoansNFT);  
  function loansNFT() external view returns (ILoansNFT);  
  
  /**  
   * @thông_báo Bộ khởi tạo một lần liên kết hợp đồng `LoansNFT`. Chỉ dành cho quản trị viên hoặc người giám hộ.  
   * @dev Hoàn tác nếu đã được khởi tạo.  
   * @tham_số _nftKhoảnVay Địa chỉ hợp đồng `LoansNFT`.  
   */  
  /**  
   * @notice One-shot initializer that links the `LoansNFT` contract. Admin or guardian only.  
   * @dev Reverts if already initialized.  
   * @param _loansNFT The `LoansNFT` contract address.  
   */  
  // hàm datNftKhoảnVay(address _nftKhoảnVay) ngoại_vi;  
  function setLoansNFT(address _loansNFT) external;

    /**  
   * @thông_báo Tạo một khoản vay mới ở trạng thái `Đã_Tạo` và đúc NFT khoản vay cho nhà đầu tư của nó.  
   * @dev Người gọi phải là `nguoiKhoiTao` được đặt tên (và là người khởi tạo được phê duyệt) hoặc quản trị viên/người giám hộ.  
   *      Tất cả bốn địa chỉ phải được đăng ký trong sổ địa chỉ của `nguoiKhoiTao` cho các vai trò của họ.  
   *      Ghi lại `ENTRY_LOAN_COMMITMENT` chuyển `sốTienGoc`  
   *      từ `ACC_UNFUNDED_COMMITMENT` đến `ACC_BORROWER_PRINCIPAL_RECEIVABLE`.  
   * @tham_số nguoiVay Địa chỉ người vay.  
   * @tham_số nhaDauTu Địa chỉ nhà đầu tư (nhận NFT khoản vay).  
   * @tham_số nguoiDichVu Địa chỉ người dịch vụ.  
   * @tham_số nguoiKhoiTao Địa chỉ người khởi tạo.  
   * @tham_số sốTienGoc Cam kết vốn gốc khoản vay.  
   * @tham_số dấuThoiGian Dấu thời gian khởi tạo ngoài chuỗi được ghi lại trên mục.  
   * @trả_về maKhoảnVay Định danh khoản vay mới.  
   */  
  /**  
   * @notice Create a new loan in `Created` status and mint its investor a loan NFT.  
   * @dev Caller must be the named `originator` (and an approved originator) or admin/guardian.  
   *      All four addresses must be registered in `originator`'s address book for their roles.  
   *      Records `ENTRY_LOAN_COMMITMENT` transferring `principalAmount`  
   *      from `ACC_UNFUNDED_COMMITMENT` to `ACC_BORROWER_PRINCIPAL_RECEIVABLE`.  
   * @param borrower The borrower address.  
   * @param investor The investor address (receives the loan NFT).  
   * @param servicer The servicer address.  
   * @param originator The originator address.  
   * @param principalAmount The loan principal commitment.  
   * @param timestamp The off-chain origination timestamp recorded on the entry.  
   * @return loanId The new loan identifier.  
   */  
  // hàm tao(  
  //   address nguoiVay,  
  //   address nhaDauTu,  
  //   address nguoiDichVu,  
  //   address nguoiKhoiTao,  
  //   int128 sốTienGoc,  
  //   uint48 dấuThoiGian  
  // ) ngoại_vi trả_về (uint64 maKhoảnVay);  
  function create(  
    address borrower,  
    address investor,  
    address servicer,  
    address originator,  
    int128 principalAmount,  
    uint48 timestamp  
  ) external returns (uint64 loanId);  
  
  /**  
   * @thông_báo Tài trợ một khoản vay ở trạng thái `Đã_Tạo` bằng cách rút tiền tệ từ nhà đầu tư.  
   * @dev Người gọi phải là chủ sở hữu NFT hiện tại (nhà đầu tư) hoặc quản trị viên/người giám hộ.  
   *      Khoản nạp phải bằng toàn bộ cam kết còn lại trong một lần gọi;  
   *      khi thành công khoản vay chuyển sang `Đã_Tài_Trợ_Đầy_Đủ`.  
   * @tham_số maKhoảnVay Định danh khoản vay.  
   * @tham_số sốTiền Số tiền vốn gốc để tài trợ (phải bằng cam kết).  
   * @tham_số dấuThoiGian Dấu thời gian tài trợ ngoài chuỗi được ghi lại trên mục.  
   * @tham_số thamChieu Tham chiếu bên ngoài do người gọi cung cấp.  
   * @trả_về chỉSốMục Id mục được đóng gói của khoản nạp được ghi lại.  
   */  
  /**  
   * @notice Fund a loan in `Created` status by pulling currency from the investor.  
   * @dev Caller must be the current NFT owner (investor) or admin/guardian.  
   *      The deposit must equal the full outstanding commitment in a single call;  
   *      on success the loan transitions to `FullyFunded`.  
   * @param loanId The loan identifier.  
   * @param amount The principal amount to fund (must equal commitment).  
   * @param timestamp The off-chain funding timestamp recorded on the entry.  
   * @param ref Caller-supplied external reference.  
   * @return entryIndex The packed entry id of the recorded deposit.  
   */  
  // hàm taiTro(uint64 maKhoảnVay, int128 sốTiền, uint48 dấuThoiGian, bytes32 thamChieu) ngoại_vi trả_về (uint128 chỉSốMục);  
  function fund(uint64 loanId, int128 amount, uint48 timestamp, bytes32 ref) external returns (uint128 entryIndex);  
  
  /**  
   * @thông_báo Giải ngân vốn đã tài trợ cho người vay và khóa các điều khoản ghi một lần của khoản vay.  
   * @dev Người gọi phải là người khởi tạo của khoản vay hoặc quản trị viên/người giám hộ. Khoản vay phải ở trạng thái `Đã_Tài_Trợ_Đầy_Đủ`.  
   *      `sốTienGiaiNganThuan + phiKhoiTao` phải bằng cam kết còn lại.  
   *      Giữ lại `phiKhoiTao` vào `ACC_ORIGINATOR_FEE_PAYABLE`, chuyển `sốTienGiaiNganThuan`  
   *      cho người vay, và chuyển khoản vay sang `Đang_Hoạt_Động`.  
   * @tham_số maKhoảnVay Định danh khoản vay.  
   * @tham_số sốTienGiaiNganThuan Số tiền gửi cho người vay (sau khi trừ phí khởi tạo).  
   * @tham_số phiKhoiTao Phí giữ lại cho người khởi tạo (có thể bằng không).  
   * @tham_số ngayKhoiTao Ngày khởi tạo khoản vay được lưu trong `LoanTerms`.  
   * @tham_số ngayDaoHanTiepTheo Ngày đáo hạn thanh toán tiếp theo ban đầu (0 giữ nguyên).  
   * @tham_số ngayDaoHan Ngày đáo hạn khoản vay (0 giữ nguyên).  
   * @tham_số laiSuat Lãi suất hàng năm tính bằng điểm cơ bản.  
   * @tham_số thanhToanHangThangDuKien Thanh toán hàng tháng dự kiến (đơn vị cơ sở tiền tệ).  
   * @tham_số dấuThoiGian Dấu thời gian giải ngân ngoài chuỗi được ghi lại trên các mục.  
   * @tham_số thamChieu Tham chiếu bên ngoài do người gọi cung cấp.  
   * @trả_về chỉSốMục Id mục được đóng gói của mục giải ngân cho người vay.  
   */  
  /**  
   * @notice Disburse funded capital to the borrower and lock in the loan's write-once terms.  
   * @dev Caller must be the loan's originator or admin/guardian. Loan must be `FullyFunded`.  
   *      `netDisbursedAmount + originationFee` must equal the outstanding commitment.  
   *      Withholds `originationFee` to `ACC_ORIGINATOR_FEE_PAYABLE`, transfers `netDisbursedAmount`  
   *      to the borrower, and transitions the loan to `Active`.  
   * @param loanId The loan identifier.  
   * @param netDisbursedAmount Amount sent to the borrower (net of origination fee).  
   * @param originationFee Fee withheld for the originator (may be zero).  
   * @param originationDate Loan origination date stored in `LoanTerms`.  
   * @param nextDueDate Initial next payment due date (0 leaves unchanged).  
   * @param maturityDate Loan maturity date (0 leaves unchanged).  
   * @param interestRate Annual interest rate in basis points.  
   * @param expectedMonthlyPayment Expected monthly payment (currency base units).  
   * @param timestamp The off-chain disbursement timestamp recorded on the entries.  
   * @param ref Caller-supplied external reference.  
   * @return entryIndex The packed entry id of the borrower disbursement entry.  
   */  
  // hàm giaiNgan(  
  //   uint64 maKhoảnVay,  
  //   int128 sốTienGiaiNganThuan,  
  //   int128 phiKhoiTao,  
  //   uint48 ngayKhoiTao,  
  //   uint48 ngayDaoHanTiepTheo,  
  //   uint48 ngayDaoHan,  
  //   uint32 laiSuat,  
  //   int128 thanhToanHangThangDuKien,  
  //   uint48 dấuThoiGian,  
  //   bytes32 thamChieu  
  // ) ngoại_vi trả_về (uint128 chỉSốMục);  
  function disburse(  
    uint64 loanId,  
    int128 netDisbursedAmount,  
    int128 originationFee,  
    uint48 originationDate,  
    uint48 nextDueDate,  
    uint48 maturityDate,  
    uint32 interestRate,  
    int128 expectedMonthlyPayment,  
    uint48 timestamp,  
    bytes32 ref  
  ) external returns (uint128 entryIndex);


  /**  
   * @thông_báo Ghi lại một khoản tích lũy lãi/phí đối với người vay. Chỉ dành cho người dịch vụ hoặc quản trị viên.  
   * @dev Ghi lại `ENTRY_INTEREST_ACCRUAL` chuyển `sốTiền` từ  
   *      `ACC_UNALLOCATED_BORROWER_INTEREST_PAYABLE` đến `ACC_BORROWER_INTEREST_RECEIVABLE`.  
   *      Việc phân chia giữa phí người dịch vụ và lãi nhà đầu tư xảy ra sau trong `apDungWaterfall`.  
   * @tham_số maKhoảnVay Định danh khoản vay.  
   * @tham_số sốTiền Tổng nghĩa vụ để tích lũy (lãi + phí kết hợp).  
   * @tham_số dấuThoiGian Dấu thời gian tích lũy ngoài chuỗi được ghi lại trên mục.  
   * @tham_số thamChieu Tham chiếu bên ngoài do người gọi cung cấp.  
   */  
  /**  
   * @notice Record an interest/fee accrual against the borrower. Servicer or admin only.  
   * @dev Records `ENTRY_INTEREST_ACCRUAL` transferring `amount` from  
   *      `ACC_UNALLOCATED_BORROWER_INTEREST_PAYABLE` to `ACC_BORROWER_INTEREST_RECEIVABLE`.  
   *      The split between servicer fees and investor interest happens later in `applyWaterfall`.  
   * @param loanId The loan identifier.  
   * @param amount The total obligation to accrue (interest + fees combined).  
   * @param timestamp The off-chain accrual timestamp recorded on the entry.  
   * @param ref Caller-supplied external reference.  
   */  
  // hàm tichLuy(uint64 maKhoảnVay, int128 sốTiền, uint48 dấuThoiGian, bytes32 thamChieu) ngoại_vi;  
  function accrue(uint64 loanId, int128 amount, uint48 timestamp, bytes32 ref) external;  
  
  /**  
   * @thông_báo Ghi lại một khoản thanh toán của người vay bằng cách rút tiền tệ từ địa chỉ người vay đã đăng ký.  
   * @dev Người gọi phải là người vay đã đăng ký hoặc quản trị viên. Khoản vay phải ở trạng thái `Đang_Hoạt_Động` hoặc `Đã_Xóa_Nợ`.  
   * @tham_số maKhoảnVay Định danh khoản vay.  
   * @tham_số sốTiền Số tiền thanh toán.  
   * @tham_số dấuThoiGian Dấu thời gian thanh toán ngoài chuỗi được ghi lại trên mục.  
   * @tham_số thamChieu Tham chiếu bên ngoài do người gọi cung cấp.  
   * @trả_về chỉSốMục Id mục được đóng gói của khoản thanh toán.  
   */  
  /**  
   * @notice Record a borrower payment by pulling currency from the registered borrower address.  
   * @dev Caller must be the registered borrower or admin. Loan must be `Active` or `ChargedOff`.  
   * @param loanId The loan identifier.  
   * @param amount The payment amount.  
   * @param timestamp The off-chain payment timestamp recorded on the entry.  
   * @param ref Caller-supplied external reference.  
   * @return entryIndex The packed entry id of the payment.  
   */  
  // hàm thanhToan(uint64 maKhoảnVay, int128 sốTiền, uint48 dấuThoiGian, bytes32 thamChieu) ngoại_vi trả_về (uint128 chỉSốMục);  
  function pay(uint64 loanId, int128 amount, uint48 timestamp, bytes32 ref) external returns (uint128 entryIndex);  
  
  /**  
   * @thông_báo Tính một khoản phí linh tinh đối với người vay. Chỉ dành cho người dịch vụ hoặc quản trị viên.  
   * @dev Ghi lại `ENTRY_MISC_FEE_CHARGE` chuyển `sốTiền` từ  
   *      `ACC_SERVICER_MISC_FEE_PAYABLE` đến `ACC_BORROWER_MISC_FEE_RECEIVABLE`.  
   * @tham_số maKhoảnVay Định danh khoản vay.  
   * @tham_số sốTiền Số tiền phí (phải dương).  
   * @tham_số dấuThoiGian Dấu thời gian tính phí ngoài chuỗi được ghi lại trên mục.  
   * @tham_số thamChieu Tham chiếu bên ngoài do người gọi cung cấp.  
   */  
  /**  
   * @notice Charge a miscellaneous fee against the borrower. Servicer or admin only.  
   * @dev Records `ENTRY_MISC_FEE_CHARGE` transferring `amount` from  
   *      `ACC_SERVICER_MISC_FEE_PAYABLE` to `ACC_BORROWER_MISC_FEE_RECEIVABLE`.  
   * @param loanId The loan identifier.  
   * @param amount The fee amount (must be positive).  
   * @param timestamp The off-chain charge timestamp recorded on the entry.  
   * @param ref Caller-supplied external reference.  
   */  
  // hàm tinhPhiLinhTinh(uint64 maKhoảnVay, int128 sốTiền, uint48 dấuThoiGian, bytes32 thamChieu) ngoại_vi;  
  function chargeMiscFee(uint64 loanId, int128 amount, uint48 timestamp, bytes32 ref) external;  
  
  /**  
   * @thông_báo Phân bổ một khoản thanh toán của người vay cho các phí linh tinh, phí dịch vụ, lãi nhà đầu tư, và vốn gốc.  
   * @dev Chỉ dành cho người dịch vụ hoặc quản trị viên. Khoản vay phải ở trạng thái `Đang_Hoạt_Động`, `Đã_Xóa_Nợ`, hoặc `Đã_Thanh_Toán_Đầy_Đủ`.  
   *      Tạo ra một chuỗi các mục thanh toán bù trừ từ `ACC_BORROWER_PAYMENT_CLEARING` tỷ lệ với  
   *      mỗi khoản phân bổ dương.  
   * @tham_số maKhoảnVay Định danh khoản vay.  
   * @tham_số phiLinhTinh Số tiền phân bổ cho các phí linh tinh còn lại.  
   * @tham_số phiDichVu Số tiền phân bổ cho các phí dịch vụ.  
   * @tham_số laiNhaDauTu Số tiền phân bổ cho lãi nhà đầu tư.  
   * @tham_số vonGoc Số tiền phân bổ cho vốn gốc.  
   * @tham_số ngayDaoHanTiepTheo Ngày đáo hạn thanh toán tiếp theo mới tùy chọn (0 giữ nguyên).  
   * @tham_số dấuThoiGian Dấu thời gian phân bổ ngoài chuỗi được ghi lại trên mỗi mục.  
   * @tham_số thamChieu Tham chiếu bên ngoài do người gọi cung cấp.  
   */  
  /**  
   * @notice Allocate a borrower payment across misc fees, servicer fees, investor interest, and principal.  
   * @dev Servicer or admin only. Loan must be `Active`, `ChargedOff`, or `FullyPaid`.  
   *      Generates a sequence of clearance entries from `ACC_BORROWER_PAYMENT_CLEARING` proportional to  
   *      each positive allocation.  
   * @param loanId The loan identifier.  
   * @param miscFees Amount allocated to outstanding misc fees.  
   * @param servicingFees Amount allocated to servicing fees.  
   * @param investorInterest Amount allocated to investor interest.  
   * @param principal Amount allocated to principal.  
   * @param nextDueDate Optional new next payment due date (0 leaves unchanged).  
   * @param timestamp The off-chain allocation timestamp recorded on each entry.  
   * @param ref Caller-supplied external reference.  
   */  
  // hàm apDungWaterfall(  
  //   uint64 maKhoảnVay,  
  //   int128 phiLinhTinh,  
  //   int128 phiDichVu,  
  //   int128 laiNhaDauTu,  
  //   int128 vonGoc,  
  //   uint48 ngayDaoHanTiepTheo,  
  //   uint48 dấuThoiGian,  
  //   bytes32 thamChieu  
  // ) ngoại_vi;  
  function applyWaterfall(  
    uint64 loanId,  
    int128 miscFees,  
    int128 servicingFees,  
    int128 investorInterest,  
    int128 principal,  
    uint48 nextDueDate,  
    uint48 timestamp,  
    bytes32 ref  
  ) external;  
  
  /**  
   * @thông_báo Rút tất cả tiền mặt vốn gốc và lãi có sẵn cho một lô khoản vay.  
   * @dev Tất cả các khoản vay trong lô phải có cùng nhà đầu tư (chủ sở hữu NFT) và cùng  
   *      trạng thái khóa. Nếu các NFT được mở khóa, người gọi phải là nhà đầu tư hoặc quản trị viên/người giám hộ  
   *      và tiền được gửi cho nhà đầu tư. Nếu các NFT bị khóa, người gọi phải là  
   *      người mở khóa chung và tiền được gửi cho người gọi.  
   * @tham_số maCacKhoảnVay Các id khoản vay để rút từ.  
   * @tham_số dấuThoiGian Dấu thời gian ngoài chuỗi được ghi lại trên mỗi mục rút tiền.  
   * @tham_số thamChieu Tham chiếu bên ngoài do người gọi cung cấp.  
   * @trả_về Phân tích theo từng khoản vay của số tiền vốn gốc và lãi đã rút.  
   */  
  /**  
   * @notice Withdraw all available principal and interest cash for a batch of loans.  
   * @dev All loans in the batch must share the same investor (NFT owner) and the same  
   *      lock state. If the NFTs are unlocked, caller must be the investor or admin/guardian  
   *      and funds are sent to the investor. If the NFTs are locked, caller must be the  
   *      shared unlocker and funds are sent to the caller.  
   * @param loanIds The loan ids to withdraw from.  
   * @param timestamp The off-chain timestamp recorded on each withdrawal entry.  
   * @param ref Caller-supplied external reference.  
   * @return Per-loan breakdown of the principal and interest amounts withdrawn.  
   */


  // hàm rutTienNhaDauTu(  
  //   uint64[] calldata maCacKhoảnVay,  
  //   uint48 dấuThoiGian,  
  //   bytes32 thamChieu  
  // ) ngoại_vi trả_về (KetQuaRutTienNhaDauTu[] memory);  
  function investorWithdraw(  
    uint64[] calldata loanIds,  
    uint48 timestamp,  
    bytes32 ref  
  ) external returns (InvestorWithdrawalResult[] memory);  
  
  /**  
   * @thông_báo Rút tất cả tiền mặt nợ người dịch vụ (phí dịch vụ và phí linh tinh) cho một lô khoản vay.  
   * @dev Cho mỗi khoản vay: người gọi phải là người dịch vụ đã đăng ký hoặc quản trị viên.  
   * @tham_số maCacKhoảnVay Các id khoản vay để rút từ.  
   * @tham_số dấuThoiGian Dấu thời gian ngoài chuỗi được ghi lại trên mỗi mục rút tiền.  
   * @tham_số thamChieu Tham chiếu bên ngoài do người gọi cung cấp.  
   * @trả_về Phân tích theo từng khoản vay của các số tiền đã rút.  
   */  
  /**  
   * @notice Withdraw all servicer-owed cash (servicing fees and misc fees) for a batch of loans.  
   * @dev For each loan: caller must be the registered servicer or admin.  
   * @param loanIds The loan ids to withdraw from.  
   * @param timestamp The off-chain timestamp recorded on each withdrawal entry.  
   * @param ref Caller-supplied external reference.  
   * @return Per-loan breakdown of the amounts withdrawn.  
   */  
  // hàm rutTienNguoiDichVu(  
  //   uint64[] calldata maCacKhoảnVay,  
  //   uint48 dấuThoiGian,  
  //   bytes32 thamChieu  
  // ) ngoại_vi trả_về (KetQuaRutTienNguoiDichVu[] memory);  
  function servicerWithdraw(  
    uint64[] calldata loanIds,  
    uint48 timestamp,  
    bytes32 ref  
  ) external returns (ServicerWithdrawalResult[] memory);  
  
  /**  
   * @thông_báo Trả lại tiền đã được thanh toán trước đó cho một tài khoản đã trả người dịch vụ về `ACC_CASH`.  
   * @dev Chỉ dành cho người dịch vụ hoặc quản trị viên. Khoản vay phải ở trạng thái `Đang_Hoạt_Động`, `Đã_Xóa_Nợ`, hoặc `Đã_Thanh_Toán_Đầy_Đủ`.  
   *      Rút tiền tệ từ người dịch vụ đã đăng ký và ghi có vào tài khoản `từ` được cung cấp.  
   * @tham_số maKhoảnVay Định danh khoản vay.  
   * @tham_số từ Tài khoản đã trả người dịch vụ đang được đảo ngược.  
   * @tham_số sốTiền Số tiền đang được trả lại (phải dương).  
   * @tham_số dấuThoiGian Dấu thời gian ngoài chuỗi được ghi lại trên mục.  
   * @tham_số loạiMục Thẻ loại mục do người gọi cung cấp cho việc sửa chữa.  
   * @tham_số thamChieu Tham chiếu bên ngoài do người gọi cung cấp.  
   * @trả_về chỉSốMục Id mục được đóng gói của khoản trả lại.  
   */  
  /**  
   * @notice Return funds previously paid out to a servicer-paid account back to `ACC_CASH`.  
   * @dev Servicer or admin only. Loan must be `Active`, `ChargedOff`, or `FullyPaid`.  
   *      Pulls currency from the registered servicer and credits the supplied `from` account.  
   * @param loanId The loan identifier.  
   * @param from The servicer-paid account being reversed.  
   * @param amount The amount being returned (must be positive).  
   * @param timestamp The off-chain timestamp recorded on the entry.  
   * @param entryType Caller-supplied entry type tag for the correction.  
   * @param ref Caller-supplied external reference.  
   * @return entryIndex The packed entry id of the return.  
   */  
  // hàm traTienLai(  
  //   uint64 maKhoảnVay,  
  //   uint8 từ,  
  //   int128 sốTiền,  
  //   uint48 dấuThoiGian,  
  //   uint16 loạiMục,  
  //   bytes32 thamChieu  
  // ) ngoại_vi trả_về (uint128 chỉSốMục);  
  function returnFunds(  
    uint64 loanId,  
    uint8 from,  
    int128 amount,  
    uint48 timestamp,  
    uint16 entryType,  
    bytes32 ref  
  ) external returns (uint128 entryIndex);  
  
  /**  
   * @thông_báo Rút tất cả tiền mặt nợ người khởi tạo cho một lô khoản vay.  
   * @dev Cho mỗi khoản vay: người gọi phải là người khởi tạo đã đăng ký hoặc quản trị viên.  
   * @tham_số maCacKhoảnVay Các id khoản vay để rút từ.  
   * @tham_số dấuThoiGian Dấu thời gian ngoài chuỗi được ghi lại trên mỗi mục rút tiền.  
   * @tham_số thamChieu Tham chiếu bên ngoài do người gọi cung cấp.  
   * @trả_về Phân tích theo từng khoản vay của các số tiền đã rút.  
   */  
  /**  
   * @notice Withdraw all originator-owed cash for a batch of loans.  
   * @dev For each loan: caller must be the registered originator or admin.  
   * @param loanIds The loan ids to withdraw from.  
   * @param timestamp The off-chain timestamp recorded on each withdrawal entry.  
   * @param ref Caller-supplied external reference.  
   * @return Per-loan breakdown of the amounts withdrawn.  
   */  
  // hàm rutTienNguoiKhoiTao(  
  //   uint64[] calldata maCacKhoảnVay,  
  //   uint48 dấuThoiGian,  
  //   bytes32 thamChieu  
  // ) ngoại_vi trả_về (KetQuaRutTienNguoiKhoiTao[] memory);  
  function originatorWithdraw(  
    uint64[] calldata loanIds,  
    uint48 timestamp,  
    bytes32 ref  
  ) external returns (OriginatorWithdrawalResult[] memory);  
  
  /**  
   * @thông_báo Cập nhật địa chỉ người vay đã đăng ký cho `maKhoảnVay`.  
   * @dev Chỉ dành cho người dịch vụ hoặc quản trị viên. Người vay mới phải được đăng ký trong sổ địa chỉ của người dịch vụ.  
   *      Khoản vay không được ở trạng thái kết thúc.  
   * @tham_số maKhoảnVay Định danh khoản vay.  
   * @tham_số nguoiVay Địa chỉ người vay mới.  
   */  
  /**  
   * @notice Update the registered borrower address for `loanId`.  
   * @dev Servicer or admin only. The new borrower must be registered in the servicer's address book.  
   *      Loan must not be in a terminal status.  
   * @param loanId The loan identifier.  
   * @param borrower The new borrower address.  
   */


  // hàm capNhatNguoiVay(uint64 maKhoảnVay, address nguoiVay) ngoại_vi;  
  function updateBorrower(uint64 loanId, address borrower) external;  
  
  /**  
   * @thông_báo Cập nhật địa chỉ người dịch vụ đã đăng ký cho `maKhoảnVay`. Chỉ dành cho người giám hộ.  
   * @dev Người dịch vụ mới phải là người dịch vụ Tare được phê duyệt. Khoản vay không được ở trạng thái kết thúc.  
   * @tham_số maKhoảnVay Định danh khoản vay.  
   * @tham_số nguoiDichVu Địa chỉ người dịch vụ mới.  
   */  
  /**  
   * @notice Update the registered servicer address for `loanId`. Guardian only.  
   * @dev The new servicer must be an approved Tare servicer. Loan must not be in a terminal status.  
   * @param loanId The loan identifier.  
   * @param servicer The new servicer address.  
   */  
  // hàm capNhatNguoiDichVu(uint64 maKhoảnVay, address nguoiDichVu) ngoại_vi;  
  function updateServicer(uint64 loanId, address servicer) external;  
  
  /**  
   * @thông_báo Cập nhật các trường dữ liệu khoản vay có thể thay đổi. Chỉ dành cho người dịch vụ hoặc quản trị viên.  
   * @dev `KhongTonTai` cho `trangThai` và `0` cho các trường ngày là các giá trị canh gác có nghĩa là "không thay đổi".  
   * @tham_số maKhoảnVay Định danh khoản vay.  
   * @tham_số trangThai Trạng thái khoản vay mới (`KhongTonTai` = không thay đổi).  
   * @tham_số ngayDaoHanTiepTheo Ngày đáo hạn thanh toán tiếp theo (0 = không thay đổi).  
   * @tham_số ngayDaoHan Ngày đáo hạn (0 = không thay đổi).  
   * @tham_số dấuThoiGian Dấu thời gian ngoài chuỗi được ghi lại trên bản cập nhật.  
   */  
  /**  
   * @notice Update mutable loan data fields. Servicer or admin only.  
   * @dev `DoesNotExist` for `status` and `0` for date fields are sentinels meaning "no change".  
   * @param loanId The loan identifier.  
   * @param status The new loan status (`DoesNotExist` = no change).  
   * @param nextDueDate The next payment due date (0 = no change).  
   * @param maturityDate The maturity date (0 = no change).  
   * @param timestamp The off-chain timestamp recorded on the update.  
   */  
  // hàm capNhatDuLieuKhoảnVay(  
  //   uint64 maKhoảnVay,  
  //   TrangThaiKhoảnVay trangThai,  
  //   uint48 ngayDaoHanTiepTheo,  
  //   uint48 ngayDaoHan,  
  //   uint48 dấuThoiGian  
  // ) ngoại_vi;  
  function updateLoanData(  
    uint64 loanId,  
    LoanStatus status,  
    uint48 nextDueDate,  
    uint48 maturityDate,  
    uint48 timestamp  
  ) external;  
  
  /**  
   * @thông_báo Cập nhật các điều khoản khoản vay được đặt trong quá trình `giaiNgan`. Chỉ dành cho người dịch vụ hoặc quản trị viên.  
   * @dev Khoản vay không được ở trạng thái kết thúc. `0` cho bất kỳ trường nào là giá trị canh gác có nghĩa là "không thay đổi",  
   *      vì vậy `thanhToanHangThangDuKien` không thể được đặt thành chính xác `0` qua hàm này.  
   *      Phát ra `LoanTermsSet` với các giá trị được lưu trữ kết quả.  
   * @tham_số maKhoảnVay Định danh khoản vay.  
   * @tham_số ngayKhoiTao Ngày khởi tạo (0 = không thay đổi).  
   * @tham_số laiSuat Lãi suất hàng năm tính bằng điểm cơ bản (0 = không thay đổi).  
   * @tham_số thanhToanHangThangDuKien Thanh toán hàng tháng dự kiến tính bằng đơn vị cơ sở tiền tệ (0 = không thay đổi).  
   */  
  /**  
   * @notice Update the loan terms set during `disburse`. Servicer or admin only.  
   * @dev Loan must not be in a terminal status. `0` for any field is a sentinel meaning "no change",  
   *      so `expectedMonthlyPayment` cannot be set to exactly `0` through this function.  
   *      Emits `LoanTermsSet` with the resulting stored values.  
   * @param loanId The loan identifier.  
   * @param originationDate The origination date (0 = no change).  
   * @param interestRate Annual interest rate in basis points (0 = no change).  
   * @param expectedMonthlyPayment Expected monthly payment in currency base units (0 = no change).  
   */  
  // hàm capNhatDieuKhoanKhoảnVay(  
  //   uint64 maKhoảnVay,  
  //   uint48 ngayKhoiTao,  
  //   uint32 laiSuat,  
  //   int128 thanhToanHangThangDuKien  
  // ) ngoại_vi;  
  function updateLoanTerms(  
    uint64 loanId,  
    uint48 originationDate,  
    uint32 interestRate,  
    int128 expectedMonthlyPayment  
  ) external;  
  
  /**  
   * @thông_báo Ghi lại một hoặc nhiều mục sổ cái thô đối với `maKhoảnVay`. Chỉ dành cho người dịch vụ hoặc Quản trị viên/Người giám hộ.  
   * @dev Cửa thoát hiểm cho các sửa chữa thủ công. Mỗi mục được xác thực theo các quy tắc tài khoản tiêu chuẩn  
   *      nhưng bỏ qua các ràng buộc vòng đời cấp cao hơn.  
   * @tham_số maKhoảnVay Định danh khoản vay.  
   * @tham_số dấuThoiGian Dấu thời gian ngoài chuỗi được ghi lại trên mỗi mục trong lô.  
   * @tham_số cacMucSoCai Các mục thô để ghi.  
   * @trả_về cacChiSoMuc Các id mục được đóng gói theo thứ tự lô.  
   */  
  /**  
   * @notice Record one or more raw ledger entries against `loanId`. Servicer or Admin/Guardian only.  
   * @dev Escape hatch for manual corrections. Each entry is validated against the standard  
   *      account rules but bypasses higher-level lifecycle constraints.  
   * @param loanId The loan identifier.  
   * @param timestamp The off-chain timestamp recorded on every entry in the batch.  
   * @param ledgerEntries The raw entries to write.  
   * @return entryIndices The packed entry ids in batch order.  
   */  
  // hàm taoMucSoCai(  
  //   uint64 maKhoảnVay,  
  //   uint48 dấuThoiGian,  
  //   DauVaoMucSoCai[] calldata cacMucSoCai  
  // ) ngoại_vi trả_về (uint128[] memory cacChiSoMuc);  
  function createLedgerEntries(  
    uint64 loanId,  
    uint48 timestamp,  
    LedgerEntryInput[] calldata ledgerEntries  
  ) external returns (uint128[] memory entryIndices);

  /**  
   * @thông_báo Hoàn tiền cho người vay từ tiền mặt được giữ bởi khoản vay và ghi có vào một tài khoản đã trả người vay.  
   * @dev Chỉ dành cho người dịch vụ hoặc quản trị viên. Khoản vay phải ở trạng thái `Đang_Hoạt_Động`, `Đã_Xóa_Nợ`, hoặc `Đã_Thanh_Toán_Đầy_Đủ`.  
   *      Chuyển `sốTiền` tiền tệ cho người vay đã đăng ký.  
   * @tham_số maKhoảnVay Định danh khoản vay.  
   * @tham_số taiKhoanDen Tài khoản sổ cái đã trả người vay đang được đảo ngược.  
   * @tham_số sốTiền Số tiền hoàn trả (phải dương).  
   * @tham_số dấuThoiGian Dấu thời gian ngoài chuỗi được ghi lại trên mục.  
   * @tham_số loạiMục Thẻ loại mục do người gọi cung cấp cho việc sửa chữa.  
   * @tham_số thamChieu Tham chiếu bên ngoài do người gọi cung cấp.  
   * @trả_về chỉSốMục Id mục được đóng gói của khoản hoàn trả.  
   */  
  /**  
   * @notice Refund the borrower from cash held by the loan and credit a borrower-paid account.  
   * @dev Servicer or admin only. Loan must be `Active`, `ChargedOff`, or `FullyPaid`.  
   *      Transfers `amount` of currency to the registered borrower.  
   * @param loanId The loan identifier.  
   * @param toAccount The borrower-paid ledger account being reversed.  
   * @param amount The refund amount (must be positive).  
   * @param timestamp The off-chain timestamp recorded on the entry.  
   * @param entryType Caller-supplied entry type tag for the correction.  
   * @param ref Caller-supplied external reference.  
   * @return entryIndex The packed entry id of the refund.  
   */  
  // hàm hoanTienNguoiVay(  
  //   uint64 maKhoảnVay,  
  //   uint8 taiKhoanDen,  
  //   int128 sốTiền,  
  //   uint48 dấuThoiGian,  
  //   uint16 loạiMục,  
  //   bytes32 thamChieu  
  // ) ngoại_vi trả_về (uint128 chỉSốMục);  
  function refundBorrower(  
    uint64 loanId,  
    uint8 toAccount,  
    int128 amount,  
    uint48 timestamp,  
    uint16 entryType,  
    bytes32 ref  
  ) external returns (uint128 entryIndex);  
  
  /**  
   * @thông_báo Trả về số dư có dấu thô của `taiKhoan` cho `maKhoảnVay`.  
   * @tham_số maKhoảnVay Định danh khoản vay.  
   * @tham_số taiKhoan Giá trị enum `TaiKhoan` được ép kiểu thành `uint8`.  
   */  
  /**  
   * @notice Returns the raw signed balance of `account` for `loanId`.  
   * @param loanId The loan identifier.  
   * @param account The `Account` enum value cast to `uint8`.  
   */  
  // hàm laySoDuTaiKhoanKhoảnVay(uint64 maKhoảnVay, uint8 taiKhoan) ngoại_vi xem trả_về (int128);  
  function getLoanAccountBalance(uint64 loanId, uint8 account) external view returns (int128);  
  
  /**  
   * @thông_báo Trả về số dư của `taiKhoan` cho `maKhoảnVay` được chuẩn hóa sao cho tất cả số dư đều không âm.  
   * @dev Các tài khoản Nợ_Phải_Trả/Doanh_Thu được đảo dấu so với `laySoDuTaiKhoanKhoảnVay`.  
   * @tham_số maKhoảnVay Định danh khoản vay.  
   * @tham_số taiKhoan Giá trị enum `TaiKhoan` được ép kiểu thành `uint8`.  
   */  
  /**  
   * @notice Returns the balance of `account` for `loanId` normalized so all balances are non-negative.  
   * @dev Liability/Revenue accounts are sign-flipped relative to `getLoanAccountBalance`.  
   * @param loanId The loan identifier.  
   * @param account The `Account` enum value cast to `uint8`.  
   */  
  // hàm laySoDuTaiKhoanKhoảnVayChuanHoa(uint64 maKhoảnVay, uint8 taiKhoan) ngoại_vi xem trả_về (int128);  
  function getLoanAccountBalanceNormalized(uint64 loanId, uint8 account) external view returns (int128);  
  
  /**  
   * @thông_báo Trả về mục được lưu trữ tại vị trí `sốMuc` cho `maKhoảnVay`.  
   * @tham_số maKhoảnVay Định danh khoản vay.  
   * @tham_số sốMuc Chỉ số mục theo từng khoản vay (bắt đầu từ 0).  
   */  
  /**  
   * @notice Returns the entry stored at position `entryNumber` for `loanId`.  
   * @param loanId The loan identifier.  
   * @param entryNumber The per-loan entry index (0-based).  
   */  
  // hàm layMucKhoảnVay(uint64 maKhoảnVay, uint64 sốMuc) ngoại_vi xem trả_về (Muc memory);  
  function getLoanEntry(uint64 loanId, uint64 entryNumber) external view returns (Entry memory);  
  
  /**  
   * @thông_báo Trả về một phạm vi các mục cho `maKhoảnVay`.  
   * @tham_số maKhoảnVay Định danh khoản vay.  
   * @tham_số chiSoBatDau Điểm bắt đầu bao gồm của phạm vi chỉ số mục theo từng khoản vay.  
   * @tham_số chiSoKetThuc Điểm kết thúc không bao gồm của phạm vi chỉ số mục theo từng khoản vay.  
   */  
  /**  
   * @notice Returns a range of entries for `loanId`.  
   * @param loanId The loan identifier.  
   * @param startIndex Inclusive start of the per-loan entry index range.  
   * @param endIndex Exclusive end of the per-loan entry index range.  
   */  
  // hàm layCacMucKhoảnVay(uint64 maKhoảnVay, uint64 chiSoBatDau, uint64 chiSoKetThuc) ngoại_vi xem trả_về (Muc[] memory);  
  function getLoanEntries(uint64 loanId, uint64 startIndex, uint64 endIndex) external view returns (Entry[] memory);  
  
  /**  
   * @thông_báo Trả về dữ liệu định giá tổng hợp cho một lô khoản vay.  
   * @tham_số maCacKhoảnVay Các id khoản vay để tra cứu. Các mục cho các khoản vay không tồn tại được trả về bằng không.  
   */  
  /**  
   * @notice Returns aggregated valuation data for a batch of loans.  
   * @param loanIds The loan ids to look up. Entries for non-existent loans are returned zeroed.  
   */  
  // hàm layGiaTriKhoảnVay(uint64[] calldata maCacKhoảnVay) ngoại_vi xem trả_về (GiaTriKhoảnVay[] memory);  
  function getLoanValues(uint64[] calldata loanIds) external view returns (LoanValue[] memory);
  
}
