// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

// Mã hạn chế cho biết việc chuyển nhượng được phép.
// Restriction code indicating the transfer is allowed.
// uint8 hằng_số MÃ_THÀNH_CÔNG = 0;
uint8 constant SUCCESS_CODE = 0;
// Mã hạn chế cho biết người gửi thiếu `VAI_TRÒ_CỔ_ĐÔNG`.
// Restriction code indicating the sender lacks `SHAREHOLDER_ROLE`.
// uint8 hằng_số MÃ_HẠN_CHẾ_NGƯỜI_GỬI = 1;
uint8 constant SENDER_RESTRICTED_CODE = 1;
// Mã hạn chế cho biết người nhận thiếu `VAI_TRÒ_CỔ_ĐÔNG`.
// Restriction code indicating the recipient lacks `SHAREHOLDER_ROLE`.
// uint8 hằng_số MÃ_HẠN_CHẾ_NGƯỜI_NHẬN = 2;
uint8 constant RECIPIENT_RESTRICTED_CODE = 2;

// string hằng_số THÔNG_ĐIỆP_THÀNH_CÔNG = "THÀNH_CÔNG";
string constant SUCCESS_MESSAGE = "SUCCESS";
// string hằng_số THÔNG_ĐIỆP_HẠN_CHẾ_NGƯỜI_GỬI = "Người gửi không có trong danh sách trắng";
string constant SENDER_RESTRICTED_MESSAGE = "Sender is not whitelisted";
// string hằng_số THÔNG_ĐIỆP_HẠN_CHẾ_NGƯỜI_NHẬN = "Người nhận không có trong danh sách trắng";
string constant RECIPIENT_RESTRICTED_MESSAGE = "Recipient is not whitelisted";
// Thông điệp trả về cho bất kỳ mã hạn chế không được nhận dạng nào.
// Message returned for any unrecognized restriction code.
// string hằng_số THÔNG_ĐIỆP_KHÔNG_XÁC_ĐỊNH = "KHÔNG_XÁC_ĐỊNH";
string constant UNKNOWN_MESSAGE = "UNKNOWN";

/**
 * @tiêu_đề IERC1404
 * @title IERC1404
 * @thông_báo Giao diện Tiêu chuẩn Token Bị Hạn Chế Đơn Giản để hiển thị
 *            các hạn chế chuyển nhượng và lý do có thể đọc được của chúng.
 * @notice Simple Restricted Token Standard interface for surfacing transfer
 *         restrictions and their human-readable reasons.
 * @nhà_phát_triển Mã hạn chế `0` được dành riêng để chỉ ra việc chuyển nhượng
 *                 thành công (không bị hạn chế).
 * @dev Restriction code `0` is reserved to indicate a successful (unrestricted)
 *      transfer.
 */
// giao_diện IERC1404 {
interface IERC1404 {
  /**
   * @thông_báo Trả về mã hạn chế cho việc chuyển nhượng được đề xuất.
   * @notice Returns a restriction code for the proposed transfer.
   * @tham_số từ Địa chỉ người gửi.
   * @param from Sender address.
   * @tham_số đến Địa chỉ người nhận.
   * @param to Recipient address.
   * @tham_số giá_trị Số lượng đang được chuyển nhượng.
   * @param value Amount being transferred.
   * @trả_về Mã hạn chế, trong đó `0` cho biết việc chuyển nhượng được phép.
   * @return Restriction code, where `0` indicates the transfer is allowed.
   */
  // hàm phát_hiện_hạn_chế_chuyển_nhượng(địa_chỉ từ, địa_chỉ đến, uint256 giá_trị) bên_ngoài xem trả_về (uint8);
  function detectTransferRestriction(address from, address to, uint256 value) external view returns (uint8);

  /**
   * @thông_báo Trả về thông điệp có thể đọc được cho mã hạn chế.
   * @notice Returns a human-readable message for a restriction code.
   * @tham_số mã_hạn_chế Mã được trả về trước đó bởi `phát_hiện_hạn_chế_chuyển_nhượng`.
   * @param restrictionCode Code previously returned by `detectTransferRestriction`.
   * @trả_về Giải thích có thể đọc được của hạn chế.
   * @return Human-readable explanation of the restriction.
   */
  // hàm thông_điệp_cho_hạn_chế_chuyển_nhượng(uint8 mã_hạn_chế) bên_ngoài xem trả_về (string bộ_nhớ);
  function messageForTransferRestriction(uint8 restrictionCode) external view returns (string memory);
}
