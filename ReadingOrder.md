Dưới đây là thứ tự đọc được đề xuất, từ nền tảng đến chi tiết:

---

## Bước 1: Hiểu domain & kế toán (đọc specs trước)

Trước khi đọc bất kỳ Solidity nào, đọc spec để hiểu mô hình tư duy:

1. `specs/ledger/ledger.md` — hiểu hệ thống double-entry ledger, sign convention
2. `contracts/interfaces/Accounts.sol` — 20 tài khoản ledger, phân nhóm dương/âm
3. `contracts/interfaces/LedgerEntries.sol` — 23 loại entry, mỗi entry = 1 thao tác nghiệp vụ [1](#2-0) [2](#2-1) 

---

## Bước 2: Hiểu data model (interfaces chứa enums/structs)

Đọc interfaces trước implementations — chúng ngắn hơn và cho thấy "hình dạng" của dữ liệu:

4. `contracts/interfaces/ILoans.sol` — `Roles`, `LoanStatus`, `LoanData`, `LoanTerms`, `Entry`
5. `contracts/interfaces/ILoansNFT.sol` — `ILockable` (ERC-5753 locking)
6. `contracts/interfaces/ILoansExchange.sol` — `SaleOffer` struct
7. `contracts/interfaces/INavCalculator.sol` — `ValuationBucket` enum
8. `contracts/interfaces/IPortfolioVault.sol` — extends `IERC7540`
9. `contracts/interfaces/IVaultShareToken.sol` — ERC-20 + ERC-1404
10. `contracts/interfaces/ITrustedCalls.sol` — delegate call whitelist
11. `contracts/interfaces/ITrustedSpender.sol` — `Allowance` struct
12. `contracts/interfaces/ISmartAccountFactory.sol` — factory interface [3](#2-2) 

---

## Bước 3: Shared infrastructure (base contracts)

Tất cả contract chính đều kế thừa từ đây — đọc một lần, hiểu mọi nơi:

13. `contracts/misc/interfaces/IGuardianAccessControl.sol` → rồi `contracts/misc/GuardianAccessControl.sol`
14. `contracts/misc/interfaces/ILoansAuth.sol` → rồi `contracts/misc/LoansAuth.sol`
15. `contracts/misc/interfaces/IRescuable.sol` → rồi `contracts/misc/Rescuable.sol` [4](#2-3) [5](#2-4) 

---

## Bước 4: Lending Core (trái tim của protocol)

Đọc theo thứ tự kế thừa — base trước, derived sau:

16. `contracts/LoansLedger.sol` — engine ghi sổ, không có logic nghiệp vụ
17. `contracts/Loans.sol` — contract chính, kế thừa `LoansLedger` + `LoansAuth`
18. `contracts/LoansNFT.sol` — ERC-721 + locking mechanism
19. `contracts/LoansExchange.sol` — thị trường thứ cấp OTC

---

## Bước 5: Portfolio Management

20. `contracts/NavCalculator.sol` — định giá loan theo DPD bucket
21. `contracts/misc/interfaces/IERC7540.sol` + `IERC7575.sol` — hiểu async vault standard trước
22. `contracts/VaultShareToken.sol` — share token ERC-1404
23. `contracts/PortfolioVault.sol` — vault tổng hợp (phức tạp nhất, đọc cuối) [6](#2-5) 

---

## Bước 6: Account Infrastructure

24. `contracts/misc/interfaces/ISafe.sol` + `IModuleManager.sol` — hiểu Gnosis Safe API
25. `contracts/TrustedCalls.sol`
26. `contracts/TrustedSpender.sol`
27. `contracts/SmartAccountFactory.sol`

---

## Tóm tắt thứ tự

```
specs → Accounts.sol → LedgerEntries.sol
  → interfaces (ILoans, ILoansNFT, ILoansExchange, ...)
  → misc base (GuardianAccessControl, LoansAuth, Rescuable)
  → LoansLedger → Loans → LoansNFT → LoansExchange
  → NavCalculator → VaultShareToken → PortfolioVault
  → TrustedCalls → TrustedSpender → SmartAccountFactory
```

**Nguyên tắc chung**: luôn đọc interface trước implementation, đọc base contract trước derived contract, đọc contract đơn giản (ít dependency) trước contract phức tạp. `PortfolioVault.sol` và `Loans.sol` là 2 file phức tạp nhất — để cuối cùng khi đã có đủ context.


```
