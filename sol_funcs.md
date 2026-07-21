# Solidity Function Signatures

## File: `tare-io__tare-contracts/contracts/interfaces/Accounts.sol`

*No contracts or functions found.*

## File: `tare-io__tare-contracts/contracts/interfaces/IERC1404.sol`

### interface IERC1404
> **Total functions:** 2 | **Audited:** 0/2

- **detectTransferRestriction**(address from, address to, uint256 value) **external** **view** returns (uint8) `<<0>>`

- **messageForTransferRestriction**(uint8 restrictionCode) **external** **view** returns (string memory) `<<0>>`

> **Functions:** detectTransferRestriction, messageForTransferRestriction


## File: `tare-io__tare-contracts/contracts/interfaces/ILoansExchange.sol`

### interface ILoansExchange
> **Total functions:** 10 | **Audited:** 0/10

- **acceptOffer**(uint64 offerId) **external** `<<0>>`

- **cancelOffer**(uint64 offerId) **external** `<<0>>`

- **createOffer**( address buyer, uint128 price, uint48 deadline, uint64[] calldata loanIds ) **external** returns (uint64 offerId) `<<0>>`

- **forceCancelOffer**(uint64 offerId) **external** `<<0>>`

- **setMaxLoansPerOffer**(uint64 newMax) **external** `<<0>>`

- **CURRENCY**() **external** **view** returns (IERC20) `<<0>>`

- **getOffer**(uint64 offerId) **external** **view** returns (SaleOffer memory) `<<0>>`

- **LOANS_NFT**() **external** **view** returns (ILoansNFT) `<<0>>`

- **LOANS**() **external** **view** returns (ILoans) `<<0>>`

- **maxLoansPerOffer**() **external** **view** returns (uint64) `<<0>>`

> **Functions:** acceptOffer, cancelOffer, createOffer, forceCancelOffer, setMaxLoansPerOffer, CURRENCY, getOffer, LOANS_NFT, LOANS, maxLoansPerOffer


## File: `tare-io__tare-contracts/contracts/interfaces/ILoansNFT.sol`

### interface ILoansNFT
> **Total functions:** 6 | **Audited:** 0/6

- **forceTransfer**(address from, address to, uint256 tokenId) **external** `<<0>>`

- **mint**(address to, uint256 tokenId) **external** `<<0>>`

- **setBaseURI**(string calldata newBaseURI) **external** `<<0>>`

- **LOANS_CONTRACT**() **external** **view** returns (address loansContract) `<<0>>`

- **ownerAndUnlocker**(uint256 tokenId) **external** **view** returns (address owner, address unlocker) `<<0>>`

- **ownershipNonce**(address account) **external** **view** returns (uint256 nonce) `<<0>>`

> **Functions:** forceTransfer, mint, setBaseURI, LOANS_CONTRACT, ownerAndUnlocker, ownershipNonce


### interface ILockable
> **Total functions:** 3 | **Audited:** 0/3

- **lock**(address unlocker, uint256 id) **external** `<<0>>`

- **unlock**(uint256 id) **external** `<<0>>`

- **getLocked**(uint256 tokenId) **external** **view** returns (address unlocker) `<<0>>`

> **Functions:** lock, unlock, getLocked


## File: `tare-io__tare-contracts/contracts/interfaces/ILoans.sol`

### interface ILoans
> **Total functions:** 34 | **Audited:** 0/34

- **accrue**(uint64 loanId, int128 amount, uint48 timestamp, bytes32 ref) **external** `<<0>>`

- **applyWaterfall**( uint64 loanId, int128 miscFees, int128 servicingFees, int128 investorInterest, int128 principal, uint48 nextDueDate, uint48 timestamp, bytes32 ref ) **external** `<<0>>`

- **chargeMiscFee**(uint64 loanId, int128 amount, uint48 timestamp, bytes32 ref) **external** `<<0>>`

- **create**( address borrower, address investor, address servicer, address originator, int128 principalAmount, uint48 timestamp ) **external** returns (uint64 loanId) `<<0>>`

- **createLedgerEntries**( uint64 loanId, uint48 timestamp, LedgerEntryInput[] calldata ledgerEntries ) **external** returns (uint128[] memory entryIndices) `<<0>>`

- **disburse**( uint64 loanId, int128 netDisbursedAmount, int128 originationFee, uint48 originationDate, uint48 nextDueDate, uint48 maturityDate, uint32 interestRate, int128 expectedMonthlyPayment, uint48 timestamp, bytes32 ref ) **external** returns (uint128 entryIndex) `<<0>>`

- **fund**(uint64 loanId, int128 amount, uint48 timestamp, bytes32 ref) **external** returns (uint128 entryIndex) `<<0>>`

- **investorWithdraw**( uint64[] calldata loanIds, uint48 timestamp, bytes32 ref ) **external** returns (InvestorWithdrawalResult[] memory) `<<0>>`

- **originatorWithdraw**( uint64[] calldata loanIds, uint48 timestamp, bytes32 ref ) **external** returns (OriginatorWithdrawalResult[] memory) `<<0>>`

- **pay**(uint64 loanId, int128 amount, uint48 timestamp, bytes32 ref) **external** returns (uint128 entryIndex) `<<0>>`

- **refundBorrower**( uint64 loanId, uint8 toAccount, int128 amount, uint48 timestamp, uint16 entryType, bytes32 ref ) **external** returns (uint128 entryIndex) `<<0>>`

- **returnFunds**( uint64 loanId, uint8 from, int128 amount, uint48 timestamp, uint16 entryType, bytes32 ref ) **external** returns (uint128 entryIndex) `<<0>>`

- **servicerWithdraw**( uint64[] calldata loanIds, uint48 timestamp, bytes32 ref ) **external** returns (ServicerWithdrawalResult[] memory) `<<0>>`

- **setLoansNFT**(address _loansNFT) **external** `<<0>>`

- **updateBorrower**(uint64 loanId, address borrower) **external** `<<0>>`

- **updateLoanData**( uint64 loanId, LoanStatus status, uint48 nextDueDate, uint48 maturityDate, uint48 timestamp ) **external** `<<0>>`

- **updateLoanTerms**( uint64 loanId, uint48 originationDate, uint32 interestRate, int128 expectedMonthlyPayment ) **external** `<<0>>`

- **updateServicer**(uint64 loanId, address servicer) **external** `<<0>>`

- **accountBalances**(uint72 key) **external** **view** returns (int128) `<<0>>`

- **borrowers**(uint64 loanId) **external** **view** returns (address) `<<0>>`

- **currency**() **external** **view** returns (IERC20) `<<0>>`

- **data**( uint64 loanId ) **external** **view** returns (LoanStatus status, uint48 updatedAt, uint48 lastPaymentDate, uint48 nextDueDate, uint48 maturityDate) `<<0>>`

- **entries**( uint128 entryIndex ) **external** **view** returns (int128 amount, uint48 timestamp, uint8 from, uint8 to, uint16 entryType, bytes32 ref) `<<0>>`

- **entryCount**(uint64 loanId) **external** **view** returns (uint64) `<<0>>`

- **getLoanAccountBalance**(uint64 loanId, uint8 account) **external** **view** returns (int128) `<<0>>`

- **getLoanAccountBalanceNormalized**(uint64 loanId, uint8 account) **external** **view** returns (int128) `<<0>>`

- **getLoanEntries**(uint64 loanId, uint64 startIndex, uint64 endIndex) **external** **view** returns (Entry[] memory) `<<0>>`

- **getLoanEntry**(uint64 loanId, uint64 entryNumber) **external** **view** returns (Entry memory) `<<0>>`

- **getLoanValues**(uint64[] calldata loanIds) **external** **view** returns (LoanValue[] memory) `<<0>>`

- **loanCount**() **external** **view** returns (uint64) `<<0>>`

- **loansNFT**() **external** **view** returns (ILoansNFT) `<<0>>`

- **loanTerms**( uint64 loanId ) **external** **view** returns (uint48 originationDate, uint32 interestRate, int128 expectedMonthlyPayment) `<<0>>`

