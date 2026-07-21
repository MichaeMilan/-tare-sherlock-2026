// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {LoansAuth} from "./misc/LoansAuth.sol";
import {Entry} from "contracts/interfaces/ILoans.sol";
import {ILoans} from "contracts/interfaces/ILoans.sol";
import {
  ACC_CASH,
  ACC_INVESTOR_INTEREST_PAYABLE,
  ACC_INVESTOR_INTEREST_PAID,
  ACC_BORROWER_PRINCIPAL_REPAID,
  ACC_INVESTOR_PRINCIPAL_REPAID
} from "contracts/interfaces/Accounts.sol";

/**  
 * @title LoansLedger  
 * Tiêu_đề LoansLedger  
 * @notice Ledger storage and read helpers for the `Loans` contract.  
 * @notice Lưu_trữ sổ_cái và các hàm_trợ_giúp đọc cho hợp_đồng `Loans`.  
 * @dev Holds per-loan account balances and entries, exposes them via the  
 * @dev Lưu_giữ số_dư tài_khoản và các mục theo từng khoản_vay, hiển_thị chúng qua  
 *      `ILoans` view functions, and provides internal primitives (`_deposit`,  
 *      các hàm xem `ILoans`, và cung_cấp các nguyên_thủy nội_bộ (`_nạpTiền`,  
 *      `_withdraw`, `_createInternalEntry`) used by the concrete `Loans`  
 *      `_rút`, `_tạoMụcNộiBộ`) được dùng bởi các hàm vòng_đời `Loans` cụ_thể  
 *      lifecycle functions to mutate the ledger.  
 *      để thay_đổi sổ_cái.  
 */  
