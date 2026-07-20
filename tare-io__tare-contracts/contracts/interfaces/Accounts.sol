// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.33;

// Hằng Số Tài Khoản Khoản Vay
// Loan Account Constants
//
// Định nghĩa các định danh tài khoản cho hệ thống sổ cái khoản vay.
// Defines account identifiers for the loan ledger system.
// Các tài khoản được nhóm theo hành vi dấu:
// Accounts are grouped by sign behavior:
//   - 100-199: Thường dương (Tài sản, Đối-Nợ phải trả, Chi phí)
//   - 100-199: Normally positive (Assets, Contra-Liabilities, Expenses)
//   - 200-255: Thường âm (Nợ phải trả, Đối-Tài sản, Doanh thu)
//   - 200-255: Normally negative (Liabilities, Contra-Assets, Revenue)
//
// Dùng `tài_khoản >= 200` để kiểm tra nếu tài khoản thường âm.
// Use `account >= 200` to check if an account is normally negative.
// Lưu ý: Giá trị tài khoản được lưu dưới dạng uint8, giới hạn giá trị tối đa là 255.
// Note: Account values are stored as uint8, limiting the max value to 255.

// =============================================================
//                    THƯỜNG DƯƠNG (100-199)
//                    NORMALLY POSITIVE (100-199)
// =============================================================

// --- Tài sản (100-149) ---
// --- Assets (100-149) ---
// uint8 hằng_số TK_TIỀN_MẶT = 100;
uint8 constant ACC_CASH = 100;
// uint8 hằng_số TK_GỐC_PHẢI_THU_NGƯỜI_VAY = 101;
uint8 constant ACC_BORROWER_PRINCIPAL_RECEIVABLE = 101;
// uint8 hằng_số TK_LÃI_PHẢI_THU_NGƯỜI_VAY = 102;
uint8 constant ACC_BORROWER_INTEREST_RECEIVABLE = 102;
// uint8 hằng_số TK_PHÍ_KHÁC_PHẢI_THU_NGƯỜI_VAY = 103;
uint8 constant ACC_BORROWER_MISC_FEE_RECEIVABLE = 103;

// --- Đối-Nợ phải trả (150-199) ---
// --- Contra-Liabilities (150-199) ---
// uint8 hằng_số TK_GỐC_ĐÃ_HOÀN_TRẢ_NHÀ_ĐẦU_TƯ = 150;
uint8 constant ACC_INVESTOR_PRINCIPAL_REPAID = 150;
// uint8 hằng_số TK_LÃI_ĐÃ_TRẢ_NHÀ_ĐẦU_TƯ = 151;
uint8 constant ACC_INVESTOR_INTEREST_PAID = 151;
// uint8 hằng_số TK_PHÍ_ĐÃ_TRẢ_ĐƠN_VỊ_DỊCH_VỤ = 152;
uint8 constant ACC_SERVICER_FEE_PAID = 152;
// uint8 hằng_số TK_PHÍ_ĐÃ_TRẢ_ĐƠN_VỊ_KHỞI_TẠO = 153;
uint8 constant ACC_ORIGINATOR_FEE_PAID = 153;
// uint8 hằng_số TK_PHÍ_KHÁC_ĐÃ_TRẢ_ĐƠN_VỊ_DỊCH_VỤ = 154;
uint8 constant ACC_SERVICER_MISC_FEE_PAID = 154;

// =============================================================
//                    THƯỜNG ÂM (200-255)
//                    NORMALLY NEGATIVE (200-255)
// =============================================================

// --- Nợ phải trả (200-249) ---
// --- Liabilities (200-249) ---
// uint8 hằng_số TK_CAM_KẾT_CHƯA_GIẢI_NGÂN = 200;
uint8 constant ACC_UNFUNDED_COMMITMENT = 200;
// uint8 hằng_số TK_THANH_TOÁN_BÙ_TRỪ_NGƯỜI_VAY = 201;
uint8 constant ACC_BORROWER_PAYMENT_CLEARING = 201;
// uint8 hằng_số TK_GỐC_PHẢI_TRẢ_NHÀ_ĐẦU_TƯ = 202;
uint8 constant ACC_INVESTOR_PRINCIPAL_PAYABLE = 202;
// uint8 hằng_số TK_LÃI_PHẢI_TRẢ_NHÀ_ĐẦU_TƯ = 203;
uint8 constant ACC_INVESTOR_INTEREST_PAYABLE = 203;
// uint8 hằng_số TK_PHÍ_PHẢI_TRẢ_ĐƠN_VỊ_DỊCH_VỤ = 204;
uint8 constant ACC_SERVICER_FEE_PAYABLE = 204;
// uint8 hằng_số TK_PHÍ_PHẢI_TRẢ_ĐƠN_VỊ_KHỞI_TẠO = 205;
uint8 constant ACC_ORIGINATOR_FEE_PAYABLE = 205;
// uint8 hằng_số TK_LÃI_PHẢI_TRẢ_NGƯỜI_VAY_CHƯA_PHÂN_BỔ = 206;
uint8 constant ACC_UNALLOCATED_BORROWER_INTEREST_PAYABLE = 206;
// uint8 hằng_số TK_PHÍ_KHÁC_PHẢI_TRẢ_ĐƠN_VỊ_DỊCH_VỤ = 207;
uint8 constant ACC_SERVICER_MISC_FEE_PAYABLE = 207;
// uint8 hằng_số TK_ĐIỀU_CHỈNH_ĐƠN_VỊ_DỊCH_VỤ = 208;
uint8 constant ACC_SERVICER_ADJUSTMENT = 208;

// --- Đối-Tài sản (250-255) ---
// --- Contra-Assets (250-255) ---
// uint8 hằng_số TK_GỐC_ĐÃ_HOÀN_TRẢ_NGƯỜI_VAY = 250;
uint8 constant ACC_BORROWER_PRINCIPAL_REPAID = 250;
// uint8 hằng_số TK_LÃI_ĐÃ_TRẢ_NGƯỜI_VAY = 251;
uint8 constant ACC_BORROWER_INTEREST_PAID = 251;
// uint8 hằng_số TK_PHÍ_KHÁC_ĐÃ_TRẢ_NGƯỜI_VAY = 252;
uint8 constant ACC_BORROWER_MISC_FEE_PAID = 252;