- **originators**(uint64 loanId) **external** **view** returns (address) `<<0>>`

- **servicers**(uint64 loanId) **external** **view** returns (address) `<<0>>`

> **Functions:** accrue, applyWaterfall, chargeMiscFee, create, createLedgerEntries, disburse, fund, investorWithdraw, originatorWithdraw, pay, refundBorrower, returnFunds, servicerWithdraw, setLoansNFT, updateBorrower, updateLoanData, updateLoanTerms, updateServicer, accountBalances, borrowers, currency, data, entries, entryCount, getLoanAccountBalance, getLoanAccountBalanceNormalized, getLoanEntries, getLoanEntry, getLoanValues, loanCount, loansNFT, loanTerms, originators, servicers


## File: `tare-io__tare-contracts/contracts/interfaces/INavCalculator.sol`

### interface INavCalculator
> **Total functions:** 9 | **Audited:** 0/9

- **setDiscountFactor**(ValuationBucket bucket, uint256 factor) **external** `<<0>>`

- **setMaxPortfolioFactor**(uint256 newMax) **external** `<<0>>`

- **setPortfolioFactor**(uint256 factor) **external** `<<0>>`

- **applyPortfolioAdjustment**(uint256 rawValue) **external** **view** returns (uint256 adjustedValue) `<<0>>`

- **configurationVersion**() **external** **view** returns (uint256) `<<0>>`

- **getDiscountFactor**(ValuationBucket bucket) **external** **view** returns (uint256 factor) `<<0>>`

- **getLoansValue**(ILoans loans, uint64[] calldata loanIds) **external** **view** returns (uint256 totalValue) `<<0>>`

- **maxPortfolioFactor**() **external** **view** returns (uint256) `<<0>>`

- **portfolioFactor**() **external** **view** returns (uint256) `<<0>>`

> **Functions:** setDiscountFactor, setMaxPortfolioFactor, setPortfolioFactor, applyPortfolioAdjustment, configurationVersion, getDiscountFactor, getLoansValue, maxPortfolioFactor, portfolioFactor


## File: `tare-io__tare-contracts/contracts/interfaces/IPortfolioVault.sol`

### interface IPortfolioVault
> **Total functions:** 31 | **Audited:** 0/31

- **acceptSaleOffer**(uint64 offerId) **external** `<<0>>`

- **addLoansToNav**(uint64[] calldata loanIds) **external** `<<0>>`

- **approveDeposit**(address controller, uint256 assets) **external** returns (uint256 shares) `<<0>>`

- **approveRedemption**(address controller, uint256 shares) **external** returns (uint256 assets) `<<0>>`

- **cancelDepositRequest**(address controller, address receiver) **external** returns (uint256 assets) `<<0>>`

- **cancelRedeemRequest**(address controller, address receiver) **external** returns (uint256 shares) `<<0>>`

- **cancelSaleOffer**(uint64 offerId) **external** `<<0>>`

- **collectCashflows**( uint64[] calldata loanIds, bytes32 ref ) **external** returns (InvestorWithdrawalResult[] memory loanWithdrawals) `<<0>>`

- **createSaleOffer**( address buyer, uint128 price, uint48 deadline, uint64[] calldata loanIds ) **external** returns (uint64 offerId) `<<0>>`

- **fundLoan**(uint64 loanId, int128 amount, uint48 timestamp, bytes32 ref) **external** `<<0>>`

- **fundLoans**(uint64[] calldata loanIds, int128[] calldata amounts, uint48 timestamp, bytes32 ref) **external** `<<0>>`

- **registerAddress**(address addr) **external** `<<0>>`

- **removeLoansFromNav**(uint64[] calldata loanIds) **external** `<<0>>`

- **setCalculator**(address _calculator) **external** `<<0>>`

- **setExchange**(address _exchange) **external** `<<0>>`

- **setLoans**(address _loans, address _loansNFT) **external** `<<0>>`

- **setMaxNavAge**(uint256 _maxNavAge) **external** `<<0>>`

- **setMaxNavComputationTime**(uint256 _maxNavComputationTime) **external** `<<0>>`

- **transferLoans**(uint64[] calldata loanIds, address recipient) **external** `<<0>>`

- **unregisterAddress**(address addr) **external** `<<0>>`

- **updateNav**(uint256 batchSize) **external** `<<0>>`

- **calculator**() **external** **view** returns (INavCalculator) `<<0>>`

- **isInNav**(uint64 loanId) **external** **view** returns (bool) `<<0>>`

- **lastNavUpdate**() **external** **view** returns (uint256) `<<0>>`

- **maxNavAge**() **external** **view** returns (uint256) `<<0>>`

- **maxNavComputationTime**() **external** **view** returns (uint256) `<<0>>`

- **nav**() **external** **view** returns (uint256) `<<0>>`

- **navLoanCount**() **external** **view** returns (uint256) `<<0>>`

- **navLoanIdAt**(uint256 index) **external** **view** returns (uint64) `<<0>>`

- **navStart**() **external** **view** returns (uint256) `<<0>>`

- **sharePrice**() **external** **view** returns (uint256 price) `<<0>>`

> **Functions:** acceptSaleOffer, addLoansToNav, approveDeposit, approveRedemption, cancelDepositRequest, cancelRedeemRequest, cancelSaleOffer, collectCashflows, createSaleOffer, fundLoan, fundLoans, registerAddress, removeLoansFromNav, setCalculator, setExchange, setLoans, setMaxNavAge, setMaxNavComputationTime, transferLoans, unregisterAddress, updateNav, calculator, isInNav, lastNavUpdate, maxNavAge, maxNavComputationTime, nav, navLoanCount, navLoanIdAt, navStart, sharePrice


## File: `tare-io__tare-contracts/contracts/interfaces/ISmartAccountFactory.sol`

### interface ISmartAccountFactory
> **Total functions:** 5 | **Audited:** 0/5

- **configureSmartAccount**( address[] memory delegates, address[] memory currencies, address[] memory nftCollections, address[] memory trustedRecipients, uint48 validUntil ) **external** `<<0>>`

- **deploySmartAccount**( address[] memory delegates, address[] memory currencies, address[] memory nftCollections, address[] memory trustedRecipients, uint48 validUntil, address[] memory owners, uint256 threshold ) **external** returns (address) `<<0>>`

- **isDeployedSmartAccount**(address account) **external** **view** returns (bool deployed) `<<0>>`

- **nonces**(address deployer) **external** **view** returns (uint256 nonce) `<<0>>`

- **predictSmartAccountAddress**( address deployer, uint256 _nonce, address[] memory delegates, address[] memory currencies, address[] memory nftCollections, address[] memory trustedRecipients, uint48 validUntil, address[] memory owners, uint256 threshold ) **external** **view** returns (address) `<<0>>`

> **Functions:** configureSmartAccount, deploySmartAccount, isDeployedSmartAccount, nonces, predictSmartAccountAddress


## File: `tare-io__tare-contracts/contracts/interfaces/ITrustedCalls.sol`

### interface ITrustedCalls
> **Total functions:** 12 | **Audited:** 0/12

- **addDelegate**(address safe, address delegate) **external** `<<0>>`

- **addTrustedCall**(address target, bytes4 selector) **external** `<<0>>`

- **addTrustedCalls**(address[] calldata targets, bytes4[] calldata selectors) **external** `<<0>>`

- **executeTrustedCall**( address safe, address target, bytes calldata data ) **external** returns (bool success, bytes memory returnData) `<<0>>`

- **executeTrustedCallBatch**( address safe, address[] calldata targets, bytes[] calldata data ) **external** returns (bytes[] memory results) `<<0>>`

- **removeDelegate**(address safe, address delegate) **external** `<<0>>`

- **removeTrustedCall**(address target, bytes4 selector) **external** `<<0>>`

- **delegates**(address safe, address delegate) **external** **view** returns (bool authorized) `<<0>>`