// hợp_đồng_trừu_tượng LoansLedger là ILoans, LoansAuth {  
abstract contract LoansLedger is ILoans, LoansAuth {  
  // sử_dụng SafeERC20 cho IERC20;  
  using SafeERC20 for IERC20;  
  
  /// @inheritdoc ILoans  
  // Kế_thừa từ ILoans  
  // số_nguyên_không_dấu_64 public số_lượng_khoản_vay;  
  uint64 public loanCount;  
  
  /// @inheritdoc ILoans  
  // Kế_thừa từ ILoans  
  // IERC20 public immutable tiền_tệ;  
  IERC20 public immutable currency;  
  
  /// @inheritdoc ILoans  
  // Kế_thừa từ ILoans  
  // mapping(số_nguyên_không_dấu_72 khóa => số_nguyên_128 số_dư) public số_dư_tài_khoản_s;  
  mapping(uint72 key => int128 balance) public accountBalances;  
  
  /// @inheritdoc ILoans  
  // Kế_thừa từ ILoans  
  // mapping(số_nguyên_không_dấu_128 chỉSốMục => Mục mục) public mục_s;  
  mapping(uint128 entryIndex => Entry entry) public entries;  
  
  /// @inheritdoc ILoans  
  // Kế_thừa từ ILoans  
  // mapping(số_nguyên_không_dấu_64 mã_khoản_vay => số_nguyên_không_dấu_64 số_lượng) public số_lượng_mục_s;  
  mapping(uint64 loanId => uint64 count) public entryCount;  
  
  // modifier khoảnVayTồnTại(số_nguyên_không_dấu_64 mã_khoản_vay) {  
  modifier loanExists(uint64 loanId) {  
    // _khoảnVayTồnTại(mã_khoản_vay);  
    _loanExists(loanId);  
    // _;  
    _;  
  // }  
  }  
  
  // constructor(IERC20 _tiền_tệ, địa_chỉ người_giám_hộ_ban_đầu) LoansAuth(người_giám_hộ_ban_đầu) {  
  constructor(IERC20 _currency, address initialGuardian) LoansAuth(initialGuardian) {  
    // yêu_cầu(địa_chỉ(_tiền_tệ) != địa_chỉ(0), ĐịaChỉKhông());  
    require(address(_currency) != address(0), ZeroAddress());  
    // tiền_tệ = _tiền_tệ;  
    currency = _currency;  
  // }  
  }  
  
  /// @inheritdoc ILoans  
  // Kế_thừa từ ILoans  
  // hàm lấySốDưTàiKhoảnKhoảnVay(số_nguyên_không_dấu_64 mã_khoản_vay, số_nguyên_không_dấu_8 tài_khoản) bên_ngoài xem khoảnVayTồnTại(mã_khoản_vay) trả_về (số_nguyên_128) {  
  function getLoanAccountBalance(uint64 loanId, uint8 account) external view loanExists(loanId) returns (int128) {  
    // trả_về _lấySốDưTàiKhoản(mã_khoản_vay, tài_khoản);  
    return _getAccountBalance(loanId, account);  
  // }  
  }  
  
  /// @inheritdoc ILoans  
  // Kế_thừa từ ILoans  
  // hàm lấySốDưTàiKhoảnKhoảnVayĐãChuẩnHóa(  
  function getLoanAccountBalanceNormalized(  
    // số_nguyên_không_dấu_64 mã_khoản_vay,  
    uint64 loanId,  
    // số_nguyên_không_dấu_8 tài_khoản  
    uint8 account  
  // ) bên_ngoài xem khoảnVayTồnTại(mã_khoản_vay) trả_về (số_nguyên_128) {  
  ) external view loanExists(loanId) returns (int128) {  
    // số_nguyên_128 số_dư = _lấySốDưTàiKhoản(mã_khoản_vay, tài_khoản);  
    int128 balance = _getAccountBalance(loanId, account);  
    // trả_về _làThườngÂm(tài_khoản) ? -số_dư : số_dư;  
    return _isNormallyNegative(account) ? -balance : balance;  
  // }  
  }  
  
  /// @inheritdoc ILoans  
  // Kế_thừa từ ILoans  
  // hàm lấyMụcKhoảnVay(số_nguyên_không_dấu_64 mã_khoản_vay, số_nguyên_không_dấu_64 sốThứTựMục) bên_ngoài xem khoảnVayTồnTại(mã_khoản_vay) trả_về (Mục bộ_nhớ) {  
  function getLoanEntry(uint64 loanId, uint64 entryNumber) external view loanExists(loanId) returns (Entry memory) {  
    // số_nguyên_không_dấu_64 số_lượng = số_lượng_mục_s[mã_khoản_vay];  
    uint64 count = entryCount[loanId];  
    // yêu_cầu(sốThứTựMục > 0 && sốThứTựMục <= số_lượng, SốTiềnKhôngHợpLệ());  
    require(entryNumber > 0 && entryNumber <= count, InvalidAmount());  
  
    // số_nguyên_không_dấu_128 chỉSốMục = (số_nguyên_không_dấu_128(mã_khoản_vay) << 64) | số_nguyên_không_dấu_128(sốThứTựMục);  
    uint128 entryIndex = (uint128(loanId) << 64) | uint128(entryNumber);  
    // trả_về mục_s[chỉSốMục];  
    return entries[entryIndex];  
  // }  
  }  
  
  /// @inheritdoc ILoans  
  // Kế_thừa từ ILoans  
  // hàm lấyCácMụcKhoảnVay(  
  function getLoanEntries(  
    // số_nguyên_không_dấu_64 mã_khoản_vay,  
    uint64 loanId,  
    // số_nguyên_không_dấu_64 chỉSốBắtĐầu,  
    uint64 startIndex,  
    // số_nguyên_không_dấu_64 chỉSốKếtThúc  
    uint64 endIndex  
  // ) bên_ngoài xem khoảnVayTồnTại(mã_khoản_vay) trả_về (Mục[] bộ_nhớ) {  
  ) external view loanExists(loanId) returns (Entry[] memory) {  
    // số_nguyên_không_dấu_64 số_lượng = số_lượng_mục_s[mã_khoản_vay];  
    uint64 count = entryCount[loanId];  
    // yêu_cầu(chỉSốBắtĐầu > 0 && chỉSốBắtĐầu <= số_lượng, SốTiềnKhôngHợpLệ());  
    require(startIndex > 0 && startIndex <= count, InvalidAmount());  
    // yêu_cầu(chỉSốKếtThúc >= chỉSốBắtĐầu && chỉSốKếtThúc <= số_lượng, SốTiềnKhôngHợpLệ());  
    require(endIndex >= startIndex && endIndex <= count, InvalidAmount());  
  
    // số_nguyên_không_dấu_64 kíchThướcPhạmVi = chỉSốKếtThúc - chỉSốBắtĐầu + 1;  
    uint64 rangeSize = endIndex - startIndex + 1;  
    // Mục[] bộ_nhớ cácMụcKhoảnVay = new Mục[](kíchThướcPhạmVi);  
    Entry[] memory loanEntries = new Entry[](rangeSize);  
    // số_nguyên_không_dấu_128 mãKhoảnVayĐãDịch = số_nguyên_không_dấu_128(mã_khoản_vay) << 64;  
    uint128 loanIdShifted = uint128(loanId) << 64;  
  
    // for (số_nguyên_không_dấu_64 i = chỉSốBắtĐầu; i <= chỉSốKếtThúc; ++i) {  
    for (uint64 i = startIndex; i <= endIndex; ++i) {  
      // số_nguyên_không_dấu_128 chỉSốMục = mãKhoảnVayĐãDịch | số_nguyên_không_dấu_128(i);  
      uint128 entryIndex = loanIdShifted | uint128(i);  
      // cácMụcKhoảnVay[i - chỉSốBắtĐầu] = mục_s[chỉSốMục];  
      loanEntries[i - startIndex] = entries[entryIndex];  
    // }  
    }  
  
    // trả_về cácMụcKhoảnVay;  
    return loanEntries;  
  // }  
  }

  /**  
   * @dev Reverts with `DoesNotExist` if `loanId` has not yet been allocated by `_create`.  
   * @dev Hoàn_tác với `KhôngTồnTại` nếu `mã_khoản_vay` chưa được phân_bổ bởi `_tạo`.  
   *      Loan ids are dense and start at `1`; `loanCount` is the highest allocated id.  
   *      Các mã khoản_vay liên_tục và bắt_đầu từ `1`; `số_lượng_khoản_vay` là mã được phân_bổ cao nhất.  
   */  
  // hàm _khoảnVayTồnTại(số_nguyên_không_dấu_64 mã_khoản_vay) nội_bộ xem {  
  function _loanExists(uint64 loanId) internal view {  
    // yêu_cầu(mã_khoản_vay != 0 && mã_khoản_vay <= số_lượng_khoản_vay, KhôngTồnTại());  
    require(loanId != 0 && loanId <= loanCount, DoesNotExist());  
  // }  
  }  
  
  /**  
   * @dev Returns the signed balance of `account` on `loanId` using the packed  
   * @dev Trả_về số_dư có_dấu của `tài_khoản` trên `mã_khoản_vay` sử_dụng khóa  
   *      `(loanId, account)` key.  
   *      `(mã_khoản_vay, tài_khoản)` đã_đóng_gói.  
   */  
  // hàm _lấySốDưTàiKhoản(số_nguyên_không_dấu_64 mã_khoản_vay, số_nguyên_không_dấu_8 tài_khoản) nội_bộ xem trả_về (số_nguyên_128) {  
  function _getAccountBalance(uint64 loanId, uint8 account) internal view returns (int128) {  
    // số_nguyên_không_dấu_72 khóa = _lấyKhóaSốDư(mã_khoản_vay, tài_khoản);  
    uint72 key = _getBalanceKey(loanId, account);  
    // trả_về số_dư_tài_khoản_s[khóa];  
    return accountBalances[key];  
  // }  
  }  
  
  /**  
   * @dev Returns the net amount still owed on a (payable, paid) account pair.  
   * @dev Trả_về số_tiền ròng còn_lại nợ trên một cặp tài_khoản (phải_trả, đã_thanh_toán).  
   *      `payableAccount` is a liability or contra-asset (normally negative) tracking  
   *      `tàiKhoảnPhảiTrả` là một khoản_nợ hoặc tài_sản_đối_ứng (thường âm) theo_dõi  
   *      the total obligation; `paidAccount` is a contra-liability (normally positive)  
   *      tổng nghĩa_vụ; `tàiKhoảnĐãThanhToán` là một khoản_nợ_đối_ứng (thường dương)  
   *      tracking what has already been paid. The returned value is positive when there  
   *      theo_dõi những gì đã được thanh_toán. Giá_trị trả_về là dương khi còn  
   *      is something left to pay out.  
   *      điều_gì đó cần chi_trả.  
   */  
  // hàm _lấyPhảiTrảRòng(số_nguyên_không_dấu_64 mã_khoản_vay, số_nguyên_không_dấu_8 tàiKhoảnPhảiTrả, số_nguyên_không_dấu_8 tàiKhoảnĐãThanhToán) nội_bộ xem trả_về (số_nguyên_128) {  
  function _getNetPayable(uint64 loanId, uint8 payableAccount, uint8 paidAccount) internal view returns (int128) {  
    // trả_về -_lấySốDưTàiKhoản(mã_khoản_vay, tàiKhoảnPhảiTrả) - _lấySốDưTàiKhoản(mã_khoản_vay, tàiKhoảnĐãThanhToán);  
    return -_getAccountBalance(loanId, payableAccount) - _getAccountBalance(loanId, paidAccount);  
  // }  
  }  
  
  /**  
   * @dev Convenience accessor for the net interest still owed to the loan's investor.  
   * @dev Hàm_truy_cập tiện_lợi cho lãi ròng còn_lại nợ nhà_đầu_tư của khoản_vay.  
   */  
  // hàm _lấyLãiRòngPhảiTrảChoNhàĐầuTư(số_nguyên_không_dấu_64 mã_khoản_vay) nội_bộ xem trả_về (số_nguyên_128) {  
  function _getNetInterestPayableToInvestor(uint64 loanId) internal view returns (int128) {  
    // trả_về _lấyPhảiTrảRòng(mã_khoản_vay, TÀI_KHOẢN_LÃI_NHÀ_ĐẦU_TƯ_PHẢI_TRẢ, TÀI_KHOẢN_LÃI_NHÀ_ĐẦU_TƯ_ĐÃ_THANH_TOÁN);  
    return _getNetPayable(loanId, ACC_INVESTOR_INTEREST_PAYABLE, ACC_INVESTOR_INTEREST_PAID);  
  // }  
  }  
  
  /**  
   * @dev Convenience accessor for the net principal currently payable to the loan's  
   * @dev Hàm_truy_cập tiện_lợi cho vốn_gốc ròng hiện_tại có_thể thanh_toán cho  
   *      investor: principal already repaid by the borrower, minus principal already  
   *      nhà_đầu_tư của khoản_vay: vốn_gốc đã được người_vay hoàn_trả, trừ vốn_gốc đã  
   *      paid out to the investor. This is bounded by borrower repayments and is not  
   *      chi_trả cho nhà_đầu_tư. Điều này bị giới_hạn bởi các khoản hoàn_trả của người_vay và không phải  
   *      the investor's full remaining principal claim.  
   *      toàn_bộ yêu_cầu vốn_gốc còn_lại của nhà_đầu_tư.  
   */  
  // hàm _lấyVốnGốcRòngPhảiTrảChoNhàĐầuTư(số_nguyên_không_dấu_64 mã_khoản_vay) nội_bộ xem trả_về (số_nguyên_128) {  
  function _getNetPrincipalPayableToInvestor(uint64 loanId) internal view returns (int128) {  
    // trả_về _lấyPhảiTrảRòng(mã_khoản_vay, TÀI_KHOẢN_VỐN_GỐC_NGƯỜI_VAY_ĐÃ_HOÀN_TRẢ, TÀI_KHOẢN_VỐN_GỐC_NHÀ_ĐẦU_TƯ_ĐÃ_HOÀN_TRẢ);  
    return _getNetPayable(loanId, ACC_BORROWER_PRINCIPAL_REPAID, ACC_INVESTOR_PRINCIPAL_REPAID);  
  // }  
  }  
  
  /**  
   * @dev Writes a Cash -> `toAccount` ledger entry for `amount` if positive and returns  
   * @dev Ghi một mục sổ_cái Tiền_mặt -> `tàiKhoảnĐến` cho `số_tiền` nếu dương và trả_về  
   *      the same `amount`, allowing the caller to accumulate a single ERC20 transfer  
   *      cùng `số_tiền` đó, cho phép người_gọi tích_lũy một tổng chuyển ERC20 duy_nhất  
   *      total across multiple loans. No entry is written when `amount` is zero.  
   *      trên nhiều khoản_vay. Không có mục nào được ghi khi `số_tiền` bằng không.  
   */  
  // hàm _rútVàoTàiKhoản(  
  function _withdrawToAccount(  
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
  // ) nội_bộ trả_về (số_nguyên_128) {  
  ) internal returns (int128) {  
    // nếu (số_tiền > 0) {  
    if (amount > 0) {  
      // _tạoMụcNộiBộ(mã_khoản_vay, TÀI_KHOẢN_TIỀN_MẶT, tàiKhoảnĐến, số_tiền, dấu_thời_gian, loạiMục, tham_chiếu);  
      _createInternalEntry(loanId, ACC_CASH, toAccount, amount, timestamp, entryType, ref);  
      // trả_về số_tiền;  
      return amount;  
    // }  
    }  
    // trả_về 0;  
    return 0;  
  // }  
  }  
  
  /**  
   * @dev Bumps the per-loan entry counter and returns the packed  
   * @dev Tăng bộ_đếm mục theo từng khoản_vay và trả_về  
   *      `(loanId << 64) | entryNumber` identifier for the new entry.  
   *      định_danh `(mã_khoản_vay << 64) | sốThứTựMục` cho mục mới.  
   */  
  // hàm _tạoChỉSốMụcTiếpTheo(số_nguyên_không_dấu_64 mã_khoản_vay) nội_bộ trả_về (số_nguyên_không_dấu_128) {  
  function _createNextEntryIndex(uint64 loanId) internal returns (uint128) {  
    // số_nguyên_không_dấu_64 sốThứTựMục = ++số_lượng_mục_s[mã_khoản_vay];  
    uint64 entryNumber = ++entryCount[loanId];  
    // trả_về (số_nguyên_không_dấu_128(mã_khoản_vay) << 64) | số_nguyên_không_dấu_128(sốThứTựMục);  
    return (uint128(loanId) << 64) | uint128(entryNumber);  
  // }  
  }

   /**  
   * @dev Applies a transfer of `amount` from `from` to `to`. Subtracts from `from`  
   * @dev Áp_dụng một lần chuyển `số_tiền` từ `từ` đến `đến`. Trừ từ `từ`  
   *      and adds to `to`. Reverts with `InsufficientCashBalance` when `from` is the  
   *      và cộng vào `đến`. Hoàn_tác với `SốDưTiềnMặtKhôngĐủ` khi `từ` là  
   *      `CASH` account and the loan does not hold enough cash. Returns the updated  
   *      tài_khoản `TIỀN_MẶT` và khoản_vay không nắm_giữ đủ tiền_mặt. Trả_về các  
   *      balances so callers can include them in the emitted `EntryCreated` event.  
   *      số_dư đã_cập_nhật để người_gọi có_thể đưa chúng vào sự_kiện `MụcĐãTạo` được phát.  
   */  
  // hàm _cậpNhậtSốDư(  
  function _updateBalances(  
    // số_nguyên_không_dấu_64 mã_khoản_vay,  
    uint64 loanId,  
    // số_nguyên_không_dấu_8 từ,  
    uint8 from,  
    // số_nguyên_không_dấu_8 đến,  
    uint8 to,  
    // số_nguyên_128 số_tiền  
    int128 amount  
  // ) nội_bộ trả_về (số_nguyên_128 sốDưTừĐãCậpNhật, số_nguyên_128 sốDưĐếnĐãCậpNhật) {  
  ) internal returns (int128 updatedFromBalance, int128 updatedToBalance) {  
    // số_nguyên_không_dấu_72 khóaTừ = _lấyKhóaSốDư(mã_khoản_vay, từ);  
    uint72 fromKey = _getBalanceKey(loanId, from);  
    // số_nguyên_không_dấu_72 khóaĐến = _lấyKhóaSốDư(mã_khoản_vay, đến);  
    uint72 toKey = _getBalanceKey(loanId, to);  
  
    // số_nguyên_128 sốDưTừ = số_dư_tài_khoản_s[khóaTừ];  
    int128 fromBalance = accountBalances[fromKey];  
    // nếu (từ == TÀI_KHOẢN_TIỀN_MẶT) {  
    if (from == ACC_CASH) {  
      // yêu_cầu(sốDưTừ >= số_tiền, SốDưTiềnMặtKhôngĐủ());  
      require(fromBalance >= amount, InsufficientCashBalance());  
    // }  
    }  
  
    // sốDưTừĐãCậpNhật = sốDưTừ - số_tiền;  
    updatedFromBalance = fromBalance - amount;  
    // sốDưĐếnĐãCậpNhật = số_dư_tài_khoản_s[khóaĐến] + số_tiền;  
    updatedToBalance = accountBalances[toKey] + amount;  
  
    // số_dư_tài_khoản_s[khóaTừ] = sốDưTừĐãCậpNhật;  
    accountBalances[fromKey] = updatedFromBalance;  
    // số_dư_tài_khoản_s[khóaĐến] = sốDưĐếnĐãCậpNhật;  
    accountBalances[toKey] = updatedToBalance;  
  // }  
  }  
  
  /**  
   * @dev Records a ledger entry transferring `amount` from the ledger accounts `from` to `to` on `loanId`,  
   * @dev Ghi_lại một mục sổ_cái chuyển `số_tiền` từ tài_khoản sổ_cái `từ` đến `đến` trên `mã_khoản_vay`,  
   *      updates the corresponding balances, and emits `EntryCreated`. Reverts when  
   *      cập_nhật các số_dư tương_ứng, và phát `MụcĐãTạo`. Hoàn_tác khi  
   *      `from == to` or `amount <= 0`.  
   *      `từ == đến` hoặc `số_tiền <= 0`.  
   */  
  // hàm _tạoMụcNộiBộ(  
  function _createInternalEntry(  
    // số_nguyên_không_dấu_64 mã_khoản_vay,  
    uint64 loanId,  
    // số_nguyên_không_dấu_8 từ,  
    uint8 from,  
    // số_nguyên_không_dấu_8 đến,  
    uint8 to,  
    // số_nguyên_128 số_tiền,  
    int128 amount,  
    // số_nguyên_không_dấu_48 dấu_thời_gian,  
    uint48 timestamp,  
    // số_nguyên_không_dấu_16 loạiMục,  
    uint16 entryType,  
    // bytes32 tham_chiếu  
    bytes32 ref  
  // ) nội_bộ trả_về (số_nguyên_không_dấu_128 chỉSốMục) {  
  ) internal returns (uint128 entryIndex) {  
    // yêu_cầu(từ != đến, TàiKhoảnKhôngHợpLệ());  
    require(from != to, InvalidAccount());  
    // yêu_cầu(số_tiền > 0, SốTiềnKhôngHợpLệ());  
    require(amount > 0, InvalidAmount());  
  
    // chỉSốMục = _tạoChỉSốMụcTiếpTheo(mã_khoản_vay);  
    entryIndex = _createNextEntryIndex(loanId);  
  
    // mục_s[chỉSốMục] = Mục({  
    entries[entryIndex] = Entry({  
      // số_tiền: số_tiền,  
      amount: amount,  
      // dấu_thời_gian: dấu_thời_gian,  
      timestamp: timestamp,  
      // từ: từ,  
      from: from,  
      // đến: đến,  
      to: to,  
      // loạiMục: loạiMục,  
      entryType: entryType,  
      // tham_chiếu: tham_chiếu  
      ref: ref  
    // });  
    });  
  
    // (số_nguyên_128 sốDưTừĐãCậpNhật, số_nguyên_128 sốDưĐếnĐãCậpNhật) = _cậpNhậtSốDư(mã_khoản_vay, từ, đến, số_tiền);  
    (int128 updatedFromBalance, int128 updatedToBalance) = _updateBalances(loanId, from, to, amount);  
  
    // phát_sự_kiện MụcĐãTạo(chỉSốMục, từ, đến, số_tiền, sốDưTừĐãCậpNhật, sốDưĐếnĐãCậpNhật, loạiMục, tham_chiếu);  
    emit EntryCreated(entryIndex, from, to, amount, updatedFromBalance, updatedToBalance, entryType, ref);  
  // }  
  }  
  
  /**  
   * @dev Pulls `amount` of `currency` from `addr` into the contract and records a  
   * @dev Kéo `số_tiền` của `tiền_tệ` từ `địaChỉ` vào hợp_đồng và ghi_lại một  
   *      `fromAccount` -> CASH ledger entry. `fromAccount` cannot be CASH (that  
   *      mục sổ_cái `tàiKhoảnTừ` -> TIỀN_MẶT. `tàiKhoảnTừ` không_thể là TIỀN_MẶT (điều đó  
   *      would double-count the inflow). Requires `addr` to have approved the  
   *      sẽ tính_đôi dòng_vào). Yêu_cầu `địaChỉ` đã phê_duyệt  
   *      contract for at least `amount`.  
   *      hợp_đồng ít_nhất `số_tiền`.  
   */  
  // hàm _nạpTiền(  
  function _deposit(  
    // số_nguyên_không_dấu_64 mã_khoản_vay,  
    uint64 loanId,  
    // số_nguyên_không_dấu_8 tàiKhoảnTừ,  
    uint8 fromAccount,  
    // số_nguyên_128 số_tiền,  
    int128 amount,  
    // địa_chỉ địaChỉ,  
    address addr,  
    // số_nguyên_không_dấu_48 dấu_thời_gian,  
    uint48 timestamp,  
    // số_nguyên_không_dấu_16 loạiMục,  
    uint16 entryType,  
    // bytes32 tham_chiếu  
    bytes32 ref  
  // ) nội_bộ trả_về (số_nguyên_không_dấu_128 chỉSốMục) {  
  ) internal returns (uint128 entryIndex) {  
    // yêu_cầu(số_tiền > 0, SốTiềnKhôngHợpLệ());  
    require(amount > 0, InvalidAmount());  
    // yêu_cầu(tàiKhoảnTừ != TÀI_KHOẢN_TIỀN_MẶT, TàiKhoảnKhôngHợpLệ());  
    require(fromAccount != ACC_CASH, InvalidAccount());  
    // yêu_cầu(địaChỉ != địa_chỉ(0), ĐịaChỉKhông());  
    require(addr != address(0), ZeroAddress());  
  
    // tiền_tệ.chuyểnAnToànTừ(địaChỉ, địa_chỉ(this), số_nguyên_không_dấu_256(số_nguyên_256(số_tiền)));  
    currency.safeTransferFrom(addr, address(this), uint256(int256(amount)));  
  
    // chỉSốMục = _tạoMụcNộiBộ(mã_khoản_vay, tàiKhoảnTừ, TÀI_KHOẢN_TIỀN_MẶT, số_tiền, dấu_thời_gian, loạiMục, tham_chiếu);  
    entryIndex = _createInternalEntry(loanId, fromAccount, ACC_CASH, amount, timestamp, entryType, ref);  
  // }  
  }  
  
  /**  
   * @dev Records a CASH -> `toAccount` ledger entry and transfers `amount` of  
   * @dev Ghi_lại một mục sổ_cái TIỀN_MẶT -> `tàiKhoảnĐến` và chuyển `số_tiền` của  
   *      `currency` from the contract to `withdrawalAddress`. `toAccount` cannot  
   *      `tiền_tệ` từ hợp_đồng đến `địaChỉRút`. `tàiKhoảnĐến` không_thể  
   *      be CASH (the cash outflow is already represented by the entry's `from`  
   *      là TIỀN_MẶT (dòng_ra tiền_mặt đã được biểu_diễn bởi tài_khoản `từ` của mục  
   *      account).  
   *      đó).  
   */  
  // hàm _rút(  
  function _withdraw(  
    // số_nguyên_không_dấu_64 mã_khoản_vay,  
    uint64 loanId,  
    // số_nguyên_không_dấu_8 tàiKhoảnĐến,  
    uint8 toAccount,  
    // số_nguyên_128 số_tiền,  
    int128 amount,  
    // địa_chỉ địaChỉRút,  
    address withdrawalAddress,  
    // số_nguyên_không_dấu_48 dấu_thời_gian,  
    uint48 timestamp,  
    // số_nguyên_không_dấu_16 loạiMục,  
    uint16 entryType,  
    // bytes32 tham_chiếu  
    bytes32 ref  
  // ) nội_bộ trả_về (số_nguyên_không_dấu_128 chỉSốMục) {  
  ) internal returns (uint128 entryIndex) {  
    // yêu_cầu(số_tiền > 0, SốTiềnKhôngHợpLệ());  
    require(amount > 0, InvalidAmount());  
    // yêu_cầu(tàiKhoảnĐến != TÀI_KHOẢN_TIỀN_MẶT, TàiKhoảnKhôngHợpLệ());  
    require(toAccount != ACC_CASH, InvalidAccount());  
    // yêu_cầu(địaChỉRút != địa_chỉ(0), ĐịaChỉKhông());  
    require(withdrawalAddress != address(0), ZeroAddress());  
  
    // chỉSốMục = _tạoMụcNộiBộ(mã_khoản_vay, TÀI_KHOẢN_TIỀN_MẶT, tàiKhoảnĐến, số_tiền, dấu_thời_gian, loạiMục, tham_chiếu);  
    entryIndex = _createInternalEntry(loanId, ACC_CASH, toAccount, amount, timestamp, entryType, ref);  
  
    // tiền_tệ.chuyểnAnToàn(địaChỉRút, số_nguyên_không_dấu_256(số_nguyên_256(số_tiền)));  
    currency.safeTransfer(withdrawalAddress, uint256(int256(amount)));  
  // }  
  }  
  
  /**  
   * @dev Packs `(loanId, account)` into the storage key used by `accountBalances`.  
   * @dev Đóng_gói `(mã_khoản_vay, tài_khoản)` vào khóa lưu_trữ được dùng bởi `số_dư_tài_khoản_s`.  
   *      Format: `loanId << 8 | account`.  
   *      Định_dạng: `mã_khoản_vay << 8 | tài_khoản`.  
   */  
  // hàm _lấyKhóaSốDư(số_nguyên_không_dấu_64 mã_khoản_vay, số_nguyên_không_dấu_8 tài_khoản) nội_bộ thuần trả_về (số_nguyên_không_dấu_72) {  
  function _getBalanceKey(uint64 loanId, uint8 account) internal pure returns (uint72) {  
    // trả_về (số_nguyên_không_dấu_72(mã_khoản_vay) << 8) | số_nguyên_không_dấu_72(tài_khoản);  
    return (uint72(loanId) << 8) | uint72(account);  
  // }  
  }  
  
  /**  
   * @dev True for accounts whose natural sign is negative (liability / revenue / equity).  
   * @dev Đúng cho các tài_khoản có dấu tự_nhiên là âm (nợ_phải_trả / doanh_thu / vốn_chủ_sở_hữu).  
   *      By convention, account ids `>= 200` are normally-negative; ids below 200 are  
   *      Theo quy_ước, các mã tài_khoản `>= 200` thường_âm; các mã dưới 200 là  
   *      normally-positive (assets / expenses).  
   *      thường_dương (tài_sản / chi_phí).  
   */  
  // hàm _làThườngÂm(số_nguyên_không_dấu_8 tài_khoản) nội_bộ thuần trả_về (bool) {  
  function _isNormallyNegative(uint8 account) internal pure returns (bool) {  
    // trả_về tài_khoản >= 200;  
    return account >= 200;  
  // }  
  }
}
