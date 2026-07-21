// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import {Rescuable} from "contracts/misc/Rescuable.sol";
import {IPortfolioVault} from "contracts/interfaces/IPortfolioVault.sol";
import {IERC7540Deposit, IERC7540Redeem, IERC7540Operator} from "contracts/misc/interfaces/IERC7540.sol";
import {IERC7575} from "contracts/misc/interfaces/IERC7575.sol";
import {INavCalculator} from "contracts/interfaces/INavCalculator.sol";
import {ILoans, InvestorWithdrawalResult, Roles} from "contracts/interfaces/ILoans.sol";
import {ILoansNFT} from "contracts/interfaces/ILoansNFT.sol";
import {ILoansExchange, SaleOffer} from "contracts/interfaces/ILoansExchange.sol";
import {IVaultShareToken} from "contracts/interfaces/IVaultShareToken.sol";
import {ILoansAuth} from "contracts/misc/interfaces/ILoansAuth.sol";

/**  
 * @title Tare Portfolio Vault  
 * Tiêu_đề Tare Portfolio Vault  
 * @notice Core vault contract that holds loan NFTs and computes on-chain NAV via  
 * @notice Hợp_đồng vault cốt_lõi nắm_giữ NFT khoản_vay và tính_toán NAV trên_chuỗi qua  
 * paginated enumeration. Delegates loan valuation to an external INavCalculator  
 * liệt_kê phân_trang. Ủy_quyền định_giá khoản_vay cho hợp_đồng INavCalculator bên_ngoài  
 * contract. Implements ERC-7540.  
 * hợp_đồng. Triển_khai ERC-7540.  
 */  