- **getTrustKey**(address target, bytes4 selector) **external** **pure** returns (bytes32) `<<0>>`

- **isDelegate**(address safe, address delegate) **external** **view** returns (bool) `<<0>>`

- **isTrustedCall**(address target, bytes4 selector) **external** **view** returns (bool) `<<0>>`

- **trustedCalls**(bytes32 trustKey) **external** **view** returns (bool isTrusted) `<<0>>`

> **Functions:** addDelegate, addTrustedCall, addTrustedCalls, executeTrustedCall, executeTrustedCallBatch, removeDelegate, removeTrustedCall, delegates, getTrustKey, isDelegate, isTrustedCall, trustedCalls


## File: `tare-io__tare-contracts/contracts/interfaces/ITrustedSpender.sol`

### interface ITrustedSpender
> **Total functions:** 11 | **Audited:** 0/11

- **addDelegate**(address safe, address delegate) **external** `<<0>>`

- **executeNFTTransfer**(address collection, address from, address to, uint256 tokenId) **external** `<<0>>`

- **executeTransfer**(address token, address from, address to, uint256 amount) **external** `<<0>>`

- **removeDelegate**(address safe, address delegate) **external** `<<0>>`

- **setAllowance**(address token, address from, address to, uint208 amount, uint48 validUntil) **external** `<<0>>`

- **setNFTAllowance**(address collection, address from, address to, bool allowed, uint48 validUntil) **external** `<<0>>`

- **delegates**(address safe, address delegate) **external** **view** returns (bool authorized) `<<0>>`

- **getAllowance**( address token, address from, address to ) **external** **view** returns (uint256 amount, uint48 validUntil) `<<0>>`

- **getNFTAllowance**( address collection, address from, address to ) **external** **view** returns (bool allowed, uint48 validUntil) `<<0>>`

- **isDelegate**(address safe, address delegate) **external** **view** returns (bool) `<<0>>`

- **isNFTTransferAllowed**(address collection, address from, address to) **external** **view** returns (bool) `<<0>>`

> **Functions:** addDelegate, executeNFTTransfer, executeTransfer, removeDelegate, setAllowance, setNFTAllowance, delegates, getAllowance, getNFTAllowance, isDelegate, isNFTTransferAllowed


## File: `tare-io__tare-contracts/contracts/interfaces/IVaultShareToken.sol`

### interface IVaultShareToken
> **Total functions:** 8 | **Audited:** 0/8

- **burn**(address from, uint256 amount) **external** `<<0>>`

- **mint**(address to, uint256 amount) **external** `<<0>>`

- **setVault**(address newVault) **external** `<<0>>`

- **BURNER_ROLE**() **external** **view** returns (bytes32) `<<0>>`

- **MINTER_ROLE**() **external** **view** returns (bytes32) `<<0>>`

- **SHAREHOLDER_ROLE**() **external** **view** returns (bytes32) `<<0>>`

- **vault**(address asset) **external** **view** returns (address) `<<0>>`

- **WHITELISTER_ROLE**() **external** **view** returns (bytes32) `<<0>>`

> **Functions:** burn, mint, setVault, BURNER_ROLE, MINTER_ROLE, SHAREHOLDER_ROLE, vault, WHITELISTER_ROLE


## File: `tare-io__tare-contracts/contracts/interfaces/LedgerEntries.sol`

*No contracts or functions found.*

## File: `tare-io__tare-contracts/contracts/LoansExchange.sol`

### contract LoansExchange
> **Total functions:** 9 | **Audited:** 0/9

- **constructor**(ILoansNFT _loansNFT, ILoans _loans, address initialGuardian, address initialRecoveryAddress) `<<0>>`

- **acceptOffer**(uint64 offerId) **external** whenNotPaused nonReentrant `<<0>>`

- **cancelOffer**(uint64 offerId) **external** whenNotPaused nonReentrant `<<0>>`

- **createOffer**( address buyer, uint128 price, uint48 deadline, uint64[] calldata loanIds ) **external** whenNotPaused nonReentrant returns (uint64 offerId) `<<0>>`

- **forceCancelOffer**(uint64 offerId) **external** **onlyRole(GUARDIAN_ROLE)** nonReentrant `<<0>>`

- **setMaxLoansPerOffer**(uint64 newMax) **external** **onlyAdminOrGuardian** `<<0>>`

- **_removeOffer**(uint64 offerId) **internal** returns (uint64[] memory loanIds) `<<0>>`

- **_unlockLoans**(uint64[] memory loanIds) **internal** `<<0>>`

- **getOffer**(uint64 offerId) **external** **view** returns (SaleOffer memory) `<<0>>`

> **Functions:** constructor, acceptOffer, cancelOffer, createOffer, forceCancelOffer, setMaxLoansPerOffer, _removeOffer, _unlockLoans, getOffer


## File: `tare-io__tare-contracts/contracts/LoansLedger.sol`

### contract LoansLedger
> **Total functions:** 18 | **Audited:** 0/18

- **constructor**(IERC20 _currency, address initialGuardian) LoansAuth(initialGuardian) `<<0>>`

- **_createInternalEntry**( uint64 loanId, uint8 from, uint8 to, int128 amount, uint48 timestamp, uint16 entryType, bytes32 ref ) **internal** returns (uint128 entryIndex) `<<0>>`

- **_createNextEntryIndex**(uint64 loanId) **internal** returns (uint128) `<<0>>`

- **_deposit**( uint64 loanId, uint8 fromAccount, int128 amount, address addr, uint48 timestamp, uint16 entryType, bytes32 ref ) **internal** returns (uint128 entryIndex) `<<0>>`

- **_updateBalances**( uint64 loanId, uint8 from, uint8 to, int128 amount ) **internal** returns (int128 updatedFromBalance, int128 updatedToBalance) `<<0>>`

- **_withdraw**( uint64 loanId, uint8 toAccount, int128 amount, address withdrawalAddress, uint48 timestamp, uint16 entryType, bytes32 ref ) **internal** returns (uint128 entryIndex) `<<0>>`

- **_withdrawToAccount**( uint64 loanId, uint8 toAccount, int128 amount, uint48 timestamp, uint16 entryType, bytes32 ref ) **internal** returns (int128) `<<0>>`

- **getLoanAccountBalance**(uint64 loanId, uint8 account) **external** **view** loanExists(loanId) returns (int128) `<<0>>`

- **getLoanAccountBalanceNormalized**( uint64 loanId, uint8 account ) **external** **view** loanExists(loanId) returns (int128) `<<0>>`

- **getLoanEntries**( uint64 loanId, uint64 startIndex, uint64 endIndex ) **external** **view** loanExists(loanId) returns (Entry[] memory) `<<0>>`

- **getLoanEntry**(uint64 loanId, uint64 entryNumber) **external** **view** loanExists(loanId) returns (Entry memory) `<<0>>`

- **_getAccountBalance**(uint64 loanId, uint8 account) **internal** **view** returns (int128) `<<0>>`

- **_getBalanceKey**(uint64 loanId, uint8 account) **internal** **pure** returns (uint72) `<<0>>`

- **_getNetInterestPayableToInvestor**(uint64 loanId) **internal** **view** returns (int128) `<<0>>`

- **_getNetPayable**(uint64 loanId, uint8 payableAccount, uint8 paidAccount) **internal** **view** returns (int128) `<<0>>`

- **_getNetPrincipalPayableToInvestor**(uint64 loanId) **internal** **view** returns (int128) `<<0>>`

- **_isNormallyNegative**(uint8 account) **internal** **pure** returns (bool) `<<0>>`

- **_loanExists**(uint64 loanId) **internal** **view** `<<0>>`

> **Functions:** constructor, _createInternalEntry, _createNextEntryIndex, _deposit, _updateBalances, _withdraw, _withdrawToAccount, getLoanAccountBalance, getLoanAccountBalanceNormalized, getLoanEntries, getLoanEntry, _getAccountBalance, _getBalanceKey, _getNetInterestPayableToInvestor, _getNetPayable, _getNetPrincipalPayableToInvestor, _isNormallyNegative, _loanExists


