# Joint-Bank-Account

## Background
用於練習使用 solidity 部署智能合約的第一個專案，可以讓使用者在此智能合約存款或提款。\
以 visual studio code 環境，利用 hardhat 撰寫，分三個部分。
- smart contract
  - solidity
- test
  - javascript
- frond end
  - javascript
  - html
## Setup
```bash=
npm init
npm install --save-dev hardhat
npx hardhat
```
## smart contract component
### Struct
- WithdrawRequest: struct，儲存提款請求的各種資訊。
  - user: address，請求提款的人地址。
  - amount: uint，提款總量。
  - approvals: uint，請求已有多少帳戶擁有人同意。
  - ownersApproved: mapping( address => bool )，帳戶擁有人哪些同意哪些不同意該請求。
  - approved: bool，請求是否已通過。
- Account: struct，儲存帳戶資訊。
  - owners: address[]，帳戶擁有人，上限為四人。
  - balance: uint，帳戶餘額。
  - withdrawRequests: mapping( uint => WithdrawRequest )，帳戶有的提款請求，以 withdrawId 對應的提款請求儲存。
### Modifier
- accountOwner(uint accountId): modifier
  - 確認 msg.sender 為 accountId 對應帳號的 owner。
- validOwners(address[] calldata owner): modifier
  - 每個帳號最多只能有 4 個 owners。
  - 這裡使用 calldata，是因為我們不需要更改 owner 這個陣列，所以不需要放在 memory，減少 gas fee。
- sufficientBalance(uint accountId, uint amount): modifier
  - 確認提款數量小於等於 accountId 對應帳戶的餘額。
- canProve(uint accountId, uint withdrawId): modifier
  - 確認 msg.sender 為 accountId 對應帳戶的擁有者。
  - 確認 accountId 對應的帳戶中存在 withdrawId 對應的提取請求。
  - 確認 msg.sender 不是 withdrawId 對應提取請求的請求者。
  - 確認 msg.sender 還未同意 withdrawId 對應的提取請求。
- canWithdraw(uint accountId, uint withdrawId): modifier
  - 確認 msg.sender 為 withdrawId 對應提取請求的請求者。
  - 確認 withdrawId 對應提取請求中所有 accountId 對應帳戶的擁有者皆已同意，也就是 approved 為 true。
### Function
- deposit(uint accountId): external payable accountOwner(accountId)
  - 在 accountId 對應帳戶存錢。
- createAccount(address[] calldata otherOwners): external validOwners(otherOwners)
  - 新增帳號，該帳號擁有者為 msg.sender 與 otherOwners。
- requestWithdraw(uint accountId, uint amount): external accountOwner(accoundId) sufficientBalance(accountId, amount)
  - 對 accountId 對應帳戶提出數量 amount 的提款請求。
- approveWithdraw(uint accountId, uint withdrawId): external accountOwner(accountId) canApprove(accountId, withdrawId)
  - 同意 accoundId 對應帳戶中 withdrawId 對應的提款請求。
- withdraw(uint accountId, uint withdrawId): external accountOwner(accountId) canWithdraw(accountId, withdrawId)
  - msg.sender 使用 accoundId 對應帳戶中 withdrawId 對應的提款請求進行提款。
- getBalance(uint accountId): public view returns (uint)
  - 回傳 accountId 對應帳戶的餘額。
- getApprovals(uint accountId, uint withdrawId): public view returns (uint)
  - 回傳 accountId 對應帳戶中 withdrawId 對應提款請求同意數。
- getAccounts(): public view returns (uint[] memory)
  - 回傳 msg.sender 所擁有的所有 accountId，也就是所有帳戶。

## test
```bash
npx hardhat test
```
使用 javascript 撰寫測試，確認智能合約提供的功能都能正確運作。

## scripts
```bash
npx hardhat node
npx hardhat run --network localhost ./scripts/deploy.js
```
會新增一個 deployment.json，等一下會用到。

## frondend
先寫 base.html，接著依照剛剛生成的 deployment.js 檔案，一一複製到 script.js 中對應的位置，完成對應功能。\
ctrl + shift + P “live server: open with live server” (要到 base.html 頁面)
