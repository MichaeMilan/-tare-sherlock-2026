Dưới đây là lịch trình audit theo thứ tự từ dưới lên (bottom-up), dựa trên đồ thị phụ thuộc thực tế của codebase:

---

## Lịch trình Audit — Tare Protocol

### Phase 1 — Data Definitions (Không có logic, đọc để xây dựng mental model)

| #   | File                           | Lý do                                                                                                              |
| --- | ------------------------------ | ------------------------------------------------------------------------------------------------------------------ | ------------------- |
| 1   | `interfaces/Accounts.sol`      | Định nghĩa hằng số account (`ACC_CASH`, `ACC_UNFUNDED_COMMITMENT`…). Mọi entry trong ledger đều dùng các hằng này. |
| 2   | `interfaces/LedgerEntries.sol` | Định nghĩa hằng số `entryType`. Cần hiểu trước khi đọc `Loans.sol`.                                                | [1](#0-0) [2](#0-1) |

---

### Phase 2 — Interfaces (Xác định attack surface, không có implementation)

| #   | File                                         | Lý do                                                                                                                                        |
| --- | -------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- | --------- |
| 3   | `interfaces/ILoans.sol`                      | Định nghĩa toàn bộ enum `LoanStatus`, `Roles`, struct `Entry`, `LoanData`, `LoanTerms` và interface `ILoans`. Đây là trung tâm của protocol. |
| 4   | `interfaces/ILoansNFT.sol`                   | Interface ERC-5753 locking — cần hiểu trước khi đọc `LoansNFT.sol` và `LoansExchange.sol`.                                                   |
| 5   | `interfaces/ILoansExchange.sol`              | Struct `SaleOffer` và interface exchange.                                                                                                    |
| 6   | `interfaces/INavCalculator.sol`              | Interface NAV calculator.                                                                                                                    |
| 7   | `interfaces/IPortfolioVault.sol`             | Interface vault (ERC-7540).                                                                                                                  |
| 8   | `interfaces/IVaultShareToken.sol`            | Interface share token (ERC-1404).                                                                                                            |
| 9   | `interfaces/IERC1404.sol`                    | Standard ERC-1404 transfer restriction.                                                                                                      |
| 10  | `interfaces/ISmartAccountFactory.sol`        | Interface factory.                                                                                                                           |
| 11  | `interfaces/ITrustedCalls.sol`               | Interface Safe module.                                                                                                                       |
| 12  | `interfaces/ITrustedSpender.sol`             | Interface spender module.                                                                                                                    |
| 13  | `misc/interfaces/IGuardianAccessControl.sol` | Base access control interface.                                                                                                               |
| 14  | `misc/interfaces/ILoansAuth.sol`             | Address book interface.                                                                                                                      |
| 15  | `misc/interfaces/IModuleManager.sol`         | Gnosis Safe module manager interface.                                                                                                        |
| 16  | `misc/interfaces/IRescuable.sol`             | Token rescue interface.                                                                                                                      |
| 17  | `misc/interfaces/ISafe.sol`                  | Gnosis Safe setup interface.                                                                                                                 |
| 18  | `misc/interfaces/IERC7540.sol`               | ERC-7540 async vault interface.                                                                                                              |
| 19  | `misc/interfaces/IERC7575.sol`               | ERC-7575 vault interface.                                                                                                                    | [3](#0-2) |

---

### Phase 3 — Access Control Foundation (Bảo mật nền tảng — audit kỹ)

| #   | File                             | Lý do                                                                      | Điểm cần chú ý                                                                                                                           |
| --- | -------------------------------- | -------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | ------------------- |
| 20  | `misc/GuardianAccessControl.sol` | Base của **mọi** contract trong protocol. Sai ở đây ảnh hưởng toàn bộ.     | `_revokeRole` với `LastGuardian` guard; `renounceRole` bị disable; `pause`/`unpause` asymmetry.                                          |
| 21  | `misc/Rescuable.sol`             | Kế thừa `GuardianAccessControl`. Cho phép guardian rút token bất kỳ.       | Kiểm tra `rescueERC20Tokens` có thể rút token đang custody của loan không.                                                               |
| 22  | `misc/LoansAuth.sol`             | Address book RBAC — kiểm soát ai được tạo loan, ai là servicer/originator. | `registerAddress` không có access control (bất kỳ ai cũng tự đăng ký role cho mình). `approveOriginator`/`approveServicer` chỉ guardian. | [4](#0-3) [5](#0-4) |

---

### Phase 4 — Core Lending (Phức tạp nhất, giá trị cao nhất — dành nhiều thời gian nhất)

| #   | File              | Lý do                                                                                | Điểm cần chú ý                                                                                                                                     |
| --- | ----------------- | ------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------- |
| 23  | `LoansLedger.sol` | Lớp storage và primitive của double-entry ledger. Mọi mutation tài chính đi qua đây. | `_updateBalances`: chỉ check `ACC_CASH >= 0`, các account khác không bị chặn âm. `_deposit`/`_withdraw` flow.                                      |
| 24  | `Loans.sol`       | Contract trung tâm: lifecycle loan, custody tiền, waterfall.                         | `applyWaterfall` logic phân bổ; `investorWithdraw` batch với lock/unlock path; `disburse` kiểm tra commitment; `createLedgerEntries` escape hatch. |
| 25  | `LoansNFT.sol`    | ERC-721 với ERC-5753 locking. NFT đại diện quyền sở hữu loan.                        | `_update` override: logic `isLocked && auth != unlocker`; `getApproved` trả về unlocker khi locked; `forceTransfer` bypass approval.               | [6](#0-5) [7](#0-6) [8](#0-7) |

---

### Phase 5 — Secondary Market

| #   | File                | Lý do                                                                  | Điểm cần chú ý                                                                                                                                                             |
| --- | ------------------- | ---------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------- |
| 26  | `LoansExchange.sol` | Peer-to-peer NFT exchange. Tương tác với `LoansNFT` locking mechanism. | `acceptOffer`: NFT transfer trước, tiền sau — kiểm tra reentrancy; double-check `isRegisteredForRole` cả hai chiều buyer/seller; `_removeOffer` delete trước khi transfer. | [9](#0-8) |

---

### Phase 6 — Portfolio Layer (ERC-7540 complexity)

| #   | File                  | Lý do                                                                                                       | Điểm cần chú ý                                                                                                                                                                                                             |
| --- | --------------------- | ----------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------- |
| 27  | `NavCalculator.sol`   | Định giá loan theo DPD bucket. Ảnh hưởng trực tiếp đến share price.                                         | `_bucketFactor`: `nextDueDate == 0` → luôn `Current`; `portfolioFactor` có thể > 1e18 (tối đa `maxPortfolioFactor`).                                                                                                       |
| 28  | `VaultShareToken.sol` | ERC-20 restricted (ERC-1404). Mint/burn chỉ vault.                                                          | `setVault` không revoke `SHAREHOLDER_ROLE` của vault cũ; `_update` enforcement path.                                                                                                                                       |
| 29  | `PortfolioVault.sol`  | Contract phức tạp nhất: NAV computation, ERC-7540 async deposit/redeem, loan funding, exchange integration. | `updateNav` restart logic; `approveDeposit`/`approveRedemption` share price math (rounding); `_requireFreshNav` staleness checks; `idleLiquidity` accounting; `lastNav` mutation tại `approveDeposit`/`approveRedemption`. | [10](#0-9) [11](#0-10) [12](#0-11) |

---

### Phase 7 — Smart Account Infrastructure

| #   | File                      | Lý do                                                     | Điểm cần chú ý                                                                                                                                                                                 |
| --- | ------------------------- | --------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------- |
| 30  | `TrustedCalls.sol`        | Safe module cho phép delegate thực thi whitelisted calls. | `executeTrustedCall`: chỉ check selector whitelist, không check calldata parameters — delegate có thể gọi bất kỳ argument nào; `addDelegate` chỉ cần `safeOrGuardian` (Safe tự thêm delegate). |
| 31  | `TrustedSpender.sol`      | Quản lý ERC-20/ERC-721 allowance có expiry.               | `executeTransfer`: không check `to` address — delegate có thể chuyển đến bất kỳ địa chỉ nào miễn là có allowance; `uint208` overflow khi `amount > type(uint208).max`.                         |
| 32  | `SmartAccountFactory.sol` | Deploy Safe với module + allowance pre-configured.        | `configureSmartAccount` chạy qua delegatecall từ Safe setup — `_setConfigured` dùng custom storage slot để chống replay; `CONFIGURED_SLOT` collision risk.                                     | [13](#0-12) [14](#0-13) |

---

## Tóm tắt thứ tự ưu tiên

```
Phase 1-2 (Interfaces)     → Đọc nhanh, xây dựng mental model
Phase 3 (Access Control)   → Audit kỹ, lỗi ở đây ảnh hưởng toàn bộ
Phase 4 (Core Lending)     → Dành nhiều thời gian nhất (Loans.sol ~988 dòng)
Phase 5 (Exchange)         → Tập trung vào settlement atomicity
Phase 6 (Portfolio Vault)  → Phức tạp thứ hai (PortfolioVault.sol ~1147 dòng)
Phase 7 (Smart Accounts)   → Tập trung vào Safe module trust model
```

**Các khu vực rủi ro cao nhất cần ưu tiên:**

- `Loans.sol` — custody tiền thực, waterfall logic, escape hatch `createLedgerEntries`
- `PortfolioVault.sol` — NAV manipulation, share price rounding, ERC-7540 state machine
- `LoansAuth.sol` — `registerAddress` không có access control (intentional design nhưng cần verify)
- `TrustedCalls.sol` — delegate có full parameter control trên whitelisted selectors