## File: `tare-io__tare-contracts/contracts/LoansNFT.sol`

### contract LoansNFT
> **Total functions:** 13 | **Audited:** 0/13

- **constructor**( address loansContract, string memory collectionName, string memory baseURI ) ERC721(collectionName, " ") `<<0>>`

- **forceTransfer**(address from, address to, uint256 tokenId) **external** `<<0>>`

- **lock**(address unlocker, uint256 id) **external** `<<0>>`

- **mint**(address to, uint256 tokenId) **external** `<<0>>`

- **setBaseURI**(string calldata newBaseURI) **external** `<<0>>`

- **unlock**(uint256 id) **external** `<<0>>`

- **approve**(address to, uint256 tokenId) **public** override(ERC721, IERC721) `<<0>>`

- **_update**(address to, uint256 tokenId, address auth) **internal** override returns (address previousOwner) `<<0>>`

- **ownerAndUnlocker**(uint256 tokenId) **external** **view** returns (address owner, address unlocker) `<<0>>`

- **getApproved**(uint256 tokenId) **public** **view** override(ERC721, IERC721) returns (address) `<<0>>`

- **getLocked**(uint256 tokenId) **public** **view** returns (address unlocker) `<<0>>`

- **supportsInterface**(bytes4 interfaceId) **public** **view** override(ERC721Enumerable, IERC165) returns (bool) `<<0>>`

- **_baseURI**() **internal** **view** override returns (string memory) `<<0>>`

> **Functions:** constructor, forceTransfer, lock, mint, setBaseURI, unlock, approve, _update, ownerAndUnlocker, getApproved, getLocked, supportsInterface, _baseURI


## File: `tare-io__tare-contracts/contracts/Loans.sol`

### contract Loans
> **Total functions:** 35 | **Audited:** 0/35

- **constructor**( IERC20 _currency, address initialGuardian, address initialRecoveryAddress ) LoansLedger(_currency, initialGuardian) `<<0>>`

- **accrue**( uint64 loanId, int128 amount, uint48 timestamp, bytes32 ref ) **external** whenNotPaused **onlyServicerOrAdmin(loanId)** **onlyOutstanding(loanId)** withLoanUpdate(loanId, timestamp) `<<0>>`

- **applyWaterfall**( uint64 loanId, int128 miscFees, int128 servicingFees, int128 investorInterest, int128 principal, uint48 nextDueDate, uint48 timestamp, bytes32 ref ) **external** whenNotPaused **onlyServicerOrAdmin(loanId)** **onlyOutstandingOrFullyPaid(loanId)** withLoanUpdate(loanId, timestamp) `<<0>>`

- **chargeMiscFee**( uint64 loanId, int128 amount, uint48 timestamp, bytes32 ref ) **external** whenNotPaused **onlyServicerOrAdmin(loanId)** **onlyOutstanding(loanId)** withLoanUpdate(loanId, timestamp) `<<0>>`

- **create**( address borrower, address investor, address servicer, address originator, int128 principalAmount, uint48 timestamp ) **external** whenNotPaused returns (uint64 loanId) `<<0>>`

- **createLedgerEntries**( uint64 loanId, uint48 timestamp, LedgerEntryInput[] calldata ledgerEntries ) **external** whenNotPaused **onlyServicerOrAdmin(loanId)** loanExists(loanId) withLoanUpdate(loanId, timestamp) returns (uint128[] memory entryIndices) `<<0>>`

- **disburse**( uint64 loanId, int128 netDisbursedAmount, int128 originationFee, uint48 originationDate, uint48 nextDueDate, uint48 maturityDate, uint32 interestRate, int128 expectedMonthlyPayment, uint48 timestamp, bytes32 ref ) **external** whenNotPaused nonReentrant loanExists(loanId) withLoanUpdate(loanId, timestamp) returns (uint128 entryIndex) `<<0>>`

- **fund**( uint64 loanId, int128 amount, uint48 timestamp, bytes32 ref ) **external** whenNotPaused nonReentrant withLoanUpdate(loanId, timestamp) returns (uint128 entryIndex) `<<0>>`

- **investorWithdraw**( uint64[] calldata loanIds, uint48 timestamp, bytes32 ref ) **external** whenNotPaused nonReentrant returns (InvestorWithdrawalResult[] memory results) `<<0>>`

- **originatorWithdraw**( uint64[] calldata loanIds, uint48 timestamp, bytes32 ref ) **external** whenNotPaused nonReentrant returns (OriginatorWithdrawalResult[] memory results) `<<0>>`

- **pay**( uint64 loanId, int128 amount, uint48 timestamp, bytes32 ref ) **external** whenNotPaused **onlyBorrowerOrAdmin(loanId)** **onlyOutstanding(loanId)** nonReentrant withLoanUpdate(loanId, timestamp) returns (uint128 entryIndex) `<<0>>`

- **refundBorrower**( uint64 loanId, uint8 toAccount, int128 amount, uint48 timestamp, uint16 entryType, bytes32 ref ) **external** whenNotPaused **onlyServicerOrAdmin(loanId)** nonReentrant **onlyOutstandingOrFullyPaid(loanId)** withLoanUpdate(loanId, timestamp) returns (uint128 entryIndex) `<<0>>`

- **returnFunds**( uint64 loanId, uint8 from, int128 amount, uint48 timestamp, uint16 entryType, bytes32 ref ) **external** whenNotPaused **onlyServicerOrAdmin(loanId)** nonReentrant **onlyOutstandingOrFullyPaid(loanId)** withLoanUpdate(loanId, timestamp) returns (uint128 entryIndex) `<<0>>`

- **servicerWithdraw**( uint64[] calldata loanIds, uint48 timestamp, bytes32 ref ) **external** whenNotPaused nonReentrant returns (ServicerWithdrawalResult[] memory results) `<<0>>`

- **setLoansNFT**(address _loansNFT) **external** **onlyAdminOrGuardian** `<<0>>`

- **updateBorrower**( uint64 loanId, address borrower ) **external** whenNotPaused **onlyServicerOrAdmin(loanId)** notTerminal(loanId) `<<0>>`

- **updateLoanData**( uint64 loanId, LoanStatus status, uint48 nextDueDate, uint48 maturityDate, uint48 timestamp ) **external** whenNotPaused **onlyServicerOrAdmin(loanId)** loanExists(loanId) withLoanUpdate(loanId, timestamp) `<<0>>`

- **updateLoanTerms**( uint64 loanId, uint48 originationDate, uint32 interestRate, int128 expectedMonthlyPayment ) **external** whenNotPaused **onlyServicerOrAdmin(loanId)** loanExists(loanId) notTerminal(loanId) `<<0>>`

- **updateServicer**( uint64 loanId, address servicer ) **external** whenNotPaused **onlyRole(GUARDIAN_ROLE)** notTerminal(loanId) `<<0>>`

- **_accrue**(uint64 loanId, int128 amount, uint48 timestamp, bytes32 ref) **internal** `<<0>>`

- **_create**( address borrower, address investor, address servicer, address originator, int128 principalAmount, uint48 timestamp ) **internal** returns (uint64 loanId) `<<0>>`

- **_disburse**( uint64 loanId, int128 netDisbursedAmount, int128 originationFee, uint48 timestamp, bytes32 ref ) **internal** returns (uint128 entryIndex) `<<0>>`

- **_processInvestorWithdrawal**( uint64 loanId, uint48 timestamp, bytes32 ref, InvestorWithdrawalResult[] memory results, uint256 resultIndex ) **internal** returns (int128 transfer) `<<0>>`

- **_updateLoanData**(uint64 loanId, LoanStatus status, uint48 nextDueDate, uint48 maturityDate) **internal** `<<0>>`

- **_withLoanUpdate**(uint64 loanId, uint48 timestamp) **internal** `<<0>>`

- **_clearReceivableDebt**( uint64 loanId, uint8 paidAcc, uint8 receivableAcc, int128 amount, uint48 timestamp, uint16 entryType, bytes32 ref ) **private** `<<0>>`

