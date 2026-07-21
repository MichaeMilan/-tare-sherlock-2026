// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.33;

// Entry type constants for standard operations  
// Các hằng số loại mục cho các thao tác tiêu chuẩn  
// Modify with caution, these are parsed and used by off-chain systems  
// Chỉnh sửa cẩn thận, chúng được phân tích cú pháp và sử dụng bởi các hệ thống ngoài chuỗi  
// số_nguyên_không_dấu_16 hằng_số MỤC_CAM_KẾT_KHOẢN_VAY = 0;  
uint16 constant ENTRY_LOAN_COMMITMENT = 0;  
// số_nguyên_không_dấu_16 hằng_số MỤC_VỐN_NHÀ_ĐẦU_TƯ_NHẬN_ĐƯỢC = 1;  
uint16 constant ENTRY_INVESTOR_CAPITAL_RECEIVED = 1;  
// số_nguyên_không_dấu_16 hằng_số MỤC_THANH_TOÁN_NGƯỜI_VAY = 2;  
uint16 constant ENTRY_BORROWER_PAYMENT = 2;  
// số_nguyên_không_dấu_16 hằng_số MỤC_TÍCH_LŨY_LÃI_SUẤT = 3;  
uint16 constant ENTRY_INTEREST_ACCRUAL = 3;  
// số_nguyên_không_dấu_16 hằng_số MỤC_THANH_TOÁN_GỐC_NGƯỜI_VAY = 4;  
uint16 constant ENTRY_BORROWER_PRINCIPAL_PAYMENT = 4;  
// số_nguyên_không_dấu_16 hằng_số MỤC_GIẢI_NGÂN_CHO_NGƯỜI_VAY = 5;  
uint16 constant ENTRY_DISBURSEMENT_TO_BORROWER = 5;  
// số_nguyên_không_dấu_16 hằng_số MỤC_GIỮ_LẠI_PHÍ_NGƯỜI_KHỞI_TẠO = 6;  
uint16 constant ENTRY_ORIGINATOR_FEE_WITHHOLDING = 6;  
// số_nguyên_không_dấu_16 hằng_số MỤC_PHÂN_BỔ_PHÍ_NGƯỜI_DỊCH_VỤ = 7;  
uint16 constant ENTRY_SERVICER_FEE_ALLOCATION = 7;  
// số_nguyên_không_dấu_16 hằng_số MỤC_PHÂN_BỔ_LÃI_NHÀ_ĐẦU_TƯ = 8;  
uint16 constant ENTRY_INVESTOR_INTEREST_ALLOCATION = 8;  
// số_nguyên_không_dấu_16 hằng_số MỤC_THANH_TOÁN_NỢ_LÃI_NGƯỜI_VAY = 9;  
uint16 constant ENTRY_BORROWER_INTEREST_DEBT_CLEARANCE = 9;  
// số_nguyên_không_dấu_16 hằng_số MỤC_RÚT_PHÍ_NGƯỜI_DỊCH_VỤ = 10;  
uint16 constant ENTRY_SERVICER_FEE_WITHDRAWAL = 10;  
// số_nguyên_không_dấu_16 hằng_số MỤC_RÚT_LÃI_NHÀ_ĐẦU_TƯ = 11;  
uint16 constant ENTRY_INVESTOR_INTEREST_WITHDRAWAL = 11;  
// số_nguyên_không_dấu_16 hằng_số MỤC_RÚT_GỐC_NHÀ_ĐẦU_TƯ = 12;  
uint16 constant ENTRY_INVESTOR_PRINCIPAL_WITHDRAWAL = 12;  
// số_nguyên_không_dấu_16 hằng_số MỤC_ĐIỀU_CHỈNH = 13;  
uint16 constant ENTRY_ADJUSTMENT = 13; // used for ad-hoc manual adjustments  
// dùng cho các điều chỉnh thủ công đặc biệt  
// số_nguyên_không_dấu_16 hằng_số MỤC_THU_PHÍ_LINH_TINH = 14;  
uint16 constant ENTRY_MISC_FEE_CHARGE = 14;  
// số_nguyên_không_dấu_16 hằng_số MỤC_THANH_TOÁN_NỢ_PHÍ_LINH_TINH = 15;  
uint16 constant ENTRY_MISC_FEE_DEBT_CLEARANCE = 15;  
// số_nguyên_không_dấu_16 hằng_số MỤC_RÚT_PHÍ_LINH_TINH = 16;  
uint16 constant ENTRY_MISC_FEE_WITHDRAWAL = 16;  
// số_nguyên_không_dấu_16 hằng_số MỤC_RÚT_PHÍ_NGƯỜI_KHỞI_TẠO = 17;  
uint16 constant ENTRY_ORIGINATOR_FEE_WITHDRAWAL = 17;  
// số_nguyên_không_dấu_16 hằng_số MỤC_HOÀN_TRẢ_QUỸ_NGƯỜI_DỊCH_VỤ = 18;  
uint16 constant ENTRY_SERVICER_FUND_RETURN = 18;  
// số_nguyên_không_dấu_16 hằng_số MỤC_ĐẢO_NGƯỢC_LÃI_SUẤT = 19;  
uint16 constant ENTRY_INTEREST_REVERSAL = 19;  
// số_nguyên_không_dấu_16 hằng_số MỤC_PHÂN_LOẠI_LẠI_LÃI_SUẤT = 20;  
uint16 constant ENTRY_INTEREST_RECLASSIFICATION = 20;  
// số_nguyên_không_dấu_16 hằng_số MỤC_HOÀN_TIỀN_NGƯỜI_VAY = 21;  
uint16 constant ENTRY_BORROWER_REFUND = 21;  
// số_nguyên_không_dấu_16 hằng_số MỤC_ĐẢO_NGƯỢC_PHÍ_NGƯỜI_DỊCH_VỤ = 22;  
uint16 constant ENTRY_SERVICER_FEE_REVERSAL = 22;