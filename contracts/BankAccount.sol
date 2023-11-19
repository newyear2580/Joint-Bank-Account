// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.22 <=0.8.19;

contract BankAccount {
    event Deposit(
        address indexed user,
        uint256 indexed accountId,
        uint256 value,
        uint256 timestamp
    ) ;

    event WithdrawRequested(
        address indexed user,
        uint256 indexed accountId,
        uint256 indexed withdrawId,
        uint256 amount,
        uint256 timestamp
    ) ;

    event Withdraw(
        uint256 indexed withdrawId, 
        uint256 timestamp
    ) ;

    event AccountCreated(
        address[] owners,
        uint256 indexed id,
        uint256 timestamp
    ) ;

    struct WithdrawRequest {
        address user ;
        uint256 amount ;
        uint256 approvals ;
        mapping( address => bool ) ownersApproved ;
        bool approved ;
    }

    struct Account {
        address[] owners ;  // 每個 account 最多可以有四個 owners
        uint256 balance ;
        mapping( uint256 => WithdrawRequest ) withdrawRequests ;  // withdrawId 對應一個 WithdrawRequest 物件
    }

    mapping( uint256 => Account ) accounts ;  // 每個帳號對應一個 uint ID
    mapping( address => uint[] ) userAccounts ;  // 每個 user 可以擁有三個 ID，也就是帳號的控制權

    uint256 nextAccountId ;
    uint256 nextWithdrawId ;

    modifier accountOwner(uint accountId) {
        // precondition
        // msg.sender 是否為 accountId 這個帳戶的擁有者
        bool isOwner ;
        for ( uint i ; i < accounts[accountId].owners.length ; i ++ ) {
            if ( msg.sender == accounts[accountId].owners[i] ) {
                isOwner = true ;
                break ;
            } // if
        } // for
        require( isOwner, "you are not the owner of this account" ) ;
        _ ;
    }

    modifier validOwners(address[] calldata owners) {
        // precondition
        // 每個帳號最多只能有 4 個 owners，這裡需要加一是因為包含 msg.sender
        require( owners.length + 1 <= 4, "maximum of 4 owners per account" ) ;

        // owners 中不能有重複的 user
        for ( uint i ; i < owners.length ; i ++ ) {
            if (owners[i] == msg.sender) {
                revert("no duplicate owners");
            } // if

            for ( uint j = i + 1 ; j < owners.length ; j ++ ) {
                if ( owners[i] == owners[j] ) {
                    revert( "no duplicate owners" ) ;
                } // if
            } // for
        } // for
        _ ;
    }

    modifier sufficientBalance(uint accoundId, uint amount) {
        require( accounts[accoundId].balance >= amount, "insufficient balance" ) ;
        _ ;
    }

    modifier canApprove(uint accountId, uint withdrawId) {
        // 若對應 withdraw request 已經 approved，則不能再做 approve 動作
        // 提出這個 withdraw request 的 user 不可 approve
        // 對應的 withdraw request 需要存在才可以做後續的 approve 動作
        // user 不能對同一個 withdraw request 做一次以上的 approve 動作
        require( 
            ! accounts[accountId].withdrawRequests[withdrawId].approved, 
            "this request is already approved" 
        ) ;
        require( 
            accounts[accountId].withdrawRequests[withdrawId].user != msg.sender, 
            "you cannot approve this request" 
        ) ;
        require( 
            accounts[accountId].withdrawRequests[withdrawId].user != address( 0 ), 
            "this request does not exist" 
        ) ;
        require(
            ! accounts[accountId].withdrawRequests[withdrawId].ownersApproved[msg.sender],
            "you have already approved this request"
        ) ;
        _ ;
    }

    modifier canWithdraw(uint accountId, uint withdrawId) {
        require( 
            accounts[accountId].withdrawRequests[withdrawId].user == msg.sender,
            "you did not create this request" 
        ) ;
        require(
            accounts[accountId].withdrawRequests[withdrawId].approved,
            "this request is not approved"
        ) ;
        _ ;
    }

    function deposit(uint256 accountId) 
        external 
        payable 
        accountOwner(accountId) 
    {
        // 想要在 accountId 這個帳戶存錢，必須是該帳戶的擁有者
        accounts[accountId].balance += msg.value ;
    } // deposit()

    function createAccount(address[] calldata otherOwners) 
        external 
        validOwners(otherOwners) 
    {
        // 新的帳號擁有者為 otherOwners 加上 msg.sender
        address[] memory owners = new address[]( otherOwners.length + 1 ) ;
        owners[otherOwners.length] = msg.sender ;

        uint id = nextAccountId ;

        for ( uint i ; i < owners.length ; i ++ ) {
            // 需要遍尋所有這個新帳號的 owners
            // 第一個 if 是將 otherOwners 更新到 owners 中
            // 第二個 if 用來檢測 owners[] 中每個 user 是否已經有三個帳號
            if ( i < owners.length - 1 ) {
                // 將 otherOwners 裡面所有 user 地址放到 owners 中
                // 因為 owners 這個 address[] 陣列最後一個已經放 msg.sender
                // 所以條件才會設為 owners.length - 1
                owners[i] = otherOwners[i] ;
            } // if

            if ( userAccounts[owners[i]].length >= 3 ) {
                revert( "each user can have a maximum of 3 accounts" ) ;
            } // if

            // 目前這個 user 所擁有的帳號數量不大於 3，幫這個 user 新增目前在處理的新帳號
            userAccounts[owners[i]].push( id ) ;
        } // for

        accounts[id].owners = owners ;
        nextAccountId ++ ;
        emit AccountCreated( owners, id, block.timestamp ) ;
    } // createAccount()

    function requestWithdraw(uint256 accountId, uint256 amount) 
        external 
        accountOwner(accountId) 
        sufficientBalance(accountId, amount) 
    {
        // 要先確定提出 withdraw request 的是不是 accountId 這個帳戶的 owner
        // 接著確定 accoundId 對應的帳戶是否有足夠的餘額
        uint id = nextWithdrawId ;
        // request 放在 storage，之後對 request 做的任何更動
        // 都會影響到 accounts[accountId].withdrawRequests[id] 所對應的 WithdrawRequest 物件
        // accounts[accountId].withdrawRequests 為 mapping 型別
        WithdrawRequest storage request = accounts[accountId].withdrawRequests[id] ;
        request.user = msg.sender ;
        request.amount = amount ;
        nextWithdrawId ++ ;
        emit WithdrawRequested( msg.sender, accountId, id, amount, block.timestamp ) ;
    } // requestWithdrawal()

    function approveWithdraw(uint256 accountId, uint256 withdrawId) 
        external
        accountOwner(accountId)
        canApprove(accountId, withdrawId)
    {
        // 要先確定提出 approve withdraw 的是不是 accountId 這個帳戶的 owner
        // 要先確定是否可以對對應的 withdraw request 做 approve

        WithdrawRequest storage request = accounts[accountId].withdrawRequests[withdrawId] ;
        request.approvals ++ ;
        request.ownersApproved[msg.sender] = true ;

        // 可以成功提出 withdraw request 的人必然是 accountId 對應帳戶的 owner
        // 他是第一個同意這個 withdraw request 的人，剩下只需這個帳戶其他 owner 同意便可提款
        // 所以 request.approvals 的數量只需該帳號 owners 數量減一
        if ( request.approvals == accounts[accountId].owners.length - 1 ) {
            request.approved = true ;
        } // if

    } // approveWithdraw()

    function withdraw(uint256 accountId, uint256 withdrawId) 
        external
        accountOwner(accountId)
        canWithdraw(accountId, withdrawId)
    {
        uint amount = accounts[accountId].withdrawRequests[withdrawId].amount ;
        require ( accounts[accountId].balance >= amount, "insufficient balance" ) ;

        accounts[accountId].balance -= amount ;
        delete accounts[accountId].withdrawRequests[withdrawId] ;
        // 預防重複提款

        (bool sent, ) = payable( msg.sender ).call { value: amount }( "" ) ;
        require( sent, "withdraw failed" ) ;

        emit Withdraw( withdrawId, block.timestamp ) ;
    } // withdraw()

    function getBalance(uint256 accountId) 
        public 
        view 
        returns (uint256) 
    {
        return accounts[accountId].balance ;
    } // getBalance()

    function getOwners(uint accountId) 
        public 
        view 
        returns (address[] memory)
    {
        return accounts[accountId].owners ;
    } // getOwners()

    function getApprovals(uint256 accountId, uint256 withdrawId) 
        public 
        view 
        returns (uint256) 
    {
        return accounts[accountId].withdrawRequests[withdrawId].approvals ;
    } // getApprovals()

    function getAccounts() 
        public 
        view 
        returns (uint256[] memory) 
    {
        return userAccounts[msg.sender] ;
    } // getAccounts()
}