- **_processInterestPortion**( uint64 loanId, int128 servicingFees, int128 investorInterest, uint48 timestamp, bytes32 ref ) **private** `<<0>>`

- **getLoanValues**(uint64[] calldata loanIds) **external** **view** returns (LoanValue[] memory results) `<<0>>`

- **_notTerminal**(uint64 loanId) **internal** **view** `<<0>>`

- **_onlyBorrowerOrAdmin**(uint64 loanId) **internal** **view** `<<0>>`

- **_onlyOutstanding**(uint64 loanId) **internal** **view** `<<0>>`

- **_onlyOutstandingOrFullyPaid**(uint64 loanId) **internal** **view** `<<0>>`

- **_onlyServicerOrAdmin**(uint64 loanId) **internal** **view** `<<0>>`

- **_requireBatchCaller**(address roleAddr, uint256 index, address canonical) **private** **view** returns (address) `<<0>>`

- **_requireCallerOrAdmin**(address addr) **private** **view** `<<0>>`

> **Functions:** constructor, accrue, applyWaterfall, chargeMiscFee, create, createLedgerEntries, disburse, fund, investorWithdraw, originatorWithdraw, pay, refundBorrower, returnFunds, servicerWithdraw, setLoansNFT, updateBorrower, updateLoanData, updateLoanTerms, updateServicer, _accrue, _create, _disburse, _processInvestorWithdrawal, _updateLoanData, _withLoanUpdate, _clearReceivableDebt, _processInterestPortion, getLoanValues, _notTerminal, _onlyBorrowerOrAdmin, _onlyOutstanding, _onlyOutstandingOrFullyPaid, _onlyServicerOrAdmin, _requireBatchCaller, _requireCallerOrAdmin


## File: `tare-io__tare-contracts/contracts/misc/GuardianAccessControl.sol`

### contract GuardianAccessControl
> **Total functions:** 8 | **Audited:** 0/8

- **pause**() **external** virtual `<<0>>`

- **setRoleAdmin**(bytes32 role, bytes32 adminRole) **external** **onlyRole(GUARDIAN_ROLE)** `<<0>>`

- **unpause**() **external** virtual **onlyRole(GUARDIAN_ROLE)** `<<0>>`

- **renounceRole**(bytes32, address) **public** virtual override(AccessControl, IAccessControl) `<<0>>`

- **_grantRole**(bytes32 role, address account) **internal** virtual override returns (bool granted) `<<0>>`

- **_initGuardian**(address initialGuardian) **internal** `<<0>>`

- **_revokeRole**(bytes32 role, address account) **internal** virtual override returns (bool revoked) `<<0>>`

- **_isAdminOrGuardian**(address account) **internal** **view** returns (bool) `<<0>>`

> **Functions:** pause, setRoleAdmin, unpause, renounceRole, _grantRole, _initGuardian, _revokeRole, _isAdminOrGuardian


## File: `tare-io__tare-contracts/contracts/misc/interfaces/IERC7540.sol`

### interface IERC7540Deposit
> **Total functions:** 5 | **Audited:** 0/5

- **deposit**(uint256 assets, address receiver, address controller) **external** returns (uint256 shares) `<<0>>`

- **mint**(uint256 shares, address receiver, address controller) **external** returns (uint256 assets) `<<0>>`

- **requestDeposit**(uint256 assets, address controller, address owner) **external** returns (uint256 requestId) `<<0>>`

- **claimableDepositRequest**( uint256 requestId, address controller ) **external** **view** returns (uint256 claimableAssets) `<<0>>`

- **pendingDepositRequest**(uint256 requestId, address controller) **external** **view** returns (uint256 pendingAssets) `<<0>>`

> **Functions:** deposit, mint, requestDeposit, claimableDepositRequest, pendingDepositRequest


### interface IERC7540Redeem
> **Total functions:** 3 | **Audited:** 0/3

- **requestRedeem**(uint256 shares, address controller, address owner) **external** returns (uint256 requestId) `<<0>>`

- **claimableRedeemRequest**( uint256 requestId, address controller ) **external** **view** returns (uint256 claimableShares) `<<0>>`

- **pendingRedeemRequest**(uint256 requestId, address controller) **external** **view** returns (uint256 pendingShares) `<<0>>`

> **Functions:** requestRedeem, claimableRedeemRequest, pendingRedeemRequest


### interface IERC7540Operator
> **Total functions:** 2 | **Audited:** 0/2

- **setOperator**(address operator, bool approved) **external** returns (bool) `<<0>>`

- **isOperator**(address controller, address operator) **external** **view** returns (bool status) `<<0>>`

> **Functions:** setOperator, isOperator


## File: `tare-io__tare-contracts/contracts/misc/interfaces/IERC7575.sol`

### interface IERC7575
> **Total functions:** 17 | **Audited:** 0/17

- **deposit**(uint256 assets, address receiver) **external** returns (uint256 shares) `<<0>>`

- **mint**(uint256 shares, address receiver) **external** returns (uint256 assets) `<<0>>`

- **redeem**(uint256 shares, address receiver, address owner) **external** returns (uint256 assets) `<<0>>`

- **withdraw**(uint256 assets, address receiver, address owner) **external** returns (uint256 shares) `<<0>>`

- **asset**() **external** **view** returns (address assetTokenAddress) `<<0>>`

- **convertToAssets**(uint256 shares) **external** **view** returns (uint256 assets) `<<0>>`

- **convertToShares**(uint256 assets) **external** **view** returns (uint256 shares) `<<0>>`

- **maxDeposit**(address receiver) **external** **view** returns (uint256 maxAssets) `<<0>>`

- **maxMint**(address receiver) **external** **view** returns (uint256 maxShares) `<<0>>`

- **maxRedeem**(address owner) **external** **view** returns (uint256 maxShares) `<<0>>`

- **maxWithdraw**(address owner) **external** **view** returns (uint256 maxAssets) `<<0>>`

- **previewDeposit**(uint256 assets) **external** **view** returns (uint256 shares) `<<0>>`

- **previewMint**(uint256 shares) **external** **view** returns (uint256 assets) `<<0>>`

- **previewRedeem**(uint256 shares) **external** **view** returns (uint256 assets) `<<0>>`

- **previewWithdraw**(uint256 assets) **external** **view** returns (uint256 shares) `<<0>>`

- **share**() **external** **view** returns (address shareTokenAddress) `<<0>>`

- **totalAssets**() **external** **view** returns (uint256 totalManagedAssets) `<<0>>`

> **Functions:** deposit, mint, redeem, withdraw, asset, convertToAssets, convertToShares, maxDeposit, maxMint, maxRedeem, maxWithdraw, previewDeposit, previewMint, previewRedeem, previewWithdraw, share, totalAssets


### interface IERC7575Share
> **Total functions:** 1 | **Audited:** 0/1

- **vault**(address asset) **external** **view** returns (address) `<<0>>`

> **Functions:** vault


## File: `tare-io__tare-contracts/contracts/misc/interfaces/IGuardianAccessControl.sol`

### interface IGuardianAccessControl
> **Total functions:** 3 | **Audited:** 0/3

- **ADMIN_ROLE**() **external** **view** returns (bytes32) `<<0>>`

- **GUARDIAN_ROLE**() **external** **view** returns (bytes32) `<<0>>`

- **PAUSER_ROLE**() **external** **view** returns (bytes32) `<<0>>`

> **Functions:** ADMIN_ROLE, GUARDIAN_ROLE, PAUSER_ROLE


## File: `tare-io__tare-contracts/contracts/misc/interfaces/ILoansAuth.sol`

### interface ILoansAuth
> **Total functions:** 10 | **Audited:** 0/10

- **approveOriginator**(address user) **external** `<<0>>`

- **approveServicer**(address user) **external** `<<0>>`

- **registerAddress**(Roles role, address addr) **external** `<<0>>`

- **registerAddressOnBehalfOf**(address addressBookOwner, Roles role, address addr) **external** `<<0>>`