// hợp_đồng PortfolioVault là IPortfolioVault, Rescuable, ReentrancyGuardTransient, IERC721Receiver {  
contract PortfolioVault is IPortfolioVault, Rescuable, ReentrancyGuardTransient, IERC721Receiver {  
  // sử_dụng SafeERC20 cho IERC20;  
  using SafeERC20 for IERC20;  
  
  // ───────────────────── Constants ──────────────────────  
  // ───────────────────── Hằng_số ──────────────────────  
  
  // bytes32 public constant QUẢN_LÝ_DANH_MỤC = keccak256("PORTFOLIO_MANAGER");  
  bytes32 public constant PORTFOLIO_MANAGER = keccak256("PORTFOLIO_MANAGER");  
  // bytes32 public constant QUẢN_LÝ_NHÀ_ĐẦU_TƯ = keccak256("INVESTOR_MANAGER");  
  bytes32 public constant INVESTOR_MANAGER = keccak256("INVESTOR_MANAGER");  
  
  // số_nguyên_không_dấu_256 nội_bộ constant ĐƠN_VỊ_WAD = 1e18;  
  uint256 internal constant WAD_UNIT = 1e18;  
  // số_nguyên_không_dấu_256 nội_bộ constant CỔ_PHẦN_CHẾT = 1e18;  
  uint256 internal constant DEAD_SHARES = 1e18;  
  // địa_chỉ nội_bộ constant ĐỊA_CHỈ_CHẾT = địa_chỉ(0xdead);  
  address internal constant DEAD_ADDRESS = address(0xdead);  
  
  // ───────────────────── Immutables ─────────────────────  
  // ───────────────────── Bất_biến ─────────────────────  
  
  /// @notice The underlying asset token (e.g. USDC) used to settle deposits and redemptions.  
  // Token tài_sản cơ_bản (ví_dụ USDC) được dùng để thanh_toán các khoản nạp và rút.  
  // IERC20 public immutable tàiSảnToken;  
  IERC20 public immutable assetToken;  
  
  /// @notice The share token minted to investors when their deposit is approved.  
  // Token cổ_phần được đúc cho nhà_đầu_tư khi khoản nạp của họ được phê_duyệt.  
  // IVaultShareToken public immutable shareToken;  
  IVaultShareToken public immutable shareToken;  
  
  // ──────────────────── External references ─────────────  
  // ──────────────────── Tham_chiếu bên_ngoài ─────────────  
  
  /// @notice The Loans contract this vault funds and collects cashflows from.  
  // Hợp_đồng Loans mà vault này cấp_vốn và thu_thập dòng_tiền từ đó.  
  // ILoans public loans;  
  ILoans public loans;  
  
  /// @notice The LoansExchange contract used to atomically buy or sell loan bundles.  
  // Hợp_đồng LoansExchange được dùng để mua hoặc bán các gói khoản_vay một_cách nguyên_tử.  
  // ILoansExchange public exchange;  
  ILoansExchange public exchange;  
  
  /// @notice The Loans NFT contract (ERC721Enumerable) used to enumerate vault holdings.  
  // Hợp_đồng NFT Khoản_vay (ERC721Enumerable) được dùng để liệt_kê các tài_sản nắm_giữ của vault.  
  // ILoansNFT public loansNFT;  
  ILoansNFT public loansNFT;  
  
  /// @inheritdoc IPortfolioVault  
  // Kế_thừa từ IPortfolioVault  
  // INavCalculator public calculator;  
  INavCalculator public calculator;  
  
  // ───────────────────── NAV state ─────────────────────  
  // ───────────────────── Trạng_thái NAV ─────────────────────  
  
  /**  
   * @notice Index into `_navLoanIds` of the next loan to value in the current  
   * @notice Chỉ_số vào `_mãKhoảnVayNav` của khoản_vay tiếp_theo cần định_giá trong  
   *         NAV computation cycle. Reset to `0` once the full list has been swept.  
   *         chu_kỳ tính_toán NAV hiện_tại. Đặt_lại về `0` khi toàn_bộ danh_sách đã được quét.  
   */  
  // số_nguyên_không_dấu_256 public navCursor;  
  uint256 public navCursor;  
  
  /**  
   * @notice Accumulator for the in-progress NAV computation. Folded into `lastNav`  
   * @notice Bộ_tích_lũy cho tính_toán NAV đang_tiến_hành. Được gộp vào `navCuối`  
   *         when the cycle finalises.  
   *         khi chu_kỳ kết_thúc.  
   */  
  // số_nguyên_không_dấu_256 public navĐangChờ;  
  uint256 public pendingNav;  
  
  /// @inheritdoc IPortfolioVault  
  // Kế_thừa từ IPortfolioVault  
  // số_nguyên_không_dấu_256 public navBắtĐầu;  
  uint256 public navStart;  
  
  /// @notice The most recently finalised NAV value.  
  // Giá_trị NAV đã được hoàn_thiện gần_đây nhất.  
  // số_nguyên_không_dấu_256 public navCuối;  
  uint256 public lastNav;  
  
  /// @inheritdoc IPortfolioVault  
  // Kế_thừa từ IPortfolioVault  
  // số_nguyên_không_dấu_256 public cậpNhậtNavCuối;  
  uint256 public lastNavUpdate;  
  
  /**  
   * @notice Snapshot of `loansNFT.ownershipNonce(address(this))` used during NAV  
   * @notice Ảnh_chụp của `loansNFT.số_thứ_tự_sở_hữu(địa_chỉ(this))` được dùng trong  
   *         computation and retained between cycles. Mismatch across batches triggers  
   *         tính_toán NAV và được giữ_lại giữa các chu_kỳ. Không_khớp giữa các lô kích_hoạt  
   *         a restart and re-syncs the NAV list against on-chain ownership; mismatch  
   *         khởi_động_lại và đồng_bộ_lại danh_sách NAV với quyền_sở_hữu trên_chuỗi; không_khớp  
   *         at approval time reverts with `PortfolioHoldingsChanged`.  
   *         tại thời_điểm phê_duyệt hoàn_tác với `DanhMụcTàiSảnĐãThayĐổi`.  
   */  
  // số_nguyên_không_dấu_256 public số_thứ_tự_sở_hữu_cuối;  
  uint256 public lastOwnershipNonce;  
  
  /**  
   * @notice Snapshot of `calculator.configurationVersion()` used during NAV  
   * @notice Ảnh_chụp của `calculator.phiênBảnCấuHình()` được dùng trong  
   *         computation and retained between cycles. Mismatch across batches triggers  
   *         tính_toán NAV và được giữ_lại giữa các chu_kỳ. Không_khớp giữa các lô kích_hoạt  
   *         a restart; mismatch at approval time reverts with `CalculatorConfigurationChanged`.  
   *         khởi_động_lại; không_khớp tại thời_điểm phê_duyệt hoàn_tác với `CấuHìnhMáyTínhĐãThayĐổi`.  
   */  
  // số_nguyên_không_dấu_256 public phiênBảnCấuHìnhMáyTínhCuối;  
  uint256 public lastCalculatorConfigurationVersion;  
  
  /**  
   * @dev Curated list of loan IDs included in NAV. Loans must be owned by the  
   * @dev Danh_sách được_tuyển_chọn các mã khoản_vay được đưa vào NAV. Các khoản_vay phải được sở_hữu bởi  
   *      vault to count; ownership is re-verified on every nonce change. Donations  
   *      vault để tính; quyền_sở_hữu được xác_minh_lại mỗi khi nonce thay_đổi. Các khoản_đóng_góp  
   *      landing in the vault are not added automatically and therefore cannot  
   *      đến vault không được thêm tự_động và do_đó không_thể  
   *      influence NAV until a manager explicitly admits them via `addLoansToNav`.  
   *      ảnh_hưởng đến NAV cho đến khi người_quản_lý chính_thức thêm chúng qua `thêmKhoảnVayVàoNav`.  
   */  
  // số_nguyên_không_dấu_64[] nội_bộ _mãKhoảnVayNav;  
  uint64[] internal _navLoanIds;  
  
  /// @dev 1-indexed position of each loanId in `_navLoanIds`; 0 means absent.  
  // Vị_trí được_đánh_số_từ_1 của mỗi mã khoản_vay trong `_mãKhoảnVayNav`; 0 nghĩa_là vắng_mặt.  
  // mapping(số_nguyên_không_dấu_64 mã_khoản_vay => số_nguyên_không_dấu_256 chỉSốCộngMột) nội_bộ _chỉSốKhoảnVayNav;  
  mapping(uint64 loanId => uint256 indexPlusOne) internal _navLoanIndex;

  // ────────────────── NAV deduction counters ────────────  
  // ────────────────── Bộ_đếm khấu_trừ NAV ────────────  
  
  /**  
   * @notice Total assets pending deposit approval across all controllers.  
   * @notice Tổng tài_sản đang_chờ phê_duyệt nạp tiền trên tất_cả các bộ_điều_khiển.  
   *         Subtracted from on-chain `assetToken` balance when computing NAV.  
   *         Bị trừ khỏi số_dư `tokenTàiSản` trên_chuỗi khi tính_toán NAV.  
   */  
  // số_nguyên_không_dấu_256 public tổngTàiSảnNạpĐangChờ;  
  uint256 public totalPendingDepositAssets;  
  
  /**  
   * @notice Total assets reserved for approved-but-unclaimed redemptions across all controllers.  
   * @notice Tổng tài_sản được dự_trữ cho các lần mua_lại đã_được_phê_duyệt_nhưng_chưa_nhận trên tất_cả các bộ_điều_khiển.  
   *         Subtracted from on-chain `assetToken` balance when computing NAV.  
   *         Bị trừ khỏi số_dư `tokenTàiSản` trên_chuỗi khi tính_toán NAV.  
   */  
  // số_nguyên_không_dấu_256 public tổngTàiSảnMuaLạiCóThểNhận;  
  uint256 public totalClaimableRedeemAssets;  
  
  // ──────────────────── Configuration ──────────────────  
  // ──────────────────── Cấu_hình ──────────────────  
  
  /// @inheritdoc IPortfolioVault  
  // Kế_thừa từ IPortfolioVault  
  // số_nguyên_không_dấu_256 public tuổiNavTốiĐa;  
  uint256 public maxNavAge;  
  
  /// @inheritdoc IPortfolioVault  
  // Kế_thừa từ IPortfolioVault  
  // số_nguyên_không_dấu_256 public thờiGianTínhNavTốiĐa;  
  uint256 public maxNavComputationTime;  
  
  // ──────────────────── Async deposit/redeem state ────────  
  // ──────────────────── Trạng_thái nạp/mua_lại bất_đồng_bộ ────────  
  
  /**  
   * @dev ERC-7540 operator authorisations: `_isOperator[controller][operator]`.  
   * @dev Ủy_quyền vận_hành ERC-7540: `_làVậnHành[bộ_điều_khiển][vận_hành]`.  
   */  
  // mapping(địa_chỉ bộ_điều_khiển => mapping(địa_chỉ vận_hành => bool đã_phê_duyệt)) nội_bộ _làVậnHành;  
  mapping(address controller => mapping(address operator => bool approved)) internal _isOperator;  
  
  /**  
   * @notice Asset amount waiting for approval per controller. Pending requests can be  
   * @notice Số_lượng tài_sản đang_chờ phê_duyệt theo từng bộ_điều_khiển. Các yêu_cầu đang_chờ có_thể  
   *         cancelled by the controller; once approved, assets move to the claimable pool.  
   *         bị hủy bởi bộ_điều_khiển; sau khi được phê_duyệt, tài_sản chuyển sang nhóm có_thể_nhận.  
   */  
  // mapping(địa_chỉ bộ_điều_khiển => số_nguyên_không_dấu_256 tài_sản) public tàiSảnNạpĐangChờ;  
  mapping(address controller => uint256 assets) public pendingDepositAssets;  
  
  /**  
   * @notice Shares pre-minted to the vault at deposit approval, claimable per controller.  
   * @notice Cổ_phần được đúc_trước vào vault khi phê_duyệt nạp tiền, có_thể_nhận theo từng bộ_điều_khiển.  
   */  
  // mapping(địa_chỉ bộ_điều_khiển => số_nguyên_không_dấu_256 cổ_phần) public cổPhầnNạpCóThểNhận;  
  mapping(address controller => uint256 shares) public claimableDepositShares;  
  
  /**  
   * @notice Asset value the controller's claimable shares were minted against. Tracked alongside  
   * @notice Giá_trị tài_sản mà các cổ_phần có_thể_nhận của bộ_điều_khiển được đúc dựa_trên. Được theo_dõi cùng  
   *         shares to keep the conversion ratio fixed at the approval-time NAV.  
   *         cổ_phần để giữ tỷ_lệ chuyển_đổi cố_định tại NAV tại_thời_điểm_phê_duyệt.  
   */  
  // mapping(địa_chỉ bộ_điều_khiển => số_nguyên_không_dấu_256 tài_sản) public tàiSảnNạpCóThểNhận;  
  mapping(address controller => uint256 assets) public claimableDepositAssets;  
  
  /**  
   * @notice Shares transferred to the vault and waiting for redeem approval per controller.  
   * @notice Cổ_phần được chuyển vào vault và đang_chờ phê_duyệt mua_lại theo từng bộ_điều_khiển.  
   *         Pending requests can be cancelled by the controller; on approval, shares are burned.  
   *         Các yêu_cầu đang_chờ có_thể bị hủy bởi bộ_điều_khiển; khi phê_duyệt, cổ_phần bị đốt.  
   */  
  // mapping(địa_chỉ bộ_điều_khiển => số_nguyên_không_dấu_256 cổ_phần) public cổPhầnMuaLạiĐangChờ;  
  mapping(address controller => uint256 shares) public pendingRedeemShares;  
  
  /**  
   * @notice Bookkeeping count of shares the controller's claimable assets were redeemed against.  
   * @notice Số_lượng kế_toán cổ_phần mà tài_sản có_thể_nhận của bộ_điều_khiển được mua_lại dựa_trên.  
   *         Shares themselves were burned at approval time; this value backs the redeem/withdraw math.  
   *         Bản_thân cổ_phần bị đốt tại thời_điểm phê_duyệt; giá_trị này hỗ_trợ phép_tính mua_lại/rút_tiền.  
   */  
  // mapping(địa_chỉ bộ_điều_khiển => số_nguyên_không_dấu_256 cổ_phần) public cổPhầnMuaLạiCóThểNhận;  
  mapping(address controller => uint256 shares) public claimableRedeemShares;  
  
  /**  
   * @notice Asset amount reserved for the controller and ready to be withdrawn against burned shares.  
   * @notice Số_lượng tài_sản được dự_trữ cho bộ_điều_khiển và sẵn_sàng để rút dựa_trên cổ_phần đã_đốt.  
   */  
  // mapping(địa_chỉ bộ_điều_khiển => số_nguyên_không_dấu_256 tài_sản) public tàiSảnMuaLạiCóThểNhận;  
  mapping(address controller => uint256 assets) public claimableRedeemAssets;  
  
  /**  
   * @notice Deploys the PortfolioVault  
   * @notice Triển_khai PortfolioVault  
   * @param loans_ Loans contract address  
   * @param loans_ Địa_chỉ hợp_đồng Loans  
   * @param loansNFT_ Loans NFT contract (ERC721Enumerable)  
   * @param loansNFT_ Hợp_đồng NFT Loans (ERC721Enumerable)  
   * @param exchange_ LoansExchange contract for atomic loan purchases/sales  
   * @param exchange_ Hợp_đồng LoansExchange cho các giao_dịch mua/bán khoản_vay nguyên_tử  
   * @param asset_ Underlying asset  
   * @param asset_ Tài_sản cơ_bản  
   * @param share_ Vault share token contract (ERC20)  
   * @param share_ Hợp_đồng token cổ_phần vault (ERC20)  
   * @param calculator_ Initial NAV calculator contract  
   * @param calculator_ Hợp_đồng máy_tính NAV ban_đầu  
   * @param initialGuardian Address that receives GUARDIAN_ROLE (also controls DEFAULT_ADMIN_ROLE)  
   * @param initialGuardian Địa_chỉ nhận VAI_TRÒ_NGƯỜI_GIÁM_HỘ (cũng kiểm_soát VAI_TRÒ_QUẢN_TRỊ_MẶC_ĐỊNH)  
   * @param initialRecoveryAddress Address that receives rescued tokens  
   * @param initialRecoveryAddress Địa_chỉ nhận các token được giải_cứu  
   * @param maxNavAge_ Maximum age (seconds) of NAV for share-price-sensitive operations  
   * @param maxNavAge_ Tuổi tối_đa (giây) của NAV cho các thao_tác nhạy_cảm_với_giá_cổ_phần  
   * @param maxNavComputationTime_ Maximum allowed duration (seconds) for a NAV computation  
   * @param maxNavComputationTime_ Thời_gian tối_đa được_phép (giây) cho một lần tính_toán NAV  
   */  
  // constructor(  
  constructor(  
    // ILoans khoảnVay_,  
    ILoans loans_,  
    // ILoansNFT nftKhoảnVay_,  
    ILoansNFT loansNFT_,  
    // ILoansExchange sàn_giao_dịch_,  
    ILoansExchange exchange_,  
    // IERC20 tàiSản_,  
    IERC20 asset_,  
    // IVaultShareToken cổPhần_,  
    IVaultShareToken share_,  
    // INavCalculator máyTính_,  
    INavCalculator calculator_,  
    // địa_chỉ người_giám_hộ_ban_đầu,  
    address initialGuardian,  
    // địa_chỉ địaChỉPhụcHồiBanĐầu,  
    address initialRecoveryAddress,  
    // số_nguyên_không_dấu_256 tuổiNavTốiĐa_,  
    uint256 maxNavAge_,  
    // số_nguyên_không_dấu_256 thờiGianTínhNavTốiĐa_  
    uint256 maxNavComputationTime_  
  // ) {  
  ) {  
    // yêu_cầu(người_giám_hộ_ban_đầu != địa_chỉ(0), ĐịaChỉKhông());  
    require(initialGuardian != address(0), ZeroAddress());  
    // yêu_cầu(địa_chỉ(khoảnVay_) != địa_chỉ(0), ĐịaChỉKhông());  
    require(address(loans_) != address(0), ZeroAddress());  
    // yêu_cầu(địa_chỉ(nftKhoảnVay_) != địa_chỉ(0), ĐịaChỉKhông());  
    require(address(loansNFT_) != address(0), ZeroAddress());  
    // yêu_cầu(địa_chỉ(sàn_giao_dịch_) != địa_chỉ(0), ĐịaChỉKhông());  
    require(address(exchange_) != address(0), ZeroAddress());  
    // yêu_cầu(địa_chỉ(tàiSản_) != địa_chỉ(0), ĐịaChỉKhông());  
    require(address(asset_) != address(0), ZeroAddress());  
    // yêu_cầu(địa_chỉ(cổPhần_) != địa_chỉ(0), ĐịaChỉKhông());  
    require(address(share_) != address(0), ZeroAddress());  
    // yêu_cầu(địa_chỉ(máyTính_) != địa_chỉ(0), ĐịaChỉKhông());  
    require(address(calculator_) != address(0), ZeroAddress());  
    // yêu_cầu(tuổiNavTốiĐa_ > 0, TuổiNavTốiĐaKhôngHợpLệ());  
    require(maxNavAge_ > 0, InvalidMaxNavAge());  
    // yêu_cầu(thờiGianTínhNavTốiĐa_ > 0, ThờiGianTínhNavTốiĐaKhôngHợpLệ());  
    require(maxNavComputationTime_ > 0, InvalidMaxNavComputationTime());  
    // _xácThựcKếtNốiKhoảnVay(khoảnVay_, nftKhoảnVay_, tàiSản_);  
    _validateLoansWiring(loans_, loansNFT_, asset_);  
  
    // khoảnVay = khoảnVay_;  
    loans = loans_;  
    // sàn_giao_dịch = sàn_giao_dịch_;  
    exchange = exchange_;  
    // tokenTàiSản = tàiSản_;  
    assetToken = asset_;  
    // tokenCổPhần = cổPhần_;  
    shareToken = share_;  
    // máyTính = máyTính_;  
    calculator = calculator_;  
    // nftKhoảnVay = nftKhoảnVay_;  
    loansNFT = loansNFT_;  
    // tuổiNavTốiĐa = tuổiNavTốiĐa_;  
    maxNavAge = maxNavAge_;  
    // thờiGianTínhNavTốiĐa = thờiGianTínhNavTốiĐa_;  
    maxNavComputationTime = maxNavComputationTime_;  
  
    // _khởiTạoNgườiGiámHộ(người_giám_hộ_ban_đầu);  
    _initGuardian(initialGuardian);  
    // _khởiTạoĐịaChỉPhụcHồi(địaChỉPhụcHồiBanĐầu);  
    _initRecoveryAddress(initialRecoveryAddress);  
    // _đặtQuảnTrịVaiTrò(NGƯỜI_QUẢN_LÝ_DANH_MỤC, VAI_TRÒ_NGƯỜI_GIÁM_HỘ);  
    _setRoleAdmin(PORTFOLIO_MANAGER, GUARDIAN_ROLE);  
    // _đặtQuảnTrịVaiTrò(NGƯỜI_QUẢN_LÝ_NHÀ_ĐẦU_TƯ, VAI_TRÒ_NGƯỜI_GIÁM_HỘ);  
    _setRoleAdmin(INVESTOR_MANAGER, GUARDIAN_ROLE);  
  
    // Mint dead shares to prevent share price manipulation.  
    // Đúc cổ_phần chết để ngăn_chặn thao_túng giá cổ_phần.  
    // Reverts if DEAD_ADDRESS lacks SHAREHOLDER_ROLE on the share token.  
    // Hoàn_tác nếu ĐỊA_CHỈ_CHẾT thiếu VAI_TRÒ_CỔ_ĐÔNG trên token cổ_phần.  
    // tokenCổPhần.đúc(ĐỊA_CHỈ_CHẾT, CỔ_PHẦN_CHẾT);  
    shareToken.mint(DEAD_ADDRESS, DEAD_SHARES);  
  // }  
  }
  // ──────────────────────── Modifiers ─────────────────────────────
 /**  
   * @notice Ensures the caller is the account itself or an approved operator  
   * @notice Đảm_bảo người_gọi là chính tài_khoản hoặc một người_vận_hành đã_được_phê_duyệt  
   * @param account The account address to check against  
   * @param account Địa_chỉ tài_khoản để kiểm_tra  
   */  
  // bổ_nghĩa chỉTàiKhoảnHoặcNgườiVậnHành(địa_chỉ tài_khoản) {  
  modifier onlyAccountOrOperator(address account) {  
    // yêu_cầu(msg.người_gửi == tài_khoản || _làNgườiVậnHành[tài_khoản][msg.người_gửi], KhôngĐượcPhép());  
    require(msg.sender == account || _isOperator[account][msg.sender], Unauthorized());  
    // _;  
    _;  
  // }  
  }  
  
  // ──────────────────────── External Functions ────────────────────  
  // ──────────────────────── Các Hàm Bên_Ngoài ────────────────────  
  
  /// @inheritdoc IPortfolioVault  
  // Kế_thừa từ IPortfolioVault  
  // hàm cậpNhậtNav(số_nguyên_không_dấu_256 kíchThướcLô) bên_ngoài khiKhôngDừng {  
  function updateNav(uint256 batchSize) external whenNotPaused {  
    // _yêuCầuVaiTròQuảnLý();  
    _requireManagerRole();  
    // yêu_cầu(kíchThướcLô > 0, SốTiềnKhông());  
    require(batchSize > 0, ZeroAmount());  
  
    // ILoansNFT nftKhoảnVay_ = nftKhoảnVay;  
    ILoansNFT loansNFT_ = loansNFT;  
    // INavCalculator máyTính_ = máyTính;  
    INavCalculator calculator_ = calculator;  
    // ILoans khoảnVay_ = khoảnVay;  
    ILoans loans_ = loans;  
  
    // số_nguyên_không_dấu_256 nonceHiệnTại = nftKhoảnVay_.số_thứ_tự_sở_hữu(địa_chỉ(this));  
    uint256 currentNonce = loansNFT_.ownershipNonce(address(this));  
    // số_nguyên_không_dấu_256 phiênBảnCấuHìnhHiệnTại = máyTính_.phiênBảnCấuHình();  
    uint256 currentConfigurationVersion = calculator_.configurationVersion();  
    // nếu (bắtĐầuNav == 0) {  
    if (navStart == 0) {  
      // bắtĐầuNav = block.dấu_thời_gian;  
      navStart = block.timestamp;  
      // nonceQuyềnSởHữuCuối = nonceHiệnTại;  
      lastOwnershipNonce = currentNonce;  
      // phiênBảnCấuHìnhMáyTínhCuối = phiênBảnCấuHìnhHiệnTại;  
      lastCalculatorConfigurationVersion = currentConfigurationVersion;  
      // phát_sự_kiện BắtĐầuTínhNav(block.dấu_thời_gian);  
      emit NavComputationStarted(block.timestamp);  
    // } else if (  
    } else if (  
      // nonceHiệnTại != nonceQuyềnSởHữuCuối ||  
      currentNonce != lastOwnershipNonce ||  
      // phiênBảnCấuHìnhHiệnTại != phiênBảnCấuHìnhMáyTínhCuối ||  
      currentConfigurationVersion != lastCalculatorConfigurationVersion ||  
      // block.dấu_thời_gian - bắtĐầuNav > thờiGianTínhNavTốiĐa  
      block.timestamp - navStart > maxNavComputationTime  
    // ) {  
    ) {  
      // Restart if the vault's NFT holdings changed mid-cycle, calculator  
      // Khởi_động_lại nếu danh_mục NFT của vault thay_đổi giữa_chu_kỳ, các hệ_số  
      // factors changed, or the previous computation took too long. The in-loop  
      // máy_tính thay_đổi, hoặc lần tính_toán trước mất quá nhiều thời_gian. Kiểm_tra  
      // ownership check below self-heals the list as it walks.  
      // quyền_sở_hữu trong vòng_lặp bên_dưới tự_chữa_lành danh_sách khi duyệt.  
      // bắtĐầuNav = block.dấu_thời_gian;  
      navStart = block.timestamp;  
      // conTrỏNav = 0;  
      navCursor = 0;  
      // navĐangChờ = 0;  
      pendingNav = 0;  
      // nonceQuyềnSởHữuCuối = nonceHiệnTại;  
      lastOwnershipNonce = currentNonce;  
      // phiênBảnCấuHìnhMáyTínhCuối = phiênBảnCấuHìnhHiệnTại;  
      lastCalculatorConfigurationVersion = currentConfigurationVersion;  
      // phát_sự_kiện BắtĐầuTínhNav(block.dấu_thời_gian);  
      emit NavComputationStarted(block.timestamp);  
    // }  
    }  
  
    // số_nguyên_không_dấu_256 conTrỏ = conTrỏNav;  
    uint256 cursor = navCursor;  
    // số_nguyên_không_dấu_64[] bộ_nhớ sởHữu = new số_nguyên_không_dấu_64[](kíchThướcLô);  
    uint64[] memory owned = new uint64[](batchSize);  
    // số_nguyên_không_dấu_256 sốLượngSởHữu;  
    uint256 ownedCount;  
  
    // for (số_nguyên_không_dấu_256 i; i < kíchThướcLô; ++i) {  
    for (uint256 i; i < batchSize; ++i) {  
      // nếu (conTrỏ >= _mãKhoảnVayNav.độ_dài) break;  
      if (cursor >= _navLoanIds.length) break;  
      // số_nguyên_không_dấu_64 mã_khoản_vay = _mãKhoảnVayNav[conTrỏ];  
      uint64 loanId = _navLoanIds[cursor];  
      // Treat a reverting `ownerOf` (e.g. burned token) the same as a foreign  
      // Xử_lý `chủSởHữuCủa` bị hoàn_tác (ví_dụ token đã_đốt) giống như một  
      // owner so the list self-heals instead of bricking NAV computation.  
      // chủ_sở_hữu ngoại_lai để danh_sách tự_chữa_lành thay_vì làm hỏng tính_toán NAV.  
      // bool sởHữu;  
      bool owns;  
      // try nftKhoảnVay_.chủSởHữuCủa(số_nguyên_không_dấu_256(mã_khoản_vay)) trả_về (địa_chỉ chủSởHữu) {  
      try loansNFT_.ownerOf(uint256(loanId)) returns (address owner) {  
        // sởHữu = chủSởHữu == địa_chỉ(this);  
        owns = owner == address(this);  
      // } catch {  
      } catch {  
        // sởHữu = false;  
        owns = false;  
      // }  
      }  
      // nếu (sởHữu) {  
      if (owns) {  
        // sởHữu[sốLượngSởHữu++] = mã_khoản_vay;  
        owned[ownedCount++] = loanId;  
        // unchecked {  
        unchecked {  
          // ++conTrỏ;  
          ++cursor;  
        // }  
        }  
      // } else {  
      } else {  
        // Drop stale entry; swap-and-pop places a new entry at `cursor`, so do  
        // Xóa mục cũ; hoán_đổi_và_bật đặt một mục mới tại `conTrỏ`, vì vậy đừng  
        // not advance — the next iteration re-scans this slot.  
        // tiến_lên — lần_lặp tiếp_theo quét_lại ô này.  
        // _xóaKhoảnVayKhỏiNav(mã_khoản_vay);  
        _removeLoanFromNav(loanId);  
      // }  
      }  
    // }  
    }  
  
    // nếu (sốLượngSởHữu > 0) {  
    if (ownedCount > 0) {  
      // Trim the memory array to its used length before passing to the calculator.  
      // Cắt_bớt mảng bộ_nhớ về độ_dài đã_dùng trước khi truyền cho máy_tính.  
      // assembly {  
      assembly {  
        // mstore(sởHữu, sốLượngSởHữu)  
        mstore(owned, ownedCount)  
      // }  
      }  
      // navĐangChờ += máyTính_.lấyGiáTrịKhoảnVay_s(khoảnVay_, sởHữu);  
      pendingNav += calculator_.getLoansValue(loans_, owned);  
    // }  
    }  
  
    // conTrỏNav = conTrỏ;  
    navCursor = cursor;  
  
    // Finalize if we've processed all loans  
    // Hoàn_tất nếu chúng_ta đã xử_lý tất_cả khoản_vay  
    // nếu (conTrỏ >= _mãKhoảnVayNav.độ_dài) {  
    if (cursor >= _navLoanIds.length) {  
      // navCuối =  
      lastNav =  
        // tokenTàiSản.số_dư_của(địa_chỉ(this)) +  
        assetToken.balanceOf(address(this)) +  
        // máyTính_.áp_dụngĐiềuChỉnhDanhMục(navĐangChờ) -  
        calculator_.applyPortfolioAdjustment(pendingNav) -  
        // tổngTàiSảnNạpĐangChờ -  
        totalPendingDepositAssets -  
        // tổngTàiSảnRútĐượcYêuCầu;  
        totalClaimableRedeemAssets;  
      // cậpNhậtNavCuối = block.dấu_thời_gian;  
      lastNavUpdate = block.timestamp;  
      // conTrỏNav = 0;  
      navCursor = 0;  
      // navĐangChờ = 0;  
      pendingNav = 0;  
      // bắtĐầuNav = 0;  
      navStart = 0;  
      // phát_sự_kiện NavĐãCậpNhật(navCuối, block.dấu_thời_gian);  
      emit NavUpdated(lastNav, block.timestamp);  
    // }  
    }  
  // }  
  }  
  
  /// @inheritdoc IPortfolioVault  
  // Kế_thừa từ IPortfolioVault  
  // hàm phêDuyệtNạpTiền(  
  function approveDeposit(  
    // địa_chỉ bộ_điều_khiển,  
    address controller,  
    // số_nguyên_không_dấu_256 tài_sản  
    uint256 assets  
  // ) bên_ngoài chỉVaiTrò(NGƯỜI_QUẢN_LÝ_NHÀ_ĐẦU_TƯ) khiKhôngDừng trả_về (số_nguyên_không_dấu_256 cổPhần) {  
  ) external onlyRole(INVESTOR_MANAGER) whenNotPaused returns (uint256 shares) {  
    // _yêuCầuNavMới();  
    _requireFreshNav();  
    // yêu_cầu(tài_sản > 0, SốTiềnKhông());  
    require(assets > 0, ZeroAmount());  
  
    // số_nguyên_không_dấu_256 đangChờ = tàiSảnNạpĐangChờ[bộ_điều_khiển];  
    uint256 pending = pendingDepositAssets[controller];  
    // yêu_cầu(đangChờ > 0, KhôngCóNạpĐangChờ());  
    require(pending > 0, NoPendingDeposit());  
    // yêu_cầu(tài_sản <= đangChờ, VượtQuáĐangChờ());  
    require(assets <= pending, ExceedsPending());  
  
    // số_nguyên_không_dấu_256 tổngCungCấp = tokenCổPhần.tổngCungCấp();  
    uint256 totalSupply = shareToken.totalSupply();  
    // cổPhần = (tài_sản * tổngCungCấp) / navCuối;  
    shares = (assets * totalSupply) / lastNav;  
    // Prevents approving a tiny amount that rounds to 0 shares, which would strand assets  
    // Ngăn_chặn phê_duyệt một số_lượng nhỏ làm_tròn thành 0 cổ_phần, điều này sẽ làm kẹt tài_sản  
    // yêu_cầu(cổPhần > 0, SốTiềnKhông());  
    require(shares > 0, ZeroAmount());  
  
    // tàiSảnNạpĐangChờ[bộ_điều_khiển] = đangChờ - tài_sản;  
    pendingDepositAssets[controller] = pending - assets;  
    // tổngTàiSảnNạpĐangChờ -= tài_sản;  
    totalPendingDepositAssets -= assets;  
    // cổPhầnNạpĐượcYêuCầu[bộ_điều_khiển] += cổPhần;  
    claimableDepositShares[controller] += shares;  
    // tàiSảnNạpĐượcYêuCầu[bộ_điều_khiển] += tài_sản;  
    claimableDepositAssets[controller] += assets;  
    // navCuối += tài_sản;  
    lastNav += assets;  
  
    // Mint shares to vault so totalSupply stays correct for subsequent approvals  
    // Đúc cổ_phần vào vault để tổngCungCấp duy_trì đúng cho các lần phê_duyệt tiếp_theo  
    // tokenCổPhần.đúc(địa_chỉ(this), cổPhần);  
    shareToken.mint(address(this), shares);  
  
    // phát_sự_kiện NạpTiềnĐãPhêDuyệt(bộ_điều_khiển, tài_sản, cổPhần);  
    emit DepositApproved(controller, assets, shares);  
  // }  
  }

  /// @inheritdoc IPortfolioVault  
  // Kế_thừa từ IPortfolioVault  
  // hàm phêDuyệtĐổiThưởng(  
  function approveRedemption(  
    // địa_chỉ bộ_điều_khiển,  
    address controller,  
    // số_nguyên_không_dấu_256 cổPhần  
    uint256 shares  
  // ) bên_ngoài chỉVaiTrò(NGƯỜI_QUẢN_LÝ_NHÀ_ĐẦU_TƯ) khiKhôngDừng trả_về (số_nguyên_không_dấu_256 tài_sản) {  
  ) external onlyRole(INVESTOR_MANAGER) whenNotPaused returns (uint256 assets) {  
    // _yêuCầuNavMới();  
    _requireFreshNav();  
    // yêu_cầu(cổPhần > 0, SốTiềnKhông());  
    require(shares > 0, ZeroAmount());  
  
    // số_nguyên_không_dấu_256 đangChờ = cổPhầnĐổiThưởngĐangChờ[bộ_điều_khiển];  
    uint256 pending = pendingRedeemShares[controller];  
    // yêu_cầu(đangChờ > 0, KhôngCóĐổiThưởngĐangChờ());  
    require(pending > 0, NoPendingRedeem());  
    // yêu_cầu(cổPhần <= đangChờ, VượtQuáĐangChờ());  
    require(shares <= pending, ExceedsPending());  
  
    // số_nguyên_không_dấu_256 tổngCungCấp = tokenCổPhần.tổngCungCấp();  
    uint256 totalSupply = shareToken.totalSupply();  
    // tài_sản = (cổPhần * navCuối) / tổngCungCấp;  
    assets = (shares * lastNav) / totalSupply;  
    // Prevents approving a tiny amount that rounds to 0 assets, which would burn shares for nothing  
    // Ngăn_chặn phê_duyệt một số_lượng nhỏ làm_tròn thành 0 tài_sản, điều này sẽ đốt cổ_phần vô_ích  
    // yêu_cầu(tài_sản > 0, SốTiềnKhông());  
    require(assets > 0, ZeroAmount());  
    // Reserve must be backed by idle USDC; otherwise NAV finalization would underflow  
    // Dự_trữ phải được hỗ_trợ bởi USDC nhàn_rỗi; nếu không việc hoàn_thiện NAV sẽ bị tràn_âm  
    // yêu_cầu(tài_sản <= thanhKhoảnNhànRỗi(), ThanhKhoảnKhôngĐủ());  
    require(assets <= idleLiquidity(), InsufficientLiquidity());  
  
    // cổPhầnĐổiThưởngĐangChờ[bộ_điều_khiển] = đangChờ - cổPhần;  
    pendingRedeemShares[controller] = pending - shares;  
    // cổPhầnĐổiThưởngĐượcYêuCầu[bộ_điều_khiển] += cổPhần;  
    claimableRedeemShares[controller] += shares;  
    // tàiSảnĐổiThưởngĐượcYêuCầu[bộ_điều_khiển] += tài_sản;  
    claimableRedeemAssets[controller] += assets;  
    // tổngTàiSảnĐổiThưởngĐượcYêuCầu += tài_sản;  
    totalClaimableRedeemAssets += assets;  
    // navCuối -= tài_sản;  
    lastNav -= assets;  
  
    // Burn shares so totalSupply stays correct for subsequent approvals  
    // Đốt cổ_phần để tổngCungCấp duy_trì đúng cho các lần phê_duyệt tiếp_theo  
    // tokenCổPhần.đốt(địa_chỉ(this), cổPhần);  
    shareToken.burn(address(this), shares);  
  
    // phát_sự_kiện ĐổiThưởngĐãPhêDuyệt(bộ_điều_khiển, cổPhần, tài_sản);  
    emit RedeemApproved(controller, shares, assets);  
  // }  
  }  
  
  /// @inheritdoc IPortfolioVault  
  // Kế_thừa từ IPortfolioVault  
  // hàm thuThuDòngTiền(  
  function collectCashflows(  
    // số_nguyên_không_dấu_64[] calldata mãKhoảnVay_s,  
    uint64[] calldata loanIds,  
    // bytes32 tham_chiếu  
    bytes32 ref  
  // ) bên_ngoài khôngTáiNhậpCảnh khiKhôngDừng trả_về (KếtQuảRútTiềnNhàĐầuTư[] bộ_nhớ rútTiềnKhoảnVay) {  
  ) external nonReentrant whenNotPaused returns (InvestorWithdrawalResult[] memory loanWithdrawals) {  
    // _yêuCầuVaiTròQuảnLý();  
    _requireManagerRole();  
    // _yêuCầuNavNhànRỗi();  
    _requireIdleNav();  
  
    // Reject loans excluded from NAV; their cashflows would otherwise inflate NAV via idleLiquidity.  
    // Từ_chối các khoản_vay bị loại_trừ khỏi NAV; dòng_tiền của chúng nếu không sẽ làm_phồng NAV qua thanhKhoảnNhànRỗi.  
    // số_nguyên_không_dấu_256 độDài = mãKhoảnVay_s.độ_dài;  
    uint256 length = loanIds.length;  
    // for (số_nguyên_không_dấu_256 i; i < độDài; ++i) {  
    for (uint256 i; i < length; ++i) {  
      // yêu_cầu(_chỉSốKhoảnVayNav[mãKhoảnVay_s[i]] != 0, KhoảnVayKhôngTrongNav());  
      require(_navLoanIndex[loanIds[i]] != 0, LoanNotInNav());  
    // }  
    }  
  
    // rútTiềnKhoảnVay = khoảnVay_s.rútTiềnNhàĐầuTư(mãKhoảnVay_s, số_nguyên_không_dấu_48(block.dấu_thời_gian), tham_chiếu);  
    loanWithdrawals = loans.investorWithdraw(loanIds, uint48(block.timestamp), ref);  
  
    // Mutates idleLiquidity and per-loan ledger state without bumping the ownership nonce.  
    // Thay_đổi thanhKhoảnNhànRỗi và trạng_thái sổ_cái theo từng khoản_vay mà không tăng nonce sở_hữu.  
    // _vôHiệuHóaNav();  
    _invalidateNav();  
  
    // phát_sự_kiện DòngTiềnĐãThu(rútTiềnKhoảnVay);  
    emit CashflowsCollected(loanWithdrawals);  
  // }  
  }  
  
  /// @inheritdoc IPortfolioVault  
  // Kế_thừa từ IPortfolioVault  
  // hàm giảiNgânKhoảnVay(  
  function fundLoan(  
    // số_nguyên_không_dấu_64 mã_khoản_vay,  
    uint64 loanId,  
    // số_nguyên_128 số_tiền,  
    int128 amount,  
    // số_nguyên_không_dấu_48 dấu_thời_gian,  
    uint48 timestamp,  
    // bytes32 tham_chiếu  
    bytes32 ref  
  // ) bên_ngoài chỉVaiTrò(NGƯỜI_QUẢN_LÝ_DANH_MỤC) khôngTáiNhậpCảnh khiKhôngDừng {  
  ) external onlyRole(PORTFOLIO_MANAGER) nonReentrant whenNotPaused {  
    // số_nguyên_không_dấu_64[] bộ_nhớ mãKhoảnVay_s = new số_nguyên_không_dấu_64[](1);  
    uint64[] memory loanIds = new uint64[](1);  
    // mãKhoảnVay_s[0] = mã_khoản_vay;  
    loanIds[0] = loanId;  
    // số_nguyên_128[] bộ_nhớ số_tiền_s = new số_nguyên_128[](1);  
    int128[] memory amounts = new int128[](1);  
    // số_tiền_s[0] = số_tiền;  
    amounts[0] = amount;  
    // _giảiNgânKhoảnVay_s(mãKhoảnVay_s, số_tiền_s, dấu_thời_gian, tham_chiếu);  
    _fundLoans(loanIds, amounts, timestamp, ref);  
  // }  
  }  
  
  /// @inheritdoc IPortfolioVault  
  // Kế_thừa từ IPortfolioVault  
  // hàm giảiNgânKhoảnVay_s(  
  function fundLoans(  
    // số_nguyên_không_dấu_64[] calldata mãKhoảnVay_s,  
    uint64[] calldata loanIds,  
    // số_nguyên_128[] calldata số_tiền_s,  
    int128[] calldata amounts,  
    // số_nguyên_không_dấu_48 dấu_thời_gian,  
    uint48 timestamp,  
    // bytes32 tham_chiếu  
    bytes32 ref  
  // ) bên_ngoài chỉVaiTrò(NGƯỜI_QUẢN_LÝ_DANH_MỤC) khôngTáiNhậpCảnh khiKhôngDừng {  
  ) external onlyRole(PORTFOLIO_MANAGER) nonReentrant whenNotPaused {  
    // yêu_cầu(mãKhoảnVay_s.độ_dài > 0, SốTiềnKhông());  
    require(loanIds.length > 0, ZeroAmount());  
    // yêu_cầu(số_tiền_s.độ_dài == mãKhoảnVay_s.độ_dài, KhôngKhớpĐộDài());  
    require(amounts.length == loanIds.length, LengthMismatch());  
    // _giảiNgânKhoảnVay_s(mãKhoảnVay_s, số_tiền_s, dấu_thời_gian, tham_chiếu);  
    _fundLoans(loanIds, amounts, timestamp, ref);  
  // }  
  }  
  
  /// @inheritdoc IPortfolioVault  
  // Kế_thừa từ IPortfolioVault  
  // hàm thêmKhoảnVayVàoNav(số_nguyên_không_dấu_64[] calldata mãKhoảnVay_s) bên_ngoài chỉVaiTrò(NGƯỜI_QUẢN_LÝ_DANH_MỤC) khiKhôngDừng {  
  function addLoansToNav(uint64[] calldata loanIds) external onlyRole(PORTFOLIO_MANAGER) whenNotPaused {  
    // _yêuCầuNavNhànRỗi();  
    _requireIdleNav();  
    // bool đãThayĐổi;  
    bool changed;  
    // số_nguyên_không_dấu_256 độDài = mãKhoảnVay_s.độ_dài;  
    uint256 length = loanIds.length;  
    // for (số_nguyên_không_dấu_256 i; i < độDài; ++i) {  
    for (uint256 i; i < length; ++i) {  
      // số_nguyên_không_dấu_64 mã_khoản_vay = mãKhoảnVay_s[i];  
      uint64 loanId = loanIds[i];  
      // yêu_cầu(nftKhoảnVay.chủSởHữuCủa(số_nguyên_không_dấu_256(mã_khoản_vay)) == địa_chỉ(this), KhoảnVayKhôngSởHữu());  
      require(loansNFT.ownerOf(uint256(loanId)) == address(this), LoanNotOwned());  
      // nếu (_chỉSốKhoảnVayNav[mã_khoản_vay] == 0) {  
      if (_navLoanIndex[loanId] == 0) {  
        // _thêmKhoảnVayVàoNav(mã_khoản_vay);  
        _addLoanToNav(loanId);  
        // đãThayĐổi = true;  
        changed = true;  
      // }  
      }  
    // }  
    }  
    // Admitting new loans grows the valuation set without bumping the ownership  
    // Thêm khoản_vay mới mở_rộng tập_hợp định_giá mà không tăng nonce sở_hữu;  
    // nonce; invalidate the cached NAV so approvals can't run against a  
    // vô_hiệu_hóa NAV đã_lưu_vào_bộ_nhớ_đệm để các lần phê_duyệt không_thể chạy dựa_trên  
    // snapshot that excluded these loans.  
    // ảnh_chụp đã loại_trừ các khoản_vay này.  
    // nếu (đãThayĐổi) _vôHiệuHóaNav();  
    if (changed) _invalidateNav();  
  // }  
  }  
  
  /// @inheritdoc IPortfolioVault  
  // Kế_thừa từ IPortfolioVault  
  // hàm xóaKhoảnVayKhỏiNav(số_nguyên_không_dấu_64[] calldata mãKhoảnVay_s) bên_ngoài chỉVaiTrò(NGƯỜI_QUẢN_LÝ_DANH_MỤC) khiKhôngDừng {  
  function removeLoansFromNav(uint64[] calldata loanIds) external onlyRole(PORTFOLIO_MANAGER) whenNotPaused {  
    // _yêuCầuNavNhànRỗi();  
    _requireIdleNav();  
    // bool đãThayĐổi;  
    bool changed;  
    // số_nguyên_không_dấu_256 độDài = mãKhoảnVay_s.độ_dài;  
    uint256 length = loanIds.length;  
    // for (số_nguyên_không_dấu_256 i; i < độDài; ++i) {  
    for (uint256 i; i < length; ++i) {  
      // số_nguyên_không_dấu_64 mã_khoản_vay = mãKhoảnVay_s[i];  
      uint64 loanId = loanIds[i];  
      // nếu (_chỉSốKhoảnVayNav[mã_khoản_vay] != 0) {  
      if (_navLoanIndex[loanId] != 0) {  
        // _xóaKhoảnVayKhỏiNav(mã_khoản_vay);  
        _removeLoanFromNav(loanId);  
        // đãThayĐổi = true;  
        changed = true;  
      // }  
      }  
    // }  
    }  
    // Removing shrinks the valuation set without bumping the ownership nonce;  
    // Xóa thu_hẹp tập_hợp định_giá mà không tăng nonce sở_hữu;  
    // invalidate the cached NAV so approvals can't run against a snapshot  
    // vô_hiệu_hóa NAV đã_lưu_vào_bộ_nhớ_đệm để các lần phê_duyệt không_thể chạy dựa_trên ảnh_chụp  
    // that still included these loans.  
    // vẫn còn bao_gồm các khoản_vay này.  
    // nếu (đãThayĐổi) _vôHiệuHóaNav();  
    if (changed) _invalidateNav();  
  // }  
  }  
  
  /// @inheritdoc IPortfolioVault  
  // Kế_thừa từ IPortfolioVault  
  // hàm đặtMáyTính(địa_chỉ _máyTính) bên_ngoài chỉVaiTrò(VAI_TRÒ_NGƯỜI_GIÁM_HỘ) {  
  function setCalculator(address _calculator) external onlyRole(GUARDIAN_ROLE) {  
    // _yêuCầuNavNhànRỗi();  
    _requireIdleNav();  
    // yêu_cầu(_máyTính != địa_chỉ(0), ĐịaChỉKhông());  
    require(_calculator != address(0), ZeroAddress());  
    // máyTính = INavCalculator(_máyTính);  
    calculator = INavCalculator(_calculator);  
    // Cached NAV was computed against the previous calculator; force a refresh  
    // NAV đã_lưu_vào_bộ_nhớ_đệm được tính_toán dựa_trên máy_tính trước; buộc làm_mới  
    // before any share-price-sensitive operation runs again.  
    // trước khi bất_kỳ thao_tác nhạy_cảm_với_giá_cổ_phần nào chạy lại.  
    // _vôHiệuHóaNav();  
    _invalidateNav();  
    // phát_sự_kiện MáyTínhĐãCậpNhật(_máyTính);  
    emit CalculatorUpdated(_calculator);  
  // }  
  }  
  
  /// @inheritdoc IPortfolioVault  
  // Kế_thừa từ IPortfolioVault  
  // hàm đặtKhoảnVay_s(địa_chỉ _khoảnVay_s, địa_chỉ _nftKhoảnVay) bên_ngoài chỉVaiTrò(VAI_TRÒ_NGƯỜI_GIÁM_HỘ) {  
  function setLoans(address _loans, address _loansNFT) external onlyRole(GUARDIAN_ROLE) {  
    // _yêuCầuNavNhànRỗi();  
    _requireIdleNav();  
    // yêu_cầu(_khoảnVay_s != địa_chỉ(0), ĐịaChỉKhông());  
    require(_loans != address(0), ZeroAddress());  
    // yêu_cầu(_nftKhoảnVay != địa_chỉ(0), ĐịaChỉKhông());  
    require(_loansNFT != address(0), ZeroAddress());  
    // _xácNhậnKếtNốiKhoảnVay(ILoans(_khoảnVay_s), ILoansNFT(_nftKhoảnVay), tokenTàiSản);  
    _validateLoansWiring(ILoans(_loans), ILoansNFT(_loansNFT), assetToken);  
  
    // Curated loanIds reference the OLD NFT collection's tokenIds; they have no  
    // Các mã khoản_vay được_tuyển_chọn tham_chiếu đến tokenId của bộ_sưu_tập NFT CŨ; chúng không có  
    // meaning under the new pair and must be cleared so the next NAV computation  
    // ý_nghĩa dưới cặp mới và phải được xóa để lần tính_toán NAV tiếp_theo  
    // doesn't price stale ids (and so re-admission of any colliding id is possible).  
    // không định_giá các id cũ (và để việc thêm_lại bất_kỳ id trùng_lặp nào là có_thể).  
    // _xóaMãKhoảnVayNav();  
    _clearNavLoanIds();  
  
    // khoảnVay_s = ILoans(_khoảnVay_s);  
    loans = ILoans(_loans);  
    // nftKhoảnVay = ILoansNFT(_nftKhoảnVay);  
    loansNFT = ILoansNFT(_loansNFT);  
    // _vôHiệuHóaNav();  
    _invalidateNav();  
    // phát_sự_kiện KhoảnVay_sĐãCậpNhật(_khoảnVay_s, _nftKhoảnVay);  
    emit LoansUpdated(_loans, _loansNFT);  
  // }  
  }

 /// @inheritdoc IPortfolioVault  
  // Kế_thừa từ IPortfolioVault  
  // hàm đặtSànGiaoDịch(địa_chỉ _sànGiaoDịch) bên_ngoài chỉVaiTrò(VAI_TRÒ_NGƯỜI_GIÁM_HỘ) {  
  function setExchange(address _exchange) external onlyRole(GUARDIAN_ROLE) {  
    // _yêuCầuNavNhànRỗi();  
    _requireIdleNav();  
    // yêu_cầu(_sànGiaoDịch != địa_chỉ(0), ĐịaChỉKhông());  
    require(_exchange != address(0), ZeroAddress());  
    // yêu_cầu(ILoansExchange(_sànGiaoDịch).KHOẢN_VAY_S() == khoảnVay_s, SànGiaoDịchKhôngHợpLệ());  
    require(ILoansExchange(_exchange).LOANS() == loans, InvalidExchange());  
    // yêu_cầu(ILoansExchange(_sànGiaoDịch).NFT_KHOẢN_VAY() == nftKhoảnVay, SànGiaoDịchKhôngHợpLệ());  
    require(ILoansExchange(_exchange).LOANS_NFT() == loansNFT, InvalidExchange());  
    // yêu_cầu(địa_chỉ(ILoansExchange(_sànGiaoDịch).TIỀN_TỆ()) == địa_chỉ(tokenTàiSản), SànGiaoDịchKhôngHợpLệ());  
    require(address(ILoansExchange(_exchange).CURRENCY()) == address(assetToken), InvalidExchange());  
    // sànGiaoDịch = ILoansExchange(_sànGiaoDịch);  
    exchange = ILoansExchange(_exchange);  
    // phát_sự_kiện SànGiaoDịchĐãCậpNhật(_sànGiaoDịch);  
    emit ExchangeUpdated(_exchange);  
  // }  
  }  
  
  /// @inheritdoc IPortfolioVault  
  // Kế_thừa từ IPortfolioVault  
  // hàm đặtTuổiNavTốiĐa(số_nguyên_không_dấu_256 _tuổiNavTốiĐa) bên_ngoài chỉQuảnTrịViênHoặcNgườiGiámHộ {  
  function setMaxNavAge(uint256 _maxNavAge) external onlyAdminOrGuardian {  
    // yêu_cầu(_tuổiNavTốiĐa > 0, TuổiNavTốiĐaKhôngHợpLệ());  
    require(_maxNavAge > 0, InvalidMaxNavAge());  
    // tuổiNavTốiĐa = _tuổiNavTốiĐa;  
    maxNavAge = _maxNavAge;  
    // phát_sự_kiện TuổiNavTốiĐaĐãCậpNhật(_tuổiNavTốiĐa);  
    emit MaxNavAgeUpdated(_maxNavAge);  
  // }  
  }  
  
  /// @inheritdoc IPortfolioVault  
  // Kế_thừa từ IPortfolioVault  
  // hàm đặtThờiGianTínhNavTốiĐa(số_nguyên_không_dấu_256 _thờiGianTínhNavTốiĐa) bên_ngoài chỉQuảnTrịViênHoặcNgườiGiámHộ {  
  function setMaxNavComputationTime(uint256 _maxNavComputationTime) external onlyAdminOrGuardian {  
    // yêu_cầu(_thờiGianTínhNavTốiĐa > 0, ThờiGianTínhNavTốiĐaKhôngHợpLệ());  
    require(_maxNavComputationTime > 0, InvalidMaxNavComputationTime());  
    // thờiGianTínhNavTốiĐa = _thờiGianTínhNavTốiĐa;  
    maxNavComputationTime = _maxNavComputationTime;  
    // phát_sự_kiện ThờiGianTínhNavTốiĐaĐãCậpNhật(_thờiGianTínhNavTốiĐa);  
    emit MaxNavComputationTimeUpdated(_maxNavComputationTime);  
  // }  
  }  
  
  /// @inheritdoc IERC721Receiver  
  // Kế_thừa từ IERC721Receiver  
  // hàm khiNhậnERC721(địa_chỉ, địa_chỉ, số_nguyên_không_dấu_256, bytes calldata) bên_ngoài xem trả_về (bytes4) {  
  function onERC721Received(address, address, uint256, bytes calldata) external view returns (bytes4) {  
    // yêu_cầu(msg.người_gửi == địa_chỉ(nftKhoảnVay), ChỉNFTKhoảnVay());  
    require(msg.sender == address(loansNFT), OnlyLoansNFT());  
    // trả_về IERC721Receiver.khiNhậnERC721.selector;  
    return IERC721Receiver.onERC721Received.selector;  
  // }  
  }  
  
  // ──────────────── Portfolio Manager Functions ───────────────────  
  // ──────────────── Các Hàm Người_Quản_Lý Danh_Mục ───────────────────  
  
  /// @inheritdoc IPortfolioVault  
  // Kế_thừa từ IPortfolioVault  
  // hàm chấpNhậnĐềNghịBán(số_nguyên_không_dấu_64 mãĐềNghị) bên_ngoài chỉVaiTrò(NGƯỜI_QUẢN_LÝ_DANH_MỤC) khôngTáiNhậpCảnh khiKhôngDừng {  
  function acceptSaleOffer(uint64 offerId) external onlyRole(PORTFOLIO_MANAGER) nonReentrant whenNotPaused {  
    // _yêuCầuNavNhànRỗi();  
    _requireIdleNav();  
    // ĐềNghịBán bộ_nhớ đềNghị = sànGiaoDịch.lấyĐềNghị(mãĐềNghị);  
    SaleOffer memory offer = exchange.getOffer(offerId);  
    // nếu (đềNghị.giá > 0) {  
    if (offer.price > 0) {  
      // yêu_cầu(số_nguyên_không_dấu_256(đềNghị.giá) <= thanhKhoảnNhànRỗi(), ThanhKhoảnKhôngĐủ());  
      require(uint256(offer.price) <= idleLiquidity(), InsufficientLiquidity());  
      // tokenTàiSản.buộcPhêDuyệt(địa_chỉ(sànGiaoDịch), số_nguyên_không_dấu_256(đềNghị.giá));  
      assetToken.forceApprove(address(exchange), uint256(offer.price));  
    // }  
    }  
    // sànGiaoDịch.chấpNhậnĐềNghị(mãĐềNghị);  
    exchange.acceptOffer(offerId);  
  
    // Verify the exchange actually delivered each NFT before admitting it into NAV.  
    // Xác_minh sàn_giao_dịch thực_sự đã giao mỗi NFT trước khi đưa vào NAV.  
    // số_nguyên_không_dấu_256 độDài = đềNghị.mãKhoảnVay_s.độ_dài;  
    uint256 length = offer.loanIds.length;  
    // for (số_nguyên_không_dấu_256 i; i < độDài; ++i) {  
    for (uint256 i; i < length; ++i) {  
      // số_nguyên_không_dấu_64 mã_khoản_vay = đềNghị.mãKhoảnVay_s[i];  
      uint64 loanId = offer.loanIds[i];  
      // yêu_cầu(nftKhoảnVay.chủSởHữuCủa(số_nguyên_không_dấu_256(mã_khoản_vay)) == địa_chỉ(this), KhoảnVayKhôngSởHữu());  
      require(loansNFT.ownerOf(uint256(loanId)) == address(this), LoanNotOwned());  
      // _thêmKhoảnVayVàoNav(mã_khoản_vay);  
      _addLoanToNav(loanId);  
    // }  
    }  
  // }  
  }  
  
  /// @inheritdoc IPortfolioVault  
  // Kế_thừa từ IPortfolioVault  
  // hàm tạoĐềNghịBán(  
  function createSaleOffer(  
    // địa_chỉ người_mua,  
    address buyer,  
    // số_nguyên_không_dấu_128 giá,  
    uint128 price,  
    // số_nguyên_không_dấu_48 hạnChót,  
    uint48 deadline,  
    // số_nguyên_không_dấu_64[] calldata mãKhoảnVay_s  
    uint64[] calldata loanIds  
  // ) bên_ngoài chỉVaiTrò(NGƯỜI_QUẢN_LÝ_DANH_MỤC) khôngTáiNhậpCảnh khiKhôngDừng trả_về (số_nguyên_không_dấu_64 mãĐềNghị) {  
  ) external onlyRole(PORTFOLIO_MANAGER) nonReentrant whenNotPaused returns (uint64 offerId) {  
    // số_nguyên_không_dấu_256 độDài = mãKhoảnVay_s.độ_dài;  
    uint256 length = loanIds.length;  
    // for (số_nguyên_không_dấu_256 i; i < độDài; ++i) {  
    for (uint256 i; i < length; ++i) {  
      // IERC721(địa_chỉ(nftKhoảnVay)).phêDuyệt(địa_chỉ(sànGiaoDịch), số_nguyên_không_dấu_256(mãKhoảnVay_s[i]));  
      IERC721(address(loansNFT)).approve(address(exchange), uint256(loanIds[i]));  
    // }  
    }  
    // mãĐềNghị = sànGiaoDịch.tạoĐềNghị(người_mua, giá, hạnChót, mãKhoảnVay_s);  
    offerId = exchange.createOffer(buyer, price, deadline, loanIds);  
  // }  
  }  
  
  /// @inheritdoc IPortfolioVault  
  // Kế_thừa từ IPortfolioVault  
  // hàm hủyĐềNghịBán(số_nguyên_không_dấu_64 mãĐềNghị) bên_ngoài chỉVaiTrò(NGƯỜI_QUẢN_LÝ_DANH_MỤC) khôngTáiNhậpCảnh khiKhôngDừng {  
  function cancelSaleOffer(uint64 offerId) external onlyRole(PORTFOLIO_MANAGER) nonReentrant whenNotPaused {  
    // sànGiaoDịch.hủyĐềNghị(mãĐềNghị);  
    exchange.cancelOffer(offerId);  
  // }  
  }  
  
  /// @inheritdoc IPortfolioVault  
  // Kế_thừa từ IPortfolioVault  
  // hàm chuyểnKhoảnVay_s(  
  function transferLoans(  
    // số_nguyên_không_dấu_64[] calldata mãKhoảnVay_s,  
    uint64[] calldata loanIds,  
    // địa_chỉ người_nhận  
    address recipient  
  // ) bên_ngoài chỉVaiTrò(NGƯỜI_QUẢN_LÝ_DANH_MỤC) khôngTáiNhậpCảnh khiKhôngDừng {  
  ) external onlyRole(PORTFOLIO_MANAGER) nonReentrant whenNotPaused {  
    // _yêuCầuNavNhànRỗi();  
    _requireIdleNav();  
    // số_nguyên_không_dấu_256 độDài = mãKhoảnVay_s.độ_dài;  
    uint256 length = loanIds.length;  
    // for (số_nguyên_không_dấu_256 i; i < độDài; ++i) {  
    for (uint256 i; i < length; ++i) {  
      // số_nguyên_không_dấu_64 mã_khoản_vay = mãKhoảnVay_s[i];  
      uint64 loanId = loanIds[i];  
      // _xóaKhoảnVayKhỏiNav(mã_khoản_vay);  
      _removeLoanFromNav(loanId);  
      // IERC721(địa_chỉ(nftKhoảnVay)).chuyểnTừ(địa_chỉ(this), người_nhận, số_nguyên_không_dấu_256(mã_khoản_vay));  
      IERC721(address(loansNFT)).transferFrom(address(this), recipient, uint256(loanId));  
    // }  
    }  
  // }  
  }


  /// @inheritdoc IPortfolioVault  
  // Kế_thừa từ IPortfolioVault  
  // hàm đăngKýĐịaChỉ(địa_chỉ địaChỉ) bên_ngoài {  
  function registerAddress(address addr) external {  
    // _yêuCầuNgườiQuảnLýSổĐịaChỉ();  
    _requireAddressBookManager();  
    // ILoansAuth(địa_chỉ(khoảnVay_s)).đăngKýĐịaChỉ(VaiTrò.NhàĐầuTư, địaChỉ);  
    ILoansAuth(address(loans)).registerAddress(Roles.Investor, addr);  
  // }  
  }  
  
  /// @inheritdoc IPortfolioVault  
  // Kế_thừa từ IPortfolioVault  
  // hàm hủyĐăngKýĐịaChỉ(địa_chỉ địaChỉ) bên_ngoài {  
  function unregisterAddress(address addr) external {  
    // _yêuCầuNgườiQuảnLýSổĐịaChỉ();  
    _requireAddressBookManager();  
    // ILoansAuth(địa_chỉ(khoảnVay_s)).hủyĐăngKýĐịaChỉ(VaiTrò.NhàĐầuTư, địaChỉ);  
    ILoansAuth(address(loans)).unregisterAddress(Roles.Investor, addr);  
  // }  
  }  
  
  // ──────────────── ERC-7540 Async Deposit ───────────────────────  
  // ──────────────── Nạp Tiền Không_Đồng_Bộ ERC-7540 ───────────────────────  
  
  /// @inheritdoc IERC7540Deposit  
  // Kế_thừa từ IERC7540Deposit  
  // hàm yêuCầuNạpTiền(  
  function requestDeposit(  
    // số_nguyên_không_dấu_256 tài_sản,  
    uint256 assets,  
    // địa_chỉ bộ_điều_khiển,  
    address controller,  
    // địa_chỉ chủ_sở_hữu  
    address owner  
  // ) bên_ngoài khôngTáiNhậpCảnh khiKhôngDừng chỉTàiKhoảnHoặcNgườiVậnHành(chủ_sở_hữu) trả_về (số_nguyên_không_dấu_256 mãYêuCầu) {  
  ) external nonReentrant whenNotPaused onlyAccountOrOperator(owner) returns (uint256 requestId) {  
    // yêu_cầu(bộ_điều_khiển != địa_chỉ(this), BộĐiềuKhiểnKhôngHợpLệ());  
    require(controller != address(this), InvalidController());  
    // _yêuCầuNhàĐầuTư(chủ_sở_hữu);  
    _requireInvestor(owner);  
    // _yêuCầuNhàĐầuTư(bộ_điều_khiển);  
    _requireInvestor(controller);  
    // yêu_cầu(tài_sản > 0, SốTiềnKhông());  
    require(assets > 0, ZeroAmount());  
  
    // tokenTàiSản.chuyểnAnToànTừ(chủ_sở_hữu, địa_chỉ(this), tài_sản);  
    assetToken.safeTransferFrom(owner, address(this), assets);  
  
    // tàiSảnNạpĐangChờ[bộ_điều_khiển] += tài_sản;  
    pendingDepositAssets[controller] += assets;  
    // tổngTàiSảnNạpĐangChờ += tài_sản;  
    totalPendingDepositAssets += assets;  
  
    // phát_sự_kiện YêuCầuNạpTiền(bộ_điều_khiển, chủ_sở_hữu, 0, msg.người_gửi, tài_sản);  
    emit DepositRequest(controller, owner, 0, msg.sender, assets);  
    // trả_về 0;  
    return 0;  
  // }  
  }  
  
  /**  
   * @notice Claims an approved deposit by transferring pre-minted shares to the receiver (asset-denominated)  
   * @notice Yêu_cầu một khoản nạp tiền đã_được_phê_duyệt bằng cách chuyển cổ_phần đã_đúc_trước cho người_nhận (tính theo tài_sản)  
   * @param assets Amount of assets to claim (converted to shares at the locked price)  
   * @param assets Số_lượng tài_sản để yêu_cầu (được chuyển_đổi thành cổ_phần theo giá đã_khóa)  
   * @param receiver Address to receive the shares  
   * @param receiver Địa_chỉ để nhận cổ_phần  
   * @param controller The controller of the deposit request  
   * @param controller Bộ_điều_khiển của yêu_cầu nạp tiền  
   * @return shares Number of shares transferred  
   * @return shares Số cổ_phần được chuyển  
   */  
  // hàm nạpTiền(  
  function deposit(  
    // số_nguyên_không_dấu_256 tài_sản,  
    uint256 assets,  
    // địa_chỉ người_nhận,  
    address receiver,  
    // địa_chỉ bộ_điều_khiển  
    address controller  
  // ) bên_ngoài khôngTáiNhậpCảnh khiKhôngDừng chỉTàiKhoảnHoặcNgườiVậnHành(bộ_điều_khiển) trả_về (số_nguyên_không_dấu_256 cổPhần) {  
  ) external nonReentrant whenNotPaused onlyAccountOrOperator(controller) returns (uint256 shares) {  
    // _yêuCầuNhàĐầuTư(bộ_điều_khiển);  
    _requireInvestor(controller);  
    // số_nguyên_không_dấu_256 tàiSảnĐượcYêuCầu_ = tàiSảnNạpĐượcYêuCầu[bộ_điều_khiển];  
    uint256 claimableAssets_ = claimableDepositAssets[controller];  
    // số_nguyên_không_dấu_256 cổPhầnĐượcYêuCầu_ = cổPhầnNạpĐượcYêuCầu[bộ_điều_khiển];  
    uint256 claimableShares_ = claimableDepositShares[controller];  
    // yêu_cầu(tàiSảnĐượcYêuCầu_ > 0 && cổPhầnĐượcYêuCầu_ > 0, KhôngCóNạpTiềnĐượcYêuCầu());  
    require(claimableAssets_ > 0 && claimableShares_ > 0, NoClaimableDeposit());  
    // yêu_cầu(tài_sản > 0 && tài_sản <= tàiSảnĐượcYêuCầu_, VượtQuáĐượcYêuCầu());  
    require(assets > 0 && assets <= claimableAssets_, ExceedsClaimable());  
  
    // cổPhần = (tài_sản * cổPhầnĐượcYêuCầu_) / tàiSảnĐượcYêuCầu_;  
    shares = (assets * claimableShares_) / claimableAssets_;  
    // _yêuCầuNạpTiền(bộ_điều_khiển, người_nhận, tài_sản, cổPhần, tàiSảnĐượcYêuCầu_, cổPhầnĐượcYêuCầu_);  
    _claimDeposit(controller, receiver, assets, shares, claimableAssets_, claimableShares_);  
  // }  
  }  
  
  /**  
   * @notice Claims an approved deposit by transferring exact pre-minted shares to the receiver  
   * @notice Yêu_cầu một khoản nạp tiền đã_được_phê_duyệt bằng cách chuyển chính_xác cổ_phần đã_đúc_trước cho người_nhận  
   * @param shares Number of shares to transfer  
   * @param shares Số cổ_phần để chuyển  
   * @param receiver Address to receive the shares  
   * @param receiver Địa_chỉ để nhận cổ_phần  
   * @param controller The controller of the deposit request  
   * @param controller Bộ_điều_khiển của yêu_cầu nạp tiền  
   * @return assets The asset equivalent of the claimed shares  
   * @return assets Tương_đương tài_sản của cổ_phần được yêu_cầu  
   */  
  // hàm đúc(  
  function mint(  
    // số_nguyên_không_dấu_256 cổPhần,  
    uint256 shares,  
    // địa_chỉ người_nhận,  
    address receiver,  
    // địa_chỉ bộ_điều_khiển  
    address controller  
  // ) bên_ngoài khôngTáiNhậpCảnh khiKhôngDừng chỉTàiKhoảnHoặcNgườiVậnHành(bộ_điều_khiển) trả_về (số_nguyên_không_dấu_256 tài_sản) {  
  ) external nonReentrant whenNotPaused onlyAccountOrOperator(controller) returns (uint256 assets) {  
    // _yêuCầuNhàĐầuTư(bộ_điều_khiển);  
    _requireInvestor(controller);  
    // số_nguyên_không_dấu_256 tàiSảnĐượcYêuCầu_ = tàiSảnNạpĐượcYêuCầu[bộ_điều_khiển];  
    uint256 claimableAssets_ = claimableDepositAssets[controller];  
    // số_nguyên_không_dấu_256 cổPhầnĐượcYêuCầu_ = cổPhầnNạpĐượcYêuCầu[bộ_điều_khiển];  
    uint256 claimableShares_ = claimableDepositShares[controller];  
    // yêu_cầu(tàiSảnĐượcYêuCầu_ > 0 && cổPhầnĐượcYêuCầu_ > 0, KhôngCóNạpTiềnĐượcYêuCầu());  
    require(claimableAssets_ > 0 && claimableShares_ > 0, NoClaimableDeposit());  
    // yêu_cầu(cổPhần > 0 && cổPhần <= cổPhầnĐượcYêuCầu_, VượtQuáĐượcYêuCầu());  
    require(shares > 0 && shares <= claimableShares_, ExceedsClaimable());  
  
    // tài_sản = (cổPhần * tàiSảnĐượcYêuCầu_) / cổPhầnĐượcYêuCầu_;  
    assets = (shares * claimableAssets_) / claimableShares_;  
    // _yêuCầuNạpTiền(bộ_điều_khiển, người_nhận, tài_sản, cổPhần, tàiSảnĐượcYêuCầu_, cổPhầnĐượcYêuCầu_);  
    _claimDeposit(controller, receiver, assets, shares, claimableAssets_, claimableShares_);  
  // }  
  }  
  
  /// @inheritdoc IPortfolioVault  
  // Kế_thừa từ IPortfolioVault  
  // hàm hủyYêuCầuNạpTiền(  
  function cancelDepositRequest(  
    // địa_chỉ bộ_điều_khiển,  
    address controller,  
    // địa_chỉ người_nhận  
    address receiver  
  // ) bên_ngoài khôngTáiNhậpCảnh khiKhôngDừng chỉTàiKhoảnHoặcNgườiVậnHành(bộ_điều_khiển) trả_về (số_nguyên_không_dấu_256 tài_sản) {  
  ) external nonReentrant whenNotPaused onlyAccountOrOperator(controller) returns (uint256 assets) {  
    // _yêuCầuNhàĐầuTư(bộ_điều_khiển);  
    _requireInvestor(controller);  
    // _yêuCầuNhàĐầuTư(người_nhận);  
    _requireInvestor(receiver);  
    // yêu_cầu(người_nhận != địa_chỉ(this), NguờiNhậnKhôngHợpLệ());  
    require(receiver != address(this), InvalidReceiver());  
    // tài_sản = tàiSảnNạpĐangChờ[bộ_điều_khiển];  
    assets = pendingDepositAssets[controller];  
    // yêu_cầu(tài_sản > 0, KhôngCóNạpTiềnĐangChờ());  
    require(assets > 0, NoPendingDeposit());  
  
    // tàiSảnNạpĐangChờ[bộ_điều_khiển] = 0;  
    pendingDepositAssets[controller] = 0;  
    // tổngTàiSảnNạpĐangChờ -= tài_sản;  
    totalPendingDepositAssets -= assets;  
  
    // tokenTàiSản.chuyểnAnToàn(người_nhận, tài_sản);  
    assetToken.safeTransfer(receiver, assets);  
  
    // phát_sự_kiện YêuCầuNạpTiềnĐãHủy(bộ_điều_khiển, người_nhận, tài_sản);  
    emit DepositRequestCancelled(controller, receiver, assets);  
  // }  
  }  
  
  // ──────────────── ERC-7540 Operator Management ─────────────────  
  // ──────────────── Quản_Lý Người_Vận_Hành ERC-7540 ─────────────────  
  
  /// @inheritdoc IERC7540Operator  
  // Kế_thừa từ IERC7540Operator  
  // hàm đặtNgườiVậnHành(địa_chỉ người_vận_hành, bool đã_phê_duyệt) bên_ngoài trả_về (bool) {  
  function setOperator(address operator, bool approved) external returns (bool) {  
    // _làNgườiVậnHành[msg.người_gửi][người_vận_hành] = đã_phê_duyệt;  
    _isOperator[msg.sender][operator] = approved;  
    // phát_sự_kiện NgườiVậnHànhĐặt(msg.người_gửi, người_vận_hành, đã_phê_duyệt);  
    emit OperatorSet(msg.sender, operator, approved);  
    // trả_về true;  
    return true;  
  // }  
  }
  

  

    // ──────────────── ERC-7540 Must-Revert Functions ───────────────  
  // ──────────────── Các Hàm Phải-Hoàn-Tác ERC-7540 ───────────────  
  
  /// @inheritdoc IERC7575  
  // Kế_thừa từ IERC7575  
  // hàm nạpTiền(số_nguyên_không_dấu_256, địa_chỉ) bên_ngoài thuần trả_về (số_nguyên_không_dấu_256) {  
  function deposit(uint256, address) external pure returns (uint256) {  
    // hoàn_tác PhảiHoànTác();  
    revert MustRevert();  
  // }  
  }  
  
  /// @inheritdoc IERC7575  
  // Kế_thừa từ IERC7575  
  // hàm đúc(số_nguyên_không_dấu_256, địa_chỉ) bên_ngoài thuần trả_về (số_nguyên_không_dấu_256) {  
  function mint(uint256, address) external pure returns (uint256) {  
    // hoàn_tác PhảiHoànTác();  
    revert MustRevert();  
  // }  
  }  
  
  /// @inheritdoc IERC7575  
  // Kế_thừa từ IERC7575  
  // hàm xemTrướcNạpTiền(số_nguyên_không_dấu_256) bên_ngoài thuần trả_về (số_nguyên_không_dấu_256) {  
  function previewDeposit(uint256) external pure returns (uint256) {  
    // hoàn_tác PhảiHoànTác();  
    revert MustRevert();  
  // }  
  }  
  
  /// @inheritdoc IERC7575  
  // Kế_thừa từ IERC7575  
  // hàm xemTrướcĐúc(số_nguyên_không_dấu_256) bên_ngoài thuần trả_về (số_nguyên_không_dấu_256) {  
  function previewMint(uint256) external pure returns (uint256) {  
    // hoàn_tác PhảiHoànTác();  
    revert MustRevert();  
  // }  
  }  
  
  /// @inheritdoc IERC7575  
  // Kế_thừa từ IERC7575  
  // hàm xemTrướcRút(số_nguyên_không_dấu_256) bên_ngoài thuần trả_về (số_nguyên_không_dấu_256) {  
  function previewWithdraw(uint256) external pure returns (uint256) {  
    // hoàn_tác PhảiHoànTác();  
    revert MustRevert();  
  // }  
  }  
  
  /// @inheritdoc IERC7575  
  // Kế_thừa từ IERC7575  
  // hàm xemTrướcĐổiThưởng(số_nguyên_không_dấu_256) bên_ngoài thuần trả_về (số_nguyên_không_dấu_256) {  
  function previewRedeem(uint256) external pure returns (uint256) {  
    // hoàn_tác PhảiHoànTác();  
    revert MustRevert();  
  // }  
  }  
  
  // ──────────────── ERC-7540 Async Redeem ──────────────────────────  
  // ──────────────── Đổi_Thưởng Bất_Đồng_Bộ ERC-7540 ──────────────────────────  
  
  /// @inheritdoc IERC7540Redeem  
  // Kế_thừa từ IERC7540Redeem  
  // hàm yêuCầuĐổiThưởng(  
  function requestRedeem(  
    // số_nguyên_không_dấu_256 cổPhần,  
    uint256 shares,  
    // địa_chỉ bộ_điều_khiển,  
    address controller,  
    // địa_chỉ chủ_sở_hữu  
    address owner  
  // ) bên_ngoài khôngTáiNhậpCảnh khiKhôngDừng chỉTàiKhoảnHoặcNgườiVậnHành(chủ_sở_hữu) trả_về (số_nguyên_không_dấu_256 mãYêuCầu) {  
  ) external nonReentrant whenNotPaused onlyAccountOrOperator(owner) returns (uint256 requestId) {  
    // yêu_cầu(bộ_điều_khiển != địa_chỉ(this), BộĐiềuKhiểnKhôngHợpLệ());  
    require(controller != address(this), InvalidController());  
    // _yêuCầuNhàĐầuTư(bộ_điều_khiển);  
    _requireInvestor(controller);  
    // yêu_cầu(cổPhần > 0, SốTiềnKhông());  
    require(shares > 0, ZeroAmount());  
  
    // Lock shares by transferring from owner to vault  
    // Khóa cổ_phần bằng cách chuyển từ chủ_sở_hữu đến vault  
    // IERC20(địa_chỉ(tokenCổPhần)).chuyểnAnToànTừ(chủ_sở_hữu, địa_chỉ(this), cổPhần);  
    IERC20(address(shareToken)).safeTransferFrom(owner, address(this), shares);  
  
    // cổPhầnĐổiĐangChờ[bộ_điều_khiển] += cổPhần;  
    pendingRedeemShares[controller] += shares;  
  
    // phát_sự_kiện YêuCầuĐổiThưởng(bộ_điều_khiển, chủ_sở_hữu, 0, msg.người_gửi, cổPhần);  
    emit RedeemRequest(controller, owner, 0, msg.sender, shares);  
    // trả_về 0;  
    return 0;  
  // }  
  }  
  
  /**  
   * @notice Claims an approved redemption by transferring assets (shares already burned at approval)  
   * @notice Yêu_cầu một lần đổi_thưởng đã_được_phê_duyệt bằng cách chuyển tài_sản (cổ_phần đã được đốt khi phê_duyệt)  
   * @param shares Number of shares to redeem from the claimable pool  
   * @param shares Số cổ_phần để đổi_thưởng từ nhóm có_thể_yêu_cầu  
   * @param receiver Address to receive the assets  
   * @param receiver Địa_chỉ để nhận tài_sản  
   * @param controller The controller of the redeem request  
   * @param controller Bộ_điều_khiển của yêu_cầu đổi_thưởng  
   * @return assets The amount of assets transferred  
   * @return assets Số_lượng tài_sản được chuyển  
   */  
  // hàm đổiThưởng(  
  function redeem(  
    // số_nguyên_không_dấu_256 cổPhần,  
    uint256 shares,  
    // địa_chỉ người_nhận,  
    address receiver,  
    // địa_chỉ bộ_điều_khiển  
    address controller  
  // ) bên_ngoài khôngTáiNhậpCảnh khiKhôngDừng chỉTàiKhoảnHoặcNgườiVậnHành(bộ_điều_khiển) trả_về (số_nguyên_không_dấu_256 tài_sản) {  
  ) external nonReentrant whenNotPaused onlyAccountOrOperator(controller) returns (uint256 assets) {  
    // _yêuCầuNhàĐầuTư(bộ_điều_khiển);  
    _requireInvestor(controller);  
    // _yêuCầuNhàĐầuTư(người_nhận);  
    _requireInvestor(receiver);  
    // số_nguyên_không_dấu_256 cổPhầnĐượcYêuCầu_ = cổPhầnĐổiĐượcYêuCầu[bộ_điều_khiển];  
    uint256 claimableShares_ = claimableRedeemShares[controller];  
    // số_nguyên_không_dấu_256 tàiSảnĐượcYêuCầu_ = tàiSảnĐổiĐượcYêuCầu[bộ_điều_khiển];  
    uint256 claimableAssets_ = claimableRedeemAssets[controller];  
    // yêu_cầu(cổPhầnĐượcYêuCầu_ > 0 && tàiSảnĐượcYêuCầu_ > 0, KhôngCóĐổiThưởngĐượcYêuCầu());  
    require(claimableShares_ > 0 && claimableAssets_ > 0, NoClaimableRedeem());  
    // yêu_cầu(cổPhần > 0 && cổPhần <= cổPhầnĐượcYêuCầu_, VượtQuáĐượcYêuCầu());  
    require(shares > 0 && shares <= claimableShares_, ExceedsClaimable());  
  
    // tài_sản = (cổPhần * tàiSảnĐượcYêuCầu_) / cổPhầnĐượcYêuCầu_;  
    assets = (shares * claimableAssets_) / claimableShares_;  
    // _yêuCầuĐổiThưởng(bộ_điều_khiển, người_nhận, tài_sản, cổPhần, tàiSảnĐượcYêuCầu_, cổPhầnĐượcYêuCầu_);  
    _claimRedeem(controller, receiver, assets, shares, claimableAssets_, claimableShares_);  
  // }  
  }  
  
  /**  
   * @notice Claims an approved redemption by transferring exact assets (shares already burned at approval)  
   * @notice Yêu_cầu một lần đổi_thưởng đã_được_phê_duyệt bằng cách chuyển chính_xác tài_sản (cổ_phần đã được đốt khi phê_duyệt)  
   * @param assets Amount of assets to withdraw  
   * @param assets Số_lượng tài_sản để rút  
   * @param receiver Address to receive the assets  
   * @param receiver Địa_chỉ để nhận tài_sản  
   * @param controller The controller of the redeem request  
   * @param controller Bộ_điều_khiển của yêu_cầu đổi_thưởng  
   * @return shares The number of shares deducted from claimable pool  
   * @return shares Số cổ_phần bị khấu_trừ từ nhóm có_thể_yêu_cầu  
   */  
  // hàm rút(  
  function withdraw(  
    // số_nguyên_không_dấu_256 tài_sản,  
    uint256 assets,  
    // địa_chỉ người_nhận,  
    address receiver,  
    // địa_chỉ bộ_điều_khiển  
    address controller  
  // ) bên_ngoài khôngTáiNhậpCảnh khiKhôngDừng chỉTàiKhoảnHoặcNgườiVậnHành(bộ_điều_khiển) trả_về (số_nguyên_không_dấu_256 cổPhần) {  
  ) external nonReentrant whenNotPaused onlyAccountOrOperator(controller) returns (uint256 shares) {  
    // _yêuCầuNhàĐầuTư(bộ_điều_khiển);  
    _requireInvestor(controller);  
    // _yêuCầuNhàĐầuTư(người_nhận);  
    _requireInvestor(receiver);  
    // số_nguyên_không_dấu_256 cổPhầnĐượcYêuCầu_ = cổPhầnĐổiĐượcYêuCầu[bộ_điều_khiển];  
    uint256 claimableShares_ = claimableRedeemShares[controller];  
    // số_nguyên_không_dấu_256 tàiSảnĐượcYêuCầu_ = tàiSảnĐổiĐượcYêuCầu[bộ_điều_khiển];  
    uint256 claimableAssets_ = claimableRedeemAssets[controller];  
    // yêu_cầu(cổPhầnĐượcYêuCầu_ > 0 && tàiSảnĐượcYêuCầu_ > 0, KhôngCóĐổiThưởngĐượcYêuCầu());  
    require(claimableShares_ > 0 && claimableAssets_ > 0, NoClaimableRedeem());  
    // yêu_cầu(tài_sản > 0 && tài_sản <= tàiSảnĐượcYêuCầu_, VượtQuáĐượcYêuCầu());  
    require(assets > 0 && assets <= claimableAssets_, ExceedsClaimable());  
  
    // cổPhần = (tài_sản * cổPhầnĐượcYêuCầu_) / tàiSảnĐượcYêuCầu_;  
    shares = (assets * claimableShares_) / claimableAssets_;  
    // _yêuCầuĐổiThưởng(bộ_điều_khiển, người_nhận, tài_sản, cổPhần, tàiSảnĐượcYêuCầu_, cổPhầnĐượcYêuCầu_);  
    _claimRedeem(controller, receiver, assets, shares, claimableAssets_, claimableShares_);  
  // }  
  }  
  
  /// @inheritdoc IPortfolioVault  
  // Kế_thừa từ IPortfolioVault  
  // hàm hủyYêuCầuĐổiThưởng(  
  function cancelRedeemRequest(  
    // địa_chỉ bộ_điều_khiển,  
    address controller,  
    // địa_chỉ người_nhận  
    address receiver  
  // ) bên_ngoài khôngTáiNhậpCảnh khiKhôngDừng chỉTàiKhoảnHoặcNgườiVậnHành(bộ_điều_khiển) trả_về (số_nguyên_không_dấu_256 cổPhần) {  
  ) external nonReentrant whenNotPaused onlyAccountOrOperator(controller) returns (uint256 shares) {  
    // _yêuCầuNhàĐầuTư(bộ_điều_khiển);  
    _requireInvestor(controller);  
    // yêu_cầu(người_nhận != địa_chỉ(this), NguờiNhậnKhôngHợpLệ());  
    require(receiver != address(this), InvalidReceiver());  
    // cổPhần = cổPhầnĐổiĐangChờ[bộ_điều_khiển];  
    shares = pendingRedeemShares[controller];  
    // yêu_cầu(cổPhần > 0, KhôngCóĐổiThưởngĐangChờ());  
    require(shares > 0, NoPendingRedeem());  
  
    // cổPhầnĐổiĐangChờ[bộ_điều_khiển] = 0;  
    pendingRedeemShares[controller] = 0;  
  
    // IERC20(địa_chỉ(tokenCổPhần)).chuyểnAnToàn(người_nhận, cổPhần);  
    IERC20(address(shareToken)).safeTransfer(receiver, shares);  
  
    // phát_sự_kiện YêuCầuĐổiThưởngĐãHủy(bộ_điều_khiển, người_nhận, cổPhần);  
    emit RedeemRequestCancelled(controller, receiver, shares);  
  // }  
  }


 // ──────────────────────── View Functions ────────────────────────  
  // ──────────────────────── Các Hàm Xem ────────────────────────  
  
  /// @inheritdoc IPortfolioVault  
  // Kế_thừa từ IPortfolioVault  
  // hàm nav() bên_ngoài xem trả_về (số_nguyên_không_dấu_256) {  
  function nav() external view returns (uint256) {  
    // trả_về navCuối;  
    return lastNav;  
  // }  
  }  
  
  /// @inheritdoc IPortfolioVault  
  // Kế_thừa từ IPortfolioVault  
  // hàm giáCổPhần() bên_ngoài xem trả_về (số_nguyên_không_dấu_256) {  
  function sharePrice() external view returns (uint256) {  
    // trả_về (navCuối * ĐƠN_VỊ_WAD) / tokenCổPhần.tổngCungCấp();  
    return (lastNav * WAD_UNIT) / shareToken.totalSupply();  
  // }  
  }  
  
  /// @inheritdoc IERC7540Operator  
  // Kế_thừa từ IERC7540Operator  
  // hàm làNgườiVậnHành(địa_chỉ bộ_điều_khiển, địa_chỉ người_vận_hành) bên_ngoài xem trả_về (bool) {  
  function isOperator(address controller, address operator) external view returns (bool) {  
    // trả_về _làNgườiVậnHành[bộ_điều_khiển][người_vận_hành];  
    return _isOperator[controller][operator];  
  // }  
  }  
  
  /// @inheritdoc IERC7540Deposit  
  // Kế_thừa từ IERC7540Deposit  
  // hàm yêuCầuNạpTiềnĐangChờ(số_nguyên_không_dấu_256, địa_chỉ bộ_điều_khiển) bên_ngoài xem trả_về (số_nguyên_không_dấu_256 tàiSảnĐangChờ) {  
  function pendingDepositRequest(uint256, address controller) external view returns (uint256 pendingAssets) {  
    // tàiSảnĐangChờ = tàiSảnNạpĐangChờ[bộ_điều_khiển];  
    pendingAssets = pendingDepositAssets[controller];  
  // }  
  }  
  
  /// @inheritdoc IERC7540Deposit  
  // Kế_thừa từ IERC7540Deposit  
  // hàm yêuCầuNạpTiềnĐượcYêuCầu(số_nguyên_không_dấu_256, địa_chỉ bộ_điều_khiển) bên_ngoài xem trả_về (số_nguyên_không_dấu_256 tàiSảnĐượcYêuCầu) {  
  function claimableDepositRequest(uint256, address controller) external view returns (uint256 claimableAssets) {  
    // tàiSảnĐượcYêuCầu = nạpTiềnTốiĐa(bộ_điều_khiển);  
    claimableAssets = maxDeposit(controller);  
  // }  
  }  
  
  /// @inheritdoc IERC7540Redeem  
  // Kế_thừa từ IERC7540Redeem  
  // hàm yêuCầuĐổiThưởngĐangChờ(số_nguyên_không_dấu_256, địa_chỉ bộ_điều_khiển) bên_ngoài xem trả_về (số_nguyên_không_dấu_256 cổPhầnĐangChờ) {  
  function pendingRedeemRequest(uint256, address controller) external view returns (uint256 pendingShares) {  
    // cổPhầnĐangChờ = cổPhầnĐổiĐangChờ[bộ_điều_khiển];  
    pendingShares = pendingRedeemShares[controller];  
  // }  
  }  
  
  /// @inheritdoc IERC7540Redeem  
  // Kế_thừa từ IERC7540Redeem  
  // hàm yêuCầuĐổiThưởngĐượcYêuCầu(số_nguyên_không_dấu_256, địa_chỉ bộ_điều_khiển) bên_ngoài xem trả_về (số_nguyên_không_dấu_256 cổPhầnĐượcYêuCầu) {  
  function claimableRedeemRequest(uint256, address controller) external view returns (uint256 claimableShares) {  
    // cổPhầnĐượcYêuCầu = đổiThưởngTốiĐa(bộ_điều_khiển);  
    claimableShares = maxRedeem(controller);  
  // }  
  }  
  
  // ──────────────── ERC-7575 View Functions ──────────────────────  
  // ──────────────── Các Hàm Xem ERC-7575 ──────────────────────  
  
  /// @inheritdoc IERC7575  
  // Kế_thừa từ IERC7575  
  // hàm tàiSản() bên_ngoài xem trả_về (địa_chỉ) {  
  function asset() external view returns (address) {  
    // trả_về địa_chỉ(tokenTàiSản);  
    return address(assetToken);  
  // }  
  }  
  
  /// @inheritdoc IERC7575  
  // Kế_thừa từ IERC7575  
  // hàm cổPhần() bên_ngoài xem trả_về (địa_chỉ) {  
  function share() external view returns (address) {  
    // trả_về địa_chỉ(tokenCổPhần);  
    return address(shareToken);  
  // }  
  }  
  
  /// @inheritdoc IERC7575  
  // Kế_thừa từ IERC7575  
  /// @dev Prices off the last finalized NAV. Returns 0 only before the first NAV. While a NAV is  
  // @dev Định_giá dựa_trên NAV đã_hoàn_thiện cuối_cùng. Trả_về 0 chỉ trước NAV đầu_tiên. Trong khi NAV bị  
  ///      invalidated (`lastNavUpdate == 0`, pending a fresh `updateNav`) this still returns the last  
  // Vô_hiệu_hóa (`cậpNhậtNavCuối == 0`, đang_chờ `cậpNhậtNav` mới) điều này vẫn trả_về giá_trị cuối_cùng,  
  ///      value, so external integrators must not treat it as a live oracle.  
  // vì vậy các bên_tích_hợp bên_ngoài không được coi nó là một oracle trực_tiếp.  
  // hàm chuyểnThànhCổPhần(số_nguyên_không_dấu_256 tài_sản) bên_ngoài xem trả_về (số_nguyên_không_dấu_256) {  
  function convertToShares(uint256 assets) external view returns (uint256) {  
    // nếu (navCuối == 0) trả_về 0;  
    if (lastNav == 0) return 0;  
    // trả_về (tài_sản * tokenCổPhần.tổngCungCấp()) / navCuối;  
    return (assets * shareToken.totalSupply()) / lastNav;  
  // }  
  }  
  
  /// @inheritdoc IERC7575  
  // Kế_thừa từ IERC7575  
  /// @dev Prices off the last finalized NAV. Returns 0 only before the first NAV. While a NAV is  
  // @dev Định_giá dựa_trên NAV đã_hoàn_thiện cuối_cùng. Trả_về 0 chỉ trước NAV đầu_tiên. Trong khi NAV bị  
  ///      invalidated (`lastNavUpdate == 0`, pending a fresh `updateNav`) this still returns the last  
  // Vô_hiệu_hóa (`cậpNhậtNavCuối == 0`, đang_chờ `cậpNhậtNav` mới) điều này vẫn trả_về giá_trị cuối_cùng,  
  ///      value, so external integrators must not treat it as a live oracle.  
  // vì vậy các bên_tích_hợp bên_ngoài không được coi nó là một oracle trực_tiếp.  
  // hàm chuyểnThànhTàiSản(số_nguyên_không_dấu_256 cổPhần) bên_ngoài xem trả_về (số_nguyên_không_dấu_256) {  
  function convertToAssets(uint256 shares) external view returns (uint256) {  
    // nếu (navCuối == 0) trả_về 0;  
    if (lastNav == 0) return 0;  
    // trả_về (cổPhần * navCuối) / tokenCổPhần.tổngCungCấp();  
    return (shares * lastNav) / shareToken.totalSupply();  
  // }  
  }  
  
  /// @inheritdoc IERC7575  
  // Kế_thừa từ IERC7575  
  // hàm tổngTàiSản() bên_ngoài xem trả_về (số_nguyên_không_dấu_256) {  
  function totalAssets() external view returns (uint256) {  
    // trả_về navCuối;  
    return lastNav;  
  // }  
  }  
  
  /// @inheritdoc IERC7575  
  // Kế_thừa từ IERC7575  
  // hàm nạpTiềnTốiĐa(địa_chỉ bộ_điều_khiển) public xem trả_về (số_nguyên_không_dấu_256) {  
  function maxDeposit(address controller) public view returns (uint256) {  
    // nếu (đãDừng()) trả_về 0;  
    if (paused()) return 0;  
    // trả_về tàiSảnNạpĐượcYêuCầu[bộ_điều_khiển];  
    return claimableDepositAssets[controller];  
  // }  
  }  
  
  /// @inheritdoc IERC7575  
  // Kế_thừa từ IERC7575  
  // hàm đúcTốiĐa(địa_chỉ bộ_điều_khiển) bên_ngoài xem trả_về (số_nguyên_không_dấu_256) {  
  function maxMint(address controller) external view returns (uint256) {  
    // nếu (đãDừng()) trả_về 0;  
    if (paused()) return 0;  
    // trả_về cổPhầnNạpĐượcYêuCầu[bộ_điều_khiển];  
    return claimableDepositShares[controller];  
  // }  
  }  
  
  /// @inheritdoc IERC7575  
  // Kế_thừa từ IERC7575  
  // hàm rútTiềnTốiĐa(địa_chỉ bộ_điều_khiển) bên_ngoài xem trả_về (số_nguyên_không_dấu_256) {  
  function maxWithdraw(address controller) external view returns (uint256) {  
    // nếu (đãDừng()) trả_về 0;  
    if (paused()) return 0;  
    // trả_về tàiSảnĐổiĐượcYêuCầu[bộ_điều_khiển];  
    return claimableRedeemAssets[controller];  
  // }  
  }  
  
  /// @inheritdoc IERC7575  
  // Kế_thừa từ IERC7575  
  // hàm đổiThưởngTốiĐa(địa_chỉ bộ_điều_khiển) public xem trả_về (số_nguyên_không_dấu_256) {  
  function maxRedeem(address controller) public view returns (uint256) {  
    // nếu (đãDừng()) trả_về 0;  
    if (paused()) return 0;  
    // trả_về cổPhầnĐổiĐượcYêuCầu[bộ_điều_khiển];  
    return claimableRedeemShares[controller];  
  // }  
  }  
  
  /**  
   * @notice ERC-165 interface support advertising ERC-721 receiver, ERC-7540 and ERC-7575 interfaces.  
   * @notice Hỗ_trợ giao_diện ERC-165 quảng_cáo giao_diện người_nhận ERC-721, ERC-7540 và ERC-7575.  
   * @dev Hard-coded interface ids match the values from the respective draft EIPs; they cannot  
   * @dev Các mã giao_diện được_mã_hóa_cứng khớp với các giá_trị từ các EIP nháp tương_ứng; chúng không_thể  
   *      be derived from `type(I).interfaceId` for interfaces that inherit from each other.  
   *      được suy_ra từ `type(I).interfaceId` cho các giao_diện kế_thừa lẫn nhau.  
   */  
  // hàm hỗTrợGiaoDiện(bytes4 mãGiaoDiện) public xem ghi_đè(AccessControl, IERC165) trả_về (bool) {  
  function supportsInterface(bytes4 interfaceId) public view override(AccessControl, IERC165) returns (bool) {  
    // trả_về  
    return  
      // mãGiaoDiện == 0xe3bc4e65 || // IERC7540Operator  
      interfaceId == 0xe3bc4e65 || // IERC7540Operator  
      // mãGiaoDiện == 0x2f0a18c5 || // IERC7575  
      interfaceId == 0x2f0a18c5 || // IERC7575  
      // mãGiaoDiện == 0xce3bbe50 || // IERC7540Deposit  
      interfaceId == 0xce3bbe50 || // IERC7540Deposit  
      // mãGiaoDiện == 0x620ee8e4 || // IERC7540Redeem  
      interfaceId == 0x620ee8e4 || // IERC7540Redeem  
      // mãGiaoDiện == type(IERC721Receiver).interfaceId ||  
      interfaceId == type(IERC721Receiver).interfaceId ||  
      // super.hỗTrợGiaoDiện(mãGiaoDiện);  
      super.supportsInterface(interfaceId);  
  // }  
  }  
  
  /// @inheritdoc IPortfolioVault  
  // Kế_thừa từ IPortfolioVault  
  // hàm sốLượngKhoảnVayNav() bên_ngoài xem trả_về (số_nguyên_không_dấu_256) {  
  function navLoanCount() external view returns (uint256) {  
    // trả_về _mãKhoảnVayNav.độ_dài;  
    return _navLoanIds.length;  
  // }  
  }  
  
  /// @inheritdoc IPortfolioVault  
  // Kế_thừa từ IPortfolioVault  
  // hàm mãKhoảnVayNavTại(số_nguyên_không_dấu_256 chỉSố) bên_ngoài xem trả_về (số_nguyên_không_dấu_64) {  
  function navLoanIdAt(uint256 index) external view returns (uint64) {  
    // trả_về _mãKhoảnVayNav[chỉSố];  
    return _navLoanIds[index];  
  // }  
  }  
  
  /// @inheritdoc IPortfolioVault  
  // Kế_thừa từ IPortfolioVault  
  // hàm làTrongNav(số_nguyên_không_dấu_64 mã_khoản_vay) bên_ngoài xem trả_về (bool) {  
  function isInNav(uint64 loanId) external view returns (bool) {  
    // trả_về _chỉSốKhoảnVayNav[mã_khoản_vay] != 0;  
    return _navLoanIndex[loanId] != 0;  
  // }  
  }  
  
  /**  
   * @notice Returns funds available for portfolio operations after reserved investor assets.  
   * @notice Trả_về các quỹ có_sẵn cho các hoạt_động danh_mục sau khi trừ tài_sản nhà_đầu_tư đã_dự_trữ.  
   * @dev Reserved assets are the sum of `totalPendingDepositAssets` (assets in flight awaiting  
   * @dev Tài_sản dự_trữ là tổng của `tổngTàiSảnNạpĐangChờ` (tài_sản đang_chờ  
   *      approval) and `totalClaimableRedeemAssets` (already-approved redemptions awaiting claim).  
   *      phê_duyệt) và `tổngTàiSảnĐổiĐượcYêuCầu` (các lần đổi_thưởng đã_phê_duyệt đang_chờ yêu_cầu).  
   */  
  // hàm thanhKhoảnNhànRỗi() public xem trả_về (số_nguyên_không_dấu_256) {  
  function idleLiquidity() public view returns (uint256) {  
    // số_nguyên_không_dấu_256 số_dư = tokenTàiSản.số_dư_của(địa_chỉ(this));  
    uint256 balance = assetToken.balanceOf(address(this));  
    // số_nguyên_không_dấu_256 tàiSảnDựTrữ = tổngTàiSảnNạpĐangChờ + tổngTàiSảnĐổiĐượcYêuCầu;  
    uint256 reservedAssets = totalPendingDepositAssets + totalClaimableRedeemAssets;  
  
    // nếu (tàiSảnDựTrữ >= số_dư) trả_về 0;  
    if (reservedAssets >= balance) return 0;  
    // trả_về số_dư - tàiSảnDựTrữ;  
    return balance - reservedAssets;  
  // }  
  }

  // ──────────────────────── Các Hàm Nội_Bộ ────────────────────  
  // ──────────────────────── Internal Functions ────────────────────  
  
  /**  
   * @notice Shared logic for deposit and mint claim paths. Transfers pre-minted shares  
   * @notice Logic dùng_chung cho các đường_dẫn yêu_cầu nạp_tiền và đúc. Chuyển cổ_phần đã_đúc_trước  
   * from vault to receiver (shares were minted to vault at approval time).  
   * từ vault đến người_nhận (cổ_phần được đúc vào vault tại thời_điểm phê_duyệt).  
   * @param controller The controller of the deposit request  
   * @param controller Bộ_điều_khiển của yêu_cầu nạp_tiền  
   * @param receiver Address to receive the shares  
   * @param receiver Địa_chỉ nhận cổ_phần  
   * @param assets The asset amount being claimed  
   * @param assets Số_lượng tài_sản đang được yêu_cầu  
   * @param shares The share amount being transferred  
   * @param shares Số_lượng cổ_phần đang được chuyển  
   * @param claimableAssets_ Cached claimable assets for the controller  
   * @param claimableAssets_ Tài_sản có_thể_yêu_cầu đã_lưu_đệm cho bộ_điều_khiển  
   * @param claimableShares_ Cached claimable shares for the controller  
   * @param claimableShares_ Cổ_phần có_thể_yêu_cầu đã_lưu_đệm cho bộ_điều_khiển  
   */  
  // hàm _yêuCầuNạpTiền(  
  function _claimDeposit(  
    // địa_chỉ bộ_điều_khiển,  
    address controller,  
    // địa_chỉ người_nhận,  
    address receiver,  
    // số_nguyên_không_dấu_256 tài_sản,  
    uint256 assets,  
    // số_nguyên_không_dấu_256 cổPhần,  
    uint256 shares,  
    // số_nguyên_không_dấu_256 tàiSảnĐượcYêuCầu_,  
    uint256 claimableAssets_,  
    // số_nguyên_không_dấu_256 cổPhầnĐượcYêuCầu_  
    uint256 claimableShares_  
  // ) riêng_tư {  
  ) private {  
    // yêu_cầu(người_nhận != địa_chỉ(this), NguờiNhậnKhôngHợpLệ());  
    require(receiver != address(this), InvalidReceiver());  
    // Prevents rounding exploits: mint() could compute assets=0 (free shares),  
    // Ngăn_chặn khai_thác làm_tròn: đúc() có_thể tính tài_sản=0 (cổ_phần miễn_phí),  
    // deposit() could compute shares=0 (assets consumed for nothing)  
    // nạpTiền() có_thể tính cổ_phần=0 (tài_sản bị tiêu_thụ vô_ích)  
    // yêu_cầu(tài_sản > 0 && cổPhần > 0, VượtQuáĐượcYêuCầu());  
    require(assets > 0 && shares > 0, ExceedsClaimable());  
  
    // tàiSảnNạpĐượcYêuCầu[bộ_điều_khiển] = tàiSảnĐượcYêuCầu_ - tài_sản;  
    claimableDepositAssets[controller] = claimableAssets_ - assets;  
    // cổPhầnNạpĐượcYêuCầu[bộ_điều_khiển] = cổPhầnĐượcYêuCầu_ - cổPhần;  
    claimableDepositShares[controller] = claimableShares_ - shares;  
  
    // IERC20(địa_chỉ(tokenCổPhần)).chuyểnAnToàn(người_nhận, cổPhần);  
    IERC20(address(shareToken)).safeTransfer(receiver, shares);  
    // phát_sự_kiện NạpTiền(bộ_điều_khiển, người_nhận, tài_sản, cổPhần);  
    emit Deposit(controller, receiver, assets, shares);  
  // }  
  }  
  
  /**  
   * @notice Shared logic for redeem and withdraw claim paths. Transfers assets to receiver  
   * @notice Logic dùng_chung cho các đường_dẫn yêu_cầu đổi_thưởng và rút_tiền. Chuyển tài_sản đến người_nhận  
   * (shares were already burned at approval time).  
   * (cổ_phần đã được đốt tại thời_điểm phê_duyệt).  
   * @param controller The controller of the redeem request  
   * @param controller Bộ_điều_khiển của yêu_cầu đổi_thưởng  
   * @param receiver Address to receive the assets  
   * @param receiver Địa_chỉ nhận tài_sản  
   * @param assets The asset amount being transferred  
   * @param assets Số_lượng tài_sản đang được chuyển  
   * @param shares The share amount being claimed (already burned, used for bookkeeping)  
   * @param shares Số_lượng cổ_phần đang được yêu_cầu (đã đốt, dùng để ghi_sổ)  
   * @param claimableAssets_ Cached claimable assets for the controller  
   * @param claimableAssets_ Tài_sản có_thể_yêu_cầu đã_lưu_đệm cho bộ_điều_khiển  
   * @param claimableShares_ Cached claimable shares for the controller  
   * @param claimableShares_ Cổ_phần có_thể_yêu_cầu đã_lưu_đệm cho bộ_điều_khiển  
   */  
  // hàm _yêuCầuĐổiThưởng(  
  function _claimRedeem(  
    // địa_chỉ bộ_điều_khiển,  
    address controller,  
    // địa_chỉ người_nhận,  
    address receiver,  
    // số_nguyên_không_dấu_256 tài_sản,  
    uint256 assets,  
    // số_nguyên_không_dấu_256 cổPhần,  
    uint256 shares,  
    // số_nguyên_không_dấu_256 tàiSảnĐượcYêuCầu_,  
    uint256 claimableAssets_,  
    // số_nguyên_không_dấu_256 cổPhầnĐượcYêuCầu_  
    uint256 claimableShares_  
  // ) riêng_tư {  
  ) private {  
    // yêu_cầu(người_nhận != địa_chỉ(this), NguờiNhậnKhôngHợpLệ());  
    require(receiver != address(this), InvalidReceiver());  
    // Prevents rounding exploits: withdraw() could compute shares=0 (free USDC),  
    // Ngăn_chặn khai_thác làm_tròn: rút_tiền() có_thể tính cổ_phần=0 (USDC miễn_phí),  
    // redeem() could compute assets=0 (shares redeemed for nothing)  
    // đổiThưởng() có_thể tính tài_sản=0 (cổ_phần đổi vô_ích)  
    // yêu_cầu(tài_sản > 0 && cổPhần > 0, VượtQuáĐượcYêuCầu());  
    require(assets > 0 && shares > 0, ExceedsClaimable());  
  
    // cổPhầnĐổiĐượcYêuCầu[bộ_điều_khiển] = cổPhầnĐượcYêuCầu_ - cổPhần;  
    claimableRedeemShares[controller] = claimableShares_ - shares;  
    // tàiSảnĐổiĐượcYêuCầu[bộ_điều_khiển] = tàiSảnĐượcYêuCầu_ - tài_sản;  
    claimableRedeemAssets[controller] = claimableAssets_ - assets;  
    // tổngTàiSảnĐổiĐượcYêuCầu -= tài_sản;  
    totalClaimableRedeemAssets -= assets;  
  
    // tokenTàiSản.chuyểnAnToàn(người_nhận, tài_sản);  
    assetToken.safeTransfer(receiver, assets);  
  
    // phát_sự_kiện Rút(msg.người_gửi, người_nhận, bộ_điều_khiển, tài_sản, cổPhần);  
    emit Withdraw(msg.sender, receiver, controller, assets, shares);  
  // }  
  }  
  
  /**  
   * @dev Shared implementation for `fundLoan` and `fundLoans`.  
   * @dev Triển_khai dùng_chung cho `giảiNgânKhoảnVay` và `giảiNgânKhoảnVay_s`.  
   */  
  // hàm _giảiNgânKhoảnVay_s(số_nguyên_không_dấu_64[] bộ_nhớ mãKhoảnVay_s, số_nguyên_128[] bộ_nhớ số_tiền_s, số_nguyên_không_dấu_48 dấu_thời_gian, bytes32 tham_chiếu) nội_bộ {  
  function _fundLoans(uint64[] memory loanIds, int128[] memory amounts, uint48 timestamp, bytes32 ref) internal {  
    // _yêuCầuNavNhànRỗi();  
    _requireIdleNav();  
    // số_nguyên_không_dấu_256 độDài = mãKhoảnVay_s.độ_dài;  
    uint256 length = loanIds.length;  
  
    // số_nguyên_không_dấu_256 tổngSốTiền;  
    uint256 totalAmount;  
    // for (số_nguyên_không_dấu_256 i; i < độDài; ++i) {  
    for (uint256 i; i < length; ++i) {  
      // số_nguyên_128 số_tiền = số_tiền_s[i];  
      int128 amount = amounts[i];  
      // yêu_cầu(số_tiền > 0, ILoans.SốTiềnKhôngHợpLệ());  
      require(amount > 0, ILoans.InvalidAmount());  
      // tổngSốTiền += số_nguyên_không_dấu_256(số_nguyên_256(số_tiền));  
      totalAmount += uint256(int256(amount));  
    // }  
    }  
    // yêu_cầu(tổngSốTiền <= thanhKhoảnNhànRỗi(), ThanhKhoảnKhôngĐủ());  
    require(totalAmount <= idleLiquidity(), InsufficientLiquidity());  
  
    // tokenTàiSản.buộcPhêDuyệt(địa_chỉ(khoảnVay_s), tổngSốTiền);  
    assetToken.forceApprove(address(loans), totalAmount);  
    // for (số_nguyên_không_dấu_256 i; i < độDài; ++i) {  
    for (uint256 i; i < length; ++i) {  
      // số_nguyên_không_dấu_64 mã_khoản_vay = mãKhoảnVay_s[i];  
      uint64 loanId = loanIds[i];  
      // số_nguyên_128 số_tiền = số_tiền_s[i];  
      int128 amount = amounts[i];  
      // số_nguyên_không_dấu_128 chỉSốMục = khoảnVay_s.giảiNgân(mã_khoản_vay, số_tiền, dấu_thời_gian, tham_chiếu);  
      uint128 entryIndex = loans.fund(loanId, amount, timestamp, ref);  
      // _thêmKhoảnVayVàoNav(mã_khoản_vay);  
      _addLoanToNav(loanId);  
      // phát_sự_kiện KhoảnVayĐãGiảiNgân(mã_khoản_vay, số_tiền, chỉSốMục, tham_chiếu);  
      emit LoanFunded(loanId, amount, entryIndex, ref);  
    // }  
    }  
  
    // NAV-preserving only when portfolioFactor is 1e18; invalidate unconditionally since no ownership-nonce bump occurs.  
    // Chỉ bảo_toàn NAV khi hệSốDanhMục là 1e18; vô_hiệu_hóa vô_điều_kiện vì không có lần tăng nonce sở_hữu nào xảy_ra.  
    // _vôHiệuHóaNav();  
    _invalidateNav();  
  // }  
  }  
  
  /**  
   * @dev Adds a loan to the NAV list if not already present. Idempotent. Caller is  
   * @dev Thêm một khoản_vay vào danh_sách NAV nếu chưa có. Bất_biến. Người_gọi có  
   *      responsible for verifying ownership when the call site doesn't already  
   *      trách_nhiệm xác_minh quyền_sở_hữu khi vị_trí gọi chưa  
   *      guarantee it (the internal callers used here do).  
   *      đảm_bảo điều đó (các người_gọi nội_bộ được dùng ở đây thì có).  
   */  
  // hàm _thêmKhoảnVayVàoNav(số_nguyên_không_dấu_64 mã_khoản_vay) nội_bộ {  
  function _addLoanToNav(uint64 loanId) internal {  
    // nếu (_chỉSốKhoảnVayNav[mã_khoản_vay] != 0) trả_về;  
    if (_navLoanIndex[loanId] != 0) return;  
    // _mãKhoảnVayNav.đẩy(mã_khoản_vay);  
    _navLoanIds.push(loanId);  
    // _chỉSốKhoảnVayNav[mã_khoản_vay] = _mãKhoảnVayNav.độ_dài;  
    _navLoanIndex[loanId] = _navLoanIds.length;  
    // phát_sự_kiện KhoảnVayĐãThêmVàoNav(mã_khoản_vay);  
    emit LoanAddedToNav(loanId);  
  // }  
  }  
  
  /**  
   * @dev Removes a loan from the curated loan list using swap-and-pop. No-op if absent.  
   * @dev Xóa một khoản_vay khỏi danh_sách khoản_vay được_tuyển_chọn bằng hoán_đổi_và_bật. Không_làm_gì nếu vắng_mặt.  
   */  
  // hàm _xóaKhoảnVayKhỏiNav(số_nguyên_không_dấu_64 mã_khoản_vay) nội_bộ {  
  function _removeLoanFromNav(uint64 loanId) internal {  
    // số_nguyên_không_dấu_256 chỉSố = _chỉSốKhoảnVayNav[mã_khoản_vay];  
    uint256 idx = _navLoanIndex[loanId];  
    // nếu (chỉSố == 0) trả_về;  
    if (idx == 0) return;  
    // số_nguyên_không_dấu_256 chỉSốCuối = _mãKhoảnVayNav.độ_dài;  
    uint256 lastIdx = _navLoanIds.length;  
    // nếu (chỉSố != chỉSốCuối) {  
    if (idx != lastIdx) {  
      // số_nguyên_không_dấu_64 mãCuối = _mãKhoảnVayNav[chỉSốCuối - 1];  
      uint64 lastId = _navLoanIds[lastIdx - 1];  
      // _mãKhoảnVayNav[chỉSố - 1] = mãCuối;  
      _navLoanIds[idx - 1] = lastId;  
      // _chỉSốKhoảnVayNav[mãCuối] = chỉSố;  
      _navLoanIndex[lastId] = idx;  
    // }  
    }  
    // _mãKhoảnVayNav.bật();  
    _navLoanIds.pop();  
    // _chỉSốKhoảnVayNav[mã_khoản_vay] = 0;  
    _navLoanIndex[loanId] = 0;  
    // phát_sự_kiện KhoảnVayĐãXóaKhỏiNav(mã_khoản_vay);  
    emit LoanRemovedFromNav(loanId);  
  // }  
  }


    /**  
   * @notice Empties the curated NAV list, clearing both the array and the index map.  
   * @notice Làm_trống danh_sách NAV được_tuyển_chọn, xóa cả mảng và bản_đồ chỉ_mục.  
   * @dev Pops from the end so each iteration is cheap (no swap); emits one `LoanRemovedFromNav` per id.  
   * @dev Bật từ cuối để mỗi lần lặp rẻ (không hoán_đổi); phát một `KhoảnVayĐãXóaKhỏiNav` mỗi id.  
   */  
  // hàm _xóaMãKhoảnVayNav() nội_bộ {  
  function _clearNavLoanIds() internal {  
    // for (số_nguyên_không_dấu_256 i = _mãKhoảnVayNav.độ_dài; i > 0; --i) {  
    for (uint256 i = _navLoanIds.length; i > 0; --i) {  
      // số_nguyên_không_dấu_64 mã_khoản_vay = _mãKhoảnVayNav[i - 1];  
      uint64 loanId = _navLoanIds[i - 1];  
      // _chỉSốKhoảnVayNav[mã_khoản_vay] = 0;  
      _navLoanIndex[loanId] = 0;  
      // _mãKhoảnVayNav.bật();  
      _navLoanIds.pop();  
      // phát_sự_kiện KhoảnVayĐãXóaKhỏiNav(mã_khoản_vay);  
      emit LoanRemovedFromNav(loanId);  
    // }  
    }  
  // }  
  }  
  
  /**  
   * @dev Reverts if the NAV is stale, zero, or a computation is in progress.  
   * @dev Hoàn_tác nếu NAV cũ, bằng_không, hoặc đang có tính_toán đang_tiến_hành.  
   *      Used by share-price-sensitive operations (approveDeposit, approveRedemption, etc.).  
   *      Được sử_dụng bởi các thao_tác nhạy_cảm với giá cổ_phần (phêDuyệtNạpTiền, phêDuyệtĐổiThưởng, v.v.).  
   *      The nonce equality check ensures `lastNav` reflects the current set of  
   *      Kiểm_tra bằng_nhau nonce đảm_bảo `navCuối` phản_ánh tập_hợp hiện_tại của  
   *      vault-owned loan NFTs: any out-of-band transfer in or out (e.g. an  
   *      NFT khoản_vay thuộc_sở_hữu vault: bất_kỳ lần chuyển ngoài_băng vào hoặc ra (ví_dụ một  
   *      external buyer settling an open sale offer, a rescue, a donation) bumps  
   *      người_mua bên_ngoài thanh_toán một đề_nghị bán đang_mở, một lần giải_cứu, một khoản_đóng_góp) tăng  
   *      the nonce and forces the manager to run `updateNav` before approvals.  
   *      nonce và buộc người_quản_lý chạy `cậpNhậtNav` trước khi phê_duyệt.  
   */  
  // hàm _yêuCầuNavMới() nội_bộ xem {  
  function _requireFreshNav() internal view {  
    // yêu_cầu(bắtĐầuNav == 0, ĐangTínhToánNav());  
    require(navStart == 0, NavComputationInProgress());  
    // yêu_cầu(navCuối > 0, NavKhông());  
    require(lastNav > 0, ZeroNav());  
    // Specific staleness signals come before the generic age check so callers  
    // Các tín_hiệu cũ cụ_thể đến trước kiểm_tra tuổi chung để người_gọi  
    // see the most informative error (e.g. `PortfolioHoldingsChanged` when an  
    // thấy lỗi thông_tin nhất (ví_dụ `DanhMụcNắmGiữĐãThayĐổi` khi một  
    // NFT moved, even if `lastNavUpdate` was also explicitly cleared).  
    // NFT đã di_chuyển, ngay cả khi `cậpNhậtNavCuối` cũng đã được xóa rõ_ràng).  
    // yêu_cầu(nftKhoảnVay.nonceQuyềnSởHữu(địa_chỉ(this)) == nonceQuyềnSởHữuCuối, DanhMụcNắmGiữĐãThayĐổi());  
    require(loansNFT.ownershipNonce(address(this)) == lastOwnershipNonce, PortfolioHoldingsChanged());  
    // yêu_cầu(máyTính.phiênBảnCấuHình() == phiênBảnCấuHìnhMáyTínhCuối, CấuHìnhMáyTínhĐãThayĐổi());  
    require(calculator.configurationVersion() == lastCalculatorConfigurationVersion, CalculatorConfigurationChanged());  
    // yêu_cầu(block.dấu_thời_gian - cậpNhậtNavCuối <= tuổiNavTốiĐa, NavCũ());  
    require(block.timestamp - lastNavUpdate <= maxNavAge, StaleNav());  
  // }  
  }  
  
  /// @notice Reverts if a NAV computation is currently in progress.  
  // Hoàn_tác nếu đang có tính_toán NAV đang_tiến_hành.  
  // hàm _yêuCầuNavNhànRỗi() nội_bộ xem {  
  function _requireIdleNav() internal view {  
    // yêu_cầu(bắtĐầuNav == 0, ĐangTínhToánNav());  
    require(navStart == 0, NavComputationInProgress());  
  // }  
  }  
  
  /**  
   * @dev Reverts unless the Loans contract settles in `asset_` and the LoansNFT points back at it.  
   * @dev Hoàn_tác trừ_khi hợp_đồng Loans thanh_toán bằng `tài_sản_` và LoansNFT trỏ ngược lại nó.  
   */  
  // hàm _xácNhậnKếtNốiKhoảnVay(ILoans khoảnVay_, ILoansNFT nftKhoảnVay_, IERC20 tài_sản_) nội_bộ xem {  
  function _validateLoansWiring(ILoans loans_, ILoansNFT loansNFT_, IERC20 asset_) internal view {  
    // yêu_cầu(địa_chỉ(khoảnVay_.tiền_tệ()) == địa_chỉ(tài_sản_), KhôngKhớpTàiSản());  
    require(address(loans_.currency()) == address(asset_), AssetMismatch());  
    // yêu_cầu(nftKhoảnVay_.HỢP_ĐỒNG_KHOẢN_VAY() == địa_chỉ(khoảnVay_), KhôngKhớpConTrỏNgược());  
    require(loansNFT_.LOANS_CONTRACT() == address(loans_), ReversePointerMismatch());  
  // }  
  }  
  
  /**  
   * @dev Clears the cached NAV freshness stamp so the next share-price-sensitive  
   * @dev Xóa dấu_mới_mẻ NAV được_lưu_trong_bộ_nhớ_đệm để thao_tác nhạy_cảm với giá cổ_phần tiếp_theo  
   *      operation must wait for a new `updateNav` cycle. Used by call sites that  
   *      phải chờ một chu_kỳ `cậpNhậtNav` mới. Được sử_dụng bởi các điểm_gọi  
   *      mutate NAV inputs (vault USDC balance, curated list, loan ledger state)  
   *      thay_đổi đầu_vào NAV (số_dư USDC vault, danh_sách được_tuyển_chọn, trạng_thái sổ_cái khoản_vay)  
   *      without bumping `loansNFT.ownershipNonce`.  
   *      mà không tăng `nftKhoảnVay.nonceQuyềnSởHữu`.  
   */  
  // hàm _vôHiệuHóaNav() nội_bộ {  
  function _invalidateNav() internal {  
    // cậpNhậtNavCuối = 0;  
    lastNavUpdate = 0;  
    // phát_sự_kiện NavĐãVôHiệuHóa();  
    emit NavInvalidated();  
  // }  
  }  
  
  /// @notice Reverts if caller holds neither PORTFOLIO_MANAGER nor INVESTOR_MANAGER  
  // Hoàn_tác nếu người_gọi không nắm_giữ cả NGƯỜI_QUẢN_LÝ_DANH_MỤC lẫn NGƯỜI_QUẢN_LÝ_NHÀ_ĐẦU_TƯ  
  // hàm _yêuCầuVaiTròQuảnLý() nội_bộ xem {  
  function _requireManagerRole() internal view {  
    // nếu (!cóVaiTrò(NGƯỜI_QUẢN_LÝ_DANH_MỤC, msg.người_gửi) && !cóVaiTrò(NGƯỜI_QUẢN_LÝ_NHÀ_ĐẦU_TƯ, msg.người_gửi)) {  
    if (!hasRole(PORTFOLIO_MANAGER, msg.sender) && !hasRole(INVESTOR_MANAGER, msg.sender)) {  
      // hoàn_tác IAccessControl.TàiKhoảnKhôngĐượcPhépKiểmSoátTruyCập(msg.người_gửi, NGƯỜI_QUẢN_LÝ_DANH_MỤC);  
      revert IAccessControl.AccessControlUnauthorizedAccount(msg.sender, PORTFOLIO_MANAGER);  
    // }  
    }  
  // }  
  }  
  
  /// @notice Reverts unless caller holds PORTFOLIO_MANAGER, ADMIN_ROLE, or GUARDIAN_ROLE  
  // Hoàn_tác trừ_khi người_gọi nắm_giữ NGƯỜI_QUẢN_LÝ_DANH_MỤC, VAI_TRÒ_QUẢN_TRỊ, hoặc VAI_TRÒ_NGƯỜI_GIÁM_HỘ  
  // hàm _yêuCầuNgườiQuảnLýSổĐịaChỉ() nội_bộ xem {  
  function _requireAddressBookManager() internal view {  
    // nếu (!cóVaiTrò(NGƯỜI_QUẢN_LÝ_DANH_MỤC, msg.người_gửi) && !_làQuảnTrịViênHoặcNgườiGiámHộ(msg.người_gửi)) {  
    if (!hasRole(PORTFOLIO_MANAGER, msg.sender) && !_isAdminOrGuardian(msg.sender)) {  
      // hoàn_tác IAccessControl.TàiKhoảnKhôngĐượcPhépKiểmSoátTruyCập(msg.người_gửi, NGƯỜI_QUẢN_LÝ_DANH_MỤC);  
      revert IAccessControl.AccessControlUnauthorizedAccount(msg.sender, PORTFOLIO_MANAGER);  
    // }  
    }  
  // }  
  }  
  
  /**  
   * @dev Reverts if the account is not a verified investor. Uses `SHAREHOLDER_ROLE` on the share  
   * @dev Hoàn_tác nếu tài_khoản không phải nhà_đầu_tư đã_xác_minh. Sử_dụng `VAI_TRÒ_CỔ_ĐÔNG` trên  
   *      token as the investor verification mechanism: shareholders are automatically considered  
   *      token cổ_phần làm cơ_chế xác_minh nhà_đầu_tư: các cổ_đông được tự_động coi là  
   *      verified investors.  
   *      nhà_đầu_tư đã_xác_minh.  
   */  
  // hàm _yêuCầuNhàĐầuTư(địa_chỉ tài_khoản) nội_bộ xem {  
  function _requireInvestor(address account) internal view {  
    // yêu_cầu(tokenCổPhần.cóVaiTrò(tokenCổPhần.VAI_TRÒ_CỔ_ĐÔNG(), tài_khoản), KhôngPhảiCổĐông());  
    require(shareToken.hasRole(shareToken.SHAREHOLDER_ROLE(), account), NotShareholder());  
  // }  
  }

}