- **revokeOriginator**(address user) **external** `<<0>>`

- **revokeServicer**(address user) **external** `<<0>>`

- **unregisterAddress**(Roles role, address addr) **external** `<<0>>`

- **unregisterAddressOnBehalfOf**(address addressBookOwner, Roles role, address addr) **external** `<<0>>`

- **addressBook**(address addressBookOwner, address addr) **external** **view** returns (uint256) `<<0>>`

- **isRegisteredForRole**(address addressBookOwner, Roles role, address addr) **external** **view** returns (bool) `<<0>>`

> **Functions:** approveOriginator, approveServicer, registerAddress, registerAddressOnBehalfOf, revokeOriginator, revokeServicer, unregisterAddress, unregisterAddressOnBehalfOf, addressBook, isRegisteredForRole


## File: `tare-io__tare-contracts/contracts/misc/interfaces/IModuleManager.sol`

### interface IModuleManager
> **Total functions:** 2 | **Audited:** 0/2

- **enableModule**(address module) **external** `<<0>>`

- **execTransactionFromModuleReturnData**( address to, uint256 value, bytes memory data, Enum.Operation operation ) **external** returns (bool success, bytes memory returnData) `<<0>>`

> **Functions:** enableModule, execTransactionFromModuleReturnData


## File: `tare-io__tare-contracts/contracts/misc/interfaces/IRescuable.sol`

### interface IRescuable
> **Total functions:** 4 | **Audited:** 0/4

- **rescueERC20Tokens**(address token, uint256 amount) **external** returns (uint256 rescued) `<<0>>`

- **rescueERC721Tokens**(address token, uint256 tokenId) **external** `<<0>>`

- **setRecoveryAddress**(address recoveryAddress_) **external** `<<0>>`

- **recoveryAddress**() **external** **view** returns (address) `<<0>>`

> **Functions:** rescueERC20Tokens, rescueERC721Tokens, setRecoveryAddress, recoveryAddress


## File: `tare-io__tare-contracts/contracts/misc/interfaces/ISafe.sol`

### interface ISafe
> **Total functions:** 9 | **Audited:** 0/9

- **approveHash**(bytes32 hashToApprove) **external** `<<0>>`

- **execTransaction**( address to, uint256 value, bytes calldata data, Enum.Operation operation, uint256 safeTxGas, uint256 baseGas, uint256 gasPrice, address gasToken, address payable refundReceiver, bytes memory signatures ) **external** payable returns (bool success) `<<0>>`

- **execTransactionFromModuleReturnData**( address to, uint256 value, bytes memory data, uint8 operation ) **external** returns (bool success, bytes memory returnData) `<<0>>`

- **setup**( address[] memory _owners, uint256 _threshold, address to, bytes memory data, address fallbackHandler, address paymentToken, uint256 payment, address payable paymentReceiver ) **external** `<<0>>`

- **getThreshold**() **external** **view** returns (uint256) `<<0>>`

- **getTransactionHash**( address to, uint256 value, bytes calldata data, Enum.Operation operation, uint256 safeTxGas, uint256 baseGas, uint256 gasPrice, address gasToken, address refundReceiver, uint256 _nonce ) **external** **view** returns (bytes32) `<<0>>`

- **isModuleEnabled**(address module) **external** **view** returns (bool) `<<0>>`

- **isOwner**(address owner) **external** **view** returns (bool) `<<0>>`

- **nonce**() **external** **view** returns (uint256) `<<0>>`

> **Functions:** approveHash, execTransaction, execTransactionFromModuleReturnData, setup, getThreshold, getTransactionHash, isModuleEnabled, isOwner, nonce


## File: `tare-io__tare-contracts/contracts/misc/LoansAuth.sol`

### contract LoansAuth
> **Total functions:** 10 | **Audited:** 0/10

- **constructor**(address initialGuardian) `<<0>>`

- **registerAddress**(Roles role, address addr) **external** `<<0>>`

- **registerAddressOnBehalfOf**(address addressBookOwner, Roles role, address addr) **external** **onlyAdminOrGuardian** `<<0>>`

- **unregisterAddress**(Roles role, address addr) **external** `<<0>>`

- **unregisterAddressOnBehalfOf**( address addressBookOwner, Roles role, address addr ) **external** **onlyAdminOrGuardian** `<<0>>`

- **approveOriginator**(address user) **public** **onlyRole(GUARDIAN_ROLE)** `<<0>>`

- **approveServicer**(address user) **public** **onlyRole(GUARDIAN_ROLE)** `<<0>>`

- **revokeOriginator**(address user) **public** **onlyAdminOrGuardian** `<<0>>`

- **revokeServicer**(address user) **public** **onlyAdminOrGuardian** `<<0>>`

- **isRegisteredForRole**(address addressBookOwner, Roles role, address addr) **public** **view** returns (bool) `<<0>>`

> **Functions:** constructor, registerAddress, registerAddressOnBehalfOf, unregisterAddress, unregisterAddressOnBehalfOf, approveOriginator, approveServicer, revokeOriginator, revokeServicer, isRegisteredForRole


## File: `tare-io__tare-contracts/contracts/misc/Rescuable.sol`

### contract Rescuable
> **Total functions:** 4 | **Audited:** 0/4

- **rescueERC20Tokens**( address token, uint256 amount ) **external** whenNotPaused **onlyRole(GUARDIAN_ROLE)** returns (uint256 rescued) `<<0>>`

- **rescueERC721Tokens**(address token, uint256 tokenId) **external** whenNotPaused **onlyRole(GUARDIAN_ROLE)** `<<0>>`

- **setRecoveryAddress**(address recoveryAddress_) **external** **onlyRole(GUARDIAN_ROLE)** `<<0>>`

- **_initRecoveryAddress**(address recoveryAddress_) **internal** `<<0>>`

> **Functions:** rescueERC20Tokens, rescueERC721Tokens, setRecoveryAddress, _initRecoveryAddress


## File: `tare-io__tare-contracts/contracts/NavCalculator.sol`

### contract NavCalculator
> **Total functions:** 9 | **Audited:** 0/9

- **constructor**(address initialGuardian, uint256[8] memory initialFactors) `<<0>>`

- **setDiscountFactor**( ValuationBucket bucket, uint256 factor ) **external** **onlyRole(CALCULATING_AGENT)** bumpsConfigurationVersion `<<0>>`

- **setMaxPortfolioFactor**(uint256 newMax) **external** **onlyRole(GUARDIAN_ROLE)** `<<0>>`

- **setPortfolioFactor**(uint256 factor) **external** **onlyRole(CALCULATING_AGENT)** bumpsConfigurationVersion `<<0>>`

- **_bumpConfigurationVersion**() **internal** `<<0>>`

- **applyPortfolioAdjustment**(uint256 rawValue) **external** **view** returns (uint256) `<<0>>`

- **getDiscountFactor**(ValuationBucket bucket) **external** **view** returns (uint256) `<<0>>`

- **getLoansValue**(ILoans loans, uint64[] calldata loanIds) **external** **view** returns (uint256 totalValue) `<<0>>`

- **_bucketFactor**(LoanStatus status, uint48 nextDueDate) **internal** **view** returns (uint256) `<<0>>`

> **Functions:** constructor, setDiscountFactor, setMaxPortfolioFactor, setPortfolioFactor, _bumpConfigurationVersion, applyPortfolioAdjustment, getDiscountFactor, getLoansValue, _bucketFactor


## File: `tare-io__tare-contracts/contracts/PortfolioVault.sol`

### contract PortfolioVault
> **Total functions:** 70 | **Audited:** 0/70

- **constructor**( ILoans loans_, ILoansNFT loansNFT_, ILoansExchange exchange_, IERC20 asset_, IVaultShareToken share_, INavCalculator calculator_, address initialGuardian, address initialRecoveryAddress, uint256 maxNavAge_, uint256 maxNavComputationTime_ ) `<<0>>`

- **acceptSaleOffer**(uint64 offerId) **external** **onlyRole(PORTFOLIO_MANAGER)** nonReentrant whenNotPaused `<<0>>`

- **addLoansToNav**(uint64[] calldata loanIds) **external** **onlyRole(PORTFOLIO_MANAGER)** whenNotPaused `<<0>>`

- **approveDeposit**( address controller, uint256 assets ) **external** **onlyRole(INVESTOR_MANAGER)** whenNotPaused returns (uint256 shares) `<<0>>`

- **approveRedemption**( address controller, uint256 shares ) **external** **onlyRole(INVESTOR_MANAGER)** whenNotPaused returns (uint256 assets) `<<0>>`

- **cancelDepositRequest**( address controller, address receiver ) **external** nonReentrant whenNotPaused **onlyAccountOrOperator(controller)** returns (uint256 assets) `<<0>>`

- **cancelRedeemRequest**( address controller, address receiver ) **external** nonReentrant whenNotPaused **onlyAccountOrOperator(controller)** returns (uint256 shares) `<<0>>`

- **cancelSaleOffer**(uint64 offerId) **external** **onlyRole(PORTFOLIO_MANAGER)** nonReentrant whenNotPaused `<<0>>`

- **collectCashflows**( uint64[] calldata loanIds, bytes32 ref ) **external** nonReentrant whenNotPaused returns (InvestorWithdrawalResult[] memory loanWithdrawals) `<<0>>`

- **createSaleOffer**( address buyer, uint128 price, uint48 deadline, uint64[] calldata loanIds ) **external** **onlyRole(PORTFOLIO_MANAGER)** nonReentrant whenNotPaused returns (uint64 offerId) `<<0>>`

- **deposit**( uint256 assets, address receiver, address controller ) **external** nonReentrant whenNotPaused **onlyAccountOrOperator(controller)** returns (uint256 shares) `<<0>>`

- **fundLoan**( uint64 loanId, int128 amount, uint48 timestamp, bytes32 ref ) **external** **onlyRole(PORTFOLIO_MANAGER)** nonReentrant whenNotPaused `<<0>>`

- **fundLoans**( uint64[] calldata loanIds, int128[] calldata amounts, uint48 timestamp, bytes32 ref ) **external** **onlyRole(PORTFOLIO_MANAGER)** nonReentrant whenNotPaused `<<0>>`

- **mint**( uint256 shares, address receiver, address controller ) **external** nonReentrant whenNotPaused **onlyAccountOrOperator(controller)** returns (uint256 assets) `<<0>>`

- **redeem**( uint256 shares, address receiver, address controller ) **external** nonReentrant whenNotPaused **onlyAccountOrOperator(controller)** returns (uint256 assets) `<<0>>`

- **registerAddress**(address addr) **external** `<<0>>`

- **removeLoansFromNav**(uint64[] calldata loanIds) **external** **onlyRole(PORTFOLIO_MANAGER)** whenNotPaused `<<0>>`

- **requestDeposit**( uint256 assets, address controller, address owner ) **external** nonReentrant whenNotPaused **onlyAccountOrOperator(owner)** returns (uint256 requestId) `<<0>>`

- **requestRedeem**( uint256 shares, address controller, address owner ) **external** nonReentrant whenNotPaused **onlyAccountOrOperator(owner)** returns (uint256 requestId) `<<0>>`

- **setCalculator**(address _calculator) **external** **onlyRole(GUARDIAN_ROLE)** `<<0>>`

- **setExchange**(address _exchange) **external** **onlyRole(GUARDIAN_ROLE)** `<<0>>`

- **setLoans**(address _loans, address _loansNFT) **external** **onlyRole(GUARDIAN_ROLE)** `<<0>>`

- **setMaxNavAge**(uint256 _maxNavAge) **external** **onlyAdminOrGuardian** `<<0>>`

- **setMaxNavComputationTime**(uint256 _maxNavComputationTime) **external** **onlyAdminOrGuardian** `<<0>>`

- **setOperator**(address operator, bool approved) **external** returns (bool) `<<0>>`

- **transferLoans**( uint64[] calldata loanIds, address recipient ) **external** **onlyRole(PORTFOLIO_MANAGER)** nonReentrant whenNotPaused `<<0>>`

- **unregisterAddress**(address addr) **external** `<<0>>`

- **updateNav**(uint256 batchSize) **external** whenNotPaused `<<0>>`

- **withdraw**( uint256 assets, address receiver, address controller ) **external** nonReentrant whenNotPaused **onlyAccountOrOperator(controller)** returns (uint256 shares) `<<0>>`

- **_addLoanToNav**(uint64 loanId) **internal** `<<0>>`

- **_clearNavLoanIds**() **internal** `<<0>>`

- **_fundLoans**(uint64[] memory loanIds, int128[] memory amounts, uint48 timestamp, bytes32 ref) **internal** `<<0>>`

- **_invalidateNav**() **internal** `<<0>>`

- **_removeLoanFromNav**(uint64 loanId) **internal** `<<0>>`

- **_claimDeposit**( address controller, address receiver, uint256 assets, uint256 shares, uint256 claimableAssets_, uint256 claimableShares_ ) **private** `<<0>>`

- **_claimRedeem**( address controller, address receiver, uint256 assets, uint256 shares, uint256 claimableAssets_, uint256 claimableShares_ ) **private** `<<0>>`

- **asset**() **external** **view** returns (address) `<<0>>`

- **claimableDepositRequest**(uint256, address controller) **external** **view** returns (uint256 claimableAssets) `<<0>>`

- **claimableRedeemRequest**(uint256, address controller) **external** **view** returns (uint256 claimableShares) `<<0>>`

- **convertToAssets**(uint256 shares) **external** **view** returns (uint256) `<<0>>`

- **convertToShares**(uint256 assets) **external** **view** returns (uint256) `<<0>>`

- **deposit**(uint256, address) **external** **pure** returns (uint256) `<<0>>`

- **isInNav**(uint64 loanId) **external** **view** returns (bool) `<<0>>`

- **isOperator**(address controller, address operator) **external** **view** returns (bool) `<<0>>`

- **maxMint**(address controller) **external** **view** returns (uint256) `<<0>>`

- **maxWithdraw**(address controller) **external** **view** returns (uint256) `<<0>>`

- **mint**(uint256, address) **external** **pure** returns (uint256) `<<0>>`

- **nav**() **external** **view** returns (uint256) `<<0>>`

- **navLoanCount**() **external** **view** returns (uint256) `<<0>>`

- **navLoanIdAt**(uint256 index) **external** **view** returns (uint64) `<<0>>`

- **onERC721Received**(address, address, uint256, bytes calldata) **external** **view** returns (bytes4) `<<0>>`

- **pendingDepositRequest**(uint256, address controller) **external** **view** returns (uint256 pendingAssets) `<<0>>`

- **pendingRedeemRequest**(uint256, address controller) **external** **view** returns (uint256 pendingShares) `<<0>>`

- **previewDeposit**(uint256) **external** **pure** returns (uint256) `<<0>>`

- **previewMint**(uint256) **external** **pure** returns (uint256) `<<0>>`

- **previewRedeem**(uint256) **external** **pure** returns (uint256) `<<0>>`

- **previewWithdraw**(uint256) **external** **pure** returns (uint256) `<<0>>`

- **share**() **external** **view** returns (address) `<<0>>`

- **sharePrice**() **external** **view** returns (uint256) `<<0>>`

- **totalAssets**() **external** **view** returns (uint256) `<<0>>`

- **idleLiquidity**() **public** **view** returns (uint256) `<<0>>`

- **maxDeposit**(address controller) **public** **view** returns (uint256) `<<0>>`

- **maxRedeem**(address controller) **public** **view** returns (uint256) `<<0>>`

- **supportsInterface**(bytes4 interfaceId) **public** **view** override(AccessControl, IERC165) returns (bool) `<<0>>`

- **_requireAddressBookManager**() **internal** **view** `<<0>>`

- **_requireFreshNav**() **internal** **view** `<<0>>`

- **_requireIdleNav**() **internal** **view** `<<0>>`

- **_requireInvestor**(address account) **internal** **view** `<<0>>`

- **_requireManagerRole**() **internal** **view** `<<0>>`

- **_validateLoansWiring**(ILoans loans_, ILoansNFT loansNFT_, IERC20 asset_) **internal** **view** `<<0>>`

> **Functions:** constructor, acceptSaleOffer, addLoansToNav, approveDeposit, approveRedemption, cancelDepositRequest, cancelRedeemRequest, cancelSaleOffer, collectCashflows, createSaleOffer, deposit, fundLoan, fundLoans, mint, redeem, registerAddress, removeLoansFromNav, requestDeposit, requestRedeem, setCalculator, setExchange, setLoans, setMaxNavAge, setMaxNavComputationTime, setOperator, transferLoans, unregisterAddress, updateNav, withdraw, _addLoanToNav, _clearNavLoanIds, _fundLoans, _invalidateNav, _removeLoanFromNav, _claimDeposit, _claimRedeem, asset, claimableDepositRequest, claimableRedeemRequest, convertToAssets, convertToShares, deposit, isInNav, isOperator, maxMint, maxWithdraw, mint, nav, navLoanCount, navLoanIdAt, onERC721Received, pendingDepositRequest, pendingRedeemRequest, previewDeposit, previewMint, previewRedeem, previewWithdraw, share, sharePrice, totalAssets, idleLiquidity, maxDeposit, maxRedeem, supportsInterface, _requireAddressBookManager, _requireFreshNav, _requireIdleNav, _requireInvestor, _requireManagerRole, _validateLoansWiring


## File: `tare-io__tare-contracts/contracts/SmartAccountFactory.sol`

### contract SmartAccountFactory
> **Total functions:** 6 | **Audited:** 0/6

- **constructor**(address _safeProxyFactory, address _safeSingleton, address _trustedCallsModule, address _trustedSpender) `<<0>>`

- **configureSmartAccount**( address[] memory delegates, address[] memory currencies, address[] memory nftCollections, address[] memory trustedRecipients, uint48 validUntil ) **external** `<<0>>`

- **deploySmartAccount**( address[] memory delegates, address[] memory currencies, address[] memory nftCollections, address[] memory trustedRecipients, uint48 validUntil, address[] memory owners, uint256 threshold ) **external** returns (address) `<<0>>`

- **_setConfigured**() **internal** `<<0>>`

- **predictSmartAccountAddress**( address deployer, uint256 _nonce, address[] memory delegates, address[] memory currencies, address[] memory nftCollections, address[] memory trustedRecipients, uint48 validUntil, address[] memory owners, uint256 threshold ) **public** **view** returns (address) `<<0>>`

- **_buildInitializer**( address[] memory delegates, address[] memory currencies, address[] memory nftCollections, address[] memory trustedRecipients, uint48 validUntil, address[] memory owners, uint256 threshold ) **internal** **view** returns (bytes memory) `<<0>>`

> **Functions:** constructor, configureSmartAccount, deploySmartAccount, _setConfigured, predictSmartAccountAddress, _buildInitializer


## File: `tare-io__tare-contracts/contracts/TrustedCalls.sol`

### contract TrustedCalls
> **Total functions:** 11 | **Audited:** 0/11

- **constructor**(address initialGuardian, address initialRecoveryAddress) `<<0>>`

- **addDelegate**(address safe, address delegate) **external** safeOrGuardian(safe) `<<0>>`

- **addTrustedCall**(address target, bytes4 selector) **external** whenNotPaused **onlyRole(GUARDIAN_ROLE)** `<<0>>`

- **addTrustedCalls**( address[] calldata targets, bytes4[] calldata selectors ) **external** whenNotPaused **onlyRole(GUARDIAN_ROLE)** `<<0>>`

- **executeTrustedCall**( address safe, address target, bytes calldata data ) **external** whenNotPaused returns (bool success, bytes memory returnData) `<<0>>`

- **executeTrustedCallBatch**( address safe, address[] calldata targets, bytes[] calldata data ) **external** whenNotPaused returns (bytes[] memory results) `<<0>>`

- **removeDelegate**(address safe, address delegate) **external** safeOrAdmin(safe) `<<0>>`

- **removeTrustedCall**(address target, bytes4 selector) **external** **onlyAdminOrGuardian** `<<0>>`

- **isDelegate**(address safe, address delegate) **external** **view** returns (bool) `<<0>>`

- **isTrustedCall**(address target, bytes4 selector) **external** **view** returns (bool) `<<0>>`

- **getTrustKey**(address target, bytes4 selector) **public** **pure** returns (bytes32) `<<0>>`

> **Functions:** constructor, addDelegate, addTrustedCall, addTrustedCalls, executeTrustedCall, executeTrustedCallBatch, removeDelegate, removeTrustedCall, isDelegate, isTrustedCall, getTrustKey


## File: `tare-io__tare-contracts/contracts/TrustedSpender.sol`

### contract TrustedSpender
> **Total functions:** 11 | **Audited:** 0/11

- **constructor**(address initialGuardian, address initialRecoveryAddress) `<<0>>`

- **addDelegate**(address safe, address delegate) **external** safeOrGuardian(safe) `<<0>>`

- **executeNFTTransfer**(address collection, address from, address to, uint256 tokenId) **external** whenNotPaused `<<0>>`

- **executeTransfer**(address token, address from, address to, uint256 amount) **external** whenNotPaused `<<0>>`

- **removeDelegate**(address safe, address delegate) **external** safeOrAdmin(safe) `<<0>>`

- **setAllowance**( address token, address from, address to, uint208 amount, uint48 validUntil ) **external** safeOrGuardian(from) `<<0>>`

- **setNFTAllowance**( address collection, address from, address to, bool allowed, uint48 validUntil ) **external** safeOrGuardian(from) `<<0>>`

- **getAllowance**( address token, address from, address to ) **external** **view** returns (uint256 amount, uint48 validUntil) `<<0>>`

- **getNFTAllowance**( address collection, address from, address to ) **external** **view** returns (bool allowed, uint48 validUntil) `<<0>>`

- **isDelegate**(address safe, address delegate) **external** **view** returns (bool) `<<0>>`

- **isNFTTransferAllowed**(address collection, address from, address to) **external** **view** returns (bool) `<<0>>`

> **Functions:** constructor, addDelegate, executeNFTTransfer, executeTransfer, removeDelegate, setAllowance, setNFTAllowance, getAllowance, getNFTAllowance, isDelegate, isNFTTransferAllowed


## File: `tare-io__tare-contracts/contracts/VaultShareToken.sol`

### contract VaultShareToken
> **Total functions:** 10 | **Audited:** 0/10

- **constructor**( string memory name_, string memory symbol_, address initialGuardian, address initialRecoveryAddress, address vault_, address asset_ ) ERC20(name_, symbol_) `<<0>>`

- **burn**(address from, uint256 amount) **external** **onlyRole(BURNER_ROLE)** `<<0>>`

- **mint**(address to, uint256 amount) **external** **onlyRole(MINTER_ROLE)** `<<0>>`

- **setVault**(address newVault) **external** **onlyRole(GUARDIAN_ROLE)** `<<0>>`

- **_update**(address from, address to, uint256 value) **internal** override `<<0>>`

- **detectTransferRestriction**(address from, address to, uint256) **external** **view** returns (uint8) `<<0>>`

- **messageForTransferRestriction**(uint8 restrictionCode) **external** **pure** returns (string memory) `<<0>>`

- **vault**(address asset) **external** **view** returns (address) `<<0>>`

- **supportsInterface**(bytes4 interfaceId) **public** **view** override returns (bool) `<<0>>`

- **_detectTransferRestriction**(address from, address to) **private** **view** returns (uint8) `<<0>>`

> **Functions:** constructor, burn, mint, setVault, _update, detectTransferRestriction, messageForTransferRestriction, vault, supportsInterface, _detectTransferRestriction


