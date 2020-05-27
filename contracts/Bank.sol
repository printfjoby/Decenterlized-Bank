// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.6.0;
     
/* Imports */
import "./SafeMath.sol"; 
import "./ownable.sol";
     
/**
 * @author Joby Augustine
 * @notice You use this contract for banking operations. 
 * @dev The main Bank contract for banking operations.
 * @title Decentralized Bank
 */     
/*Contract */
contract Bank is Ownable {
    
    /* library */
    using SafeMath for uint256;
    
    /* Enuns */
    
    // Loan Status.
    enum LnStatus { 
                
        WaitingForCollateralVerification, // Waiting for collateral verification by the Manager.
        Approved, // Loan approved by Manager after collateral verification.
        CrossedDeadline // Failed to repay the loan.
    }
            
            
    /* Structs */
    
    // Store Loan information.
    struct LnInfo { 
        
        uint256 loanId; // loan Id.
        uint256 amount; // Loan amount.
        uint256 duration; // Duration of Loan in Days. 
        uint256 interest; // Interest for the Loan.
        uint256 endTime; // Loan end time
        uint256 repayAmountBal; // Repayment amount left.
        LnStatus loanStatus; //Loan status
    }
    
    // Store Fixed Deposit information.
    struct FxDptInfo {
            
        uint256 fdId; // Fixied deposit Id.
        uint256 amount; // Fixed Deposit amount.
        uint256 duration; // Duration of Fixed Deposit in Days.
        uint256 interest; // Interest for the Fixed Deposit.
        uint256 endTime; // Fixed Deposit end time.
    }
     
    // Store information of the User.
    struct UsrInfo{
        
        bool acc_status; // Account status. `true` value denoted existing user.
        uint256 balance; // Balance amount.
        uint256 totalUsrFD; // Sum total of all Fixed Deposit.
        LnInfo[] loanInfo; // Store details of all Loans of an User.
        FxDptInfo[] fdInfo; // Store details of all Fixed Deposits of an User.
    }
    
    // Loan tariff
    struct LoanTariff{

        uint256 duration; // Loan duration in Days.
        uint256 interest; // Loan intrest.
    }
    
    
    // Fixed Deposit tariff
    struct FdTariff{
        
        uint256 duration; // Fixed Deposit duration in Days.
        uint256 interest; // Fixed Deposit intrest.
    }
    
    
    /*Events */
    
    /**
     * @dev Emitted when User deposits to his/her account.
     * @param userAddr User address.
     * @param amount Amount deposited.
     */
    event Deposit(address indexed userAddr, uint amount);  
    
    /**
     * @dev Emitted when User withdraws from his/her account.
     * @param userAddr User address.
     * @param amount Amount withdrawn.
     */
    event Withdraw(address indexed userAddr, uint256 amount);  
    
    /**
     * @dev Emitted when User deposits an amount for a fixed duration.
     * @param fdId Fixed deposit Id
     * @param userAddr User address.
     * @param amount Deposit amount.
     * @param tariffId Tariff Id for fixed deposit.
     */
    event FixedDeposit(uint256 indexed fdId, address userAddr, uint256 amount, uint256 tariffId); 
        
    /**
     * @dev Emitted when User withdraws his/her fixed deposit.
     * @param fdId Fixed deposit Id
     * @param userAddr User address.
     * @param amount Amount withdrawn.
     */
    event WithdrawFD(uint256 indexed fdId, address userAddr, uint256 amount);  
        
    /**
     * @dev Emitted when User withdraws his/her fixed deposit before maturity period.
     * @param fdId Fixed deposit Id
     * @param userAddr User address.
     * @param amount Amount withdrawn.
     */
    event WithdrawFDBeforeMaturity(uint256 indexed fdId, address userAddr, uint256 amount);  
        
    /**
     * @dev Emitted when User requests for a loan.
     * @param loanId Loan id.
     * @param userAddr User address.
     * @param amount Loan amount.
     * @param tariffId Tariff Id for Loan.
     */
    event RequestLoan(uint256 indexed loanId, address userAddr, uint256 amount, uint256 tariffId);  
    
    /**
     * @dev Emitted when User cancel Loan request.
     * @param loanId Loan id.
     * @param userAddr User address.
     */
    event CancelLoanRequest(uint256 indexed loanId, address userAddr); 
        
    /**
     * @dev Emitted when User repays the loan.
     * @param loanId Loan id.
     * @param userAddr User address.
     * @param amount Repay amount.
     */
    event RepayLoan(uint256 indexed loanId, address userAddr, uint256 amount);   
    
    /**
     * @dev Emitted when User failed to repay loan.
     * @param loanId Loan id.
     * @param userAddr User address.
     */
    event LoanDeadLineCrosssed(uint256 indexed loanId, address userAddr); 
    
    /**
     * @dev Emitted when Loan is closed.
     * @param userAddr User address.
     * @param loanId Loan Id.
     */
    event LoanClosed(uint256 indexed loanId, address userAddr); 
        
    /**
     * @dev Emitted when Manager approve or reject loan.
     * @param loanId Loan Id
     * @param userAddr User address.
     * @param status Loan status, if `true` then loan approved else if `false` then loan rejected.
     */
    event ApproveOrRejectLoan(uint indexed loanId, address userAddr, bool status);  
        
    /**
     * @dev Emitted when new deposits are freezed.
     */
    event PausedNewDeposits();  
        
    /**
     * @dev Emitted when allows new deposits.
     */
    event ResumedNewDeposits();  
        
    /**
     * @dev Emitted when new loans are freezed.
     */
    event PausedNewLoans();  
        
    /**
     * @dev Emitted when new loans are available.
     */
    event ResumedNewLoans();  
        
    /**
     * @dev Emitted when Owner deposits Eth to the Bank.
     * @param amount Deposit amount.
     */
    event DepositEthToBank(uint256 amount);   
        
    /**
     * @dev Emitted when Owner withdraws profit.
     * @param amount Withdraw amount.
     */
    event OwnerWithdraw(uint256 amount);  
        
    /**
     * @dev Emitted when Owner sets a loan duration and its interest rate.
     * @param tariffId Loan tarrif Id.
     * @param duration Loan duration.
     * @param interest Loan interest.
     * 
     */
    event SetLoanDurationAndInterest(uint256 tariffId, uint256 duration, uint256 interest);  

    /**
     * @dev Emitted when Owner remove a loan duration and its interest rate.
     * @param tariffId Loan tariff Id.
     */
    event RemoveLoanDurationAndInterest(uint256 tariffId);
        
    /**
     * @dev Emitted when Owner sets a Fixed deposit duration and its interest rate.
     * @param tariffId Fixed deposit tarrif Id.
     * @param duration of Fixed deposit.
     * @param interest Fixed deposit interest.
     */
    event SetFDDurationAndInterest(uint256 tariffId, uint256 duration, uint256 interest); 
    
     /**
     * @dev Emitted when Owner remove a fixed deposit duration and its interest rate.
     * @param tariffId Fixed deposit tariff Id.
     */
    event RemoveFDDurationAndInterest(uint256 tariffId);  
        
     /**
     * @dev Emitted when Owner changes the manager.
     * @param managerAddrs Manager's address.
     */
    event SetManager(address managerAddrs);  
        
    
     /* Storage */
    
    address[] private userAddress; // Array of User addresses.
    address public managerAddress; // Managers's Address.
    
    uint256 public contractBalance; // Balance amount of the contract.
    uint256 private ownerBalance; // Owner Balance.
    uint256 constant public loanInterestAmountShare = 10 ; // Loan interest amount share for owner in percent.
    uint256 public totalFixedDeposit; // Total fixed deposit.
    uint256[] public loanIdsOfPendingRequests; // Loan ids of pending Loan requests.
    uint256[] public fdTfId; // Fixed Deposit tariff Ids.
    uint256[] public lnTfId; // Loan tariff Ids.
    
    bool public acceptDeposit; // User can deposit Eth only if `acceptDeposit` is `true`;
    bool public loanAvailable; // User can request Loan only if `loanAvailable` is `truw`;
    
    mapping(address => UsrInfo) public userInfo; // Information of User.
    mapping(uint256 => address) public loanIdToUser; // Mapping from loan ids of pending Loan requests to user.
    mapping(uint256 => FdTariff) public fdTariffIdToInfo; // Mapping from Fixed deposit tariff Id to information(Fd duration and interest).
    mapping(uint256 => LoanTariff) public lnTfIdToInfo; // Mapping from Loan tariff Id to information(Loan duration and interest).
    
    /* Modifiers */
    
    /** @dev Requires that the sender is the Manager */
    modifier onlyByManager() {
        require(managerAddress == msg.sender);
        _;
        
    }
    
    
    /*Constructor */
    
    constructor () public {
        
    }
    
    
    /* Functions */
    
    
    /**
     * @notice Send eth to deposit it in the account.
     * @dev User deposits to his/her account.
     */
    function deposit() external payable{
        
        require(acceptDeposit,"Deposit function freezed by Owner");
        if(!userInfo[msg.sender].acc_status) {
            userInfo[msg.sender].acc_status = true;
            userAddress.push(msg.sender);
        }
        userInfo[msg.sender].balance = userInfo[msg.sender].balance.add(msg.value);
        contractBalance = contractBalance.add(msg.value);
        
        emit Deposit(msg.sender, msg.value);
    }
    
    /**
     * @notice Withdraw an amount from account. 
     * @dev User withdraw from his/her account.
     * @param _amount Withdrawal amount.
     */
    function withdraw(uint256 _amount) external {
        
        require(userInfo[msg.sender].balance >= _amount, "Insufficient Balance");
        userInfo[msg.sender].balance = userInfo[msg.sender].balance.sub(_amount);
        contractBalance = contractBalance.sub(_amount);
        msg.sender.transfer(_amount);
        
        emit Withdraw(msg.sender, _amount);
    }
    
    /**
     * @notice Send fixed deposit amount in Eth and choose a tariff.
     * @dev User deposits an amount for a fixed duration.
     * @param _tariffId Tariff id for fixed deposit.
     */
    function fixedDeposit(uint256 _tariffId) external payable {
        
        require(acceptDeposit,"Deposit function freezed by Owner");
        if(!userInfo[msg.sender].acc_status) {
            userInfo[msg.sender].acc_status = true;
            userAddress.push(msg.sender);
        }
        
        userInfo[msg.sender].totalUsrFD = userInfo[msg.sender].totalUsrFD.add(msg.value);
        
        uint256 _fdId = uint256(keccak256(abi.encodePacked(now, msg.sender)));
        userInfo[msg.sender].fdInfo.push(
            FxDptInfo(
                _fdId,
                msg.value,
                fdTariffIdToInfo[_tariffId].duration,
                fdTariffIdToInfo[_tariffId].interest,
                now.add(fdTariffIdToInfo[_tariffId].duration.mul(1 days) )
            ));
        
        contractBalance = contractBalance.add(msg.value); 
        totalFixedDeposit = totalFixedDeposit.add(msg.value);
        
        emit FixedDeposit(_fdId, msg.sender, msg.value, _tariffId);
    }
    
    /**
     * @notice Withdraw fixed deposit.
     * @dev User withdraws his/her fixed deposit with interest.
     * @param _fdIndex Index of the Fixed deposit to be withdrawn.
     */
    function withdrawFD(uint256 _fdIndex) public {
        
        uint256 _fdCount = userInfo[msg.sender].fdInfo.length;
        require(_fdIndex < _fdCount, "Invalid choice");
        require(userInfo[msg.sender].fdInfo[_fdIndex].endTime >= now, "This Fixed deposit is not matured");
    
        uint256 _interest =  userInfo[msg.sender].fdInfo[_fdIndex].interest;
        uint256 _numOfDays = userInfo[msg.sender].fdInfo[_fdIndex].duration
            .add((now.sub(userInfo[msg.sender].fdInfo[_fdIndex].endTime))
            .div(1 days));
        uint256 _amount =  userInfo[msg.sender].fdInfo[_fdIndex].amount;
        uint256 _interestAmt = (_amount.div(100).mul(_interest)).div(365); // Interest Amount for 1 day.
        _interestAmt = _interestAmt.mul(_numOfDays);
        _amount = _amount.add(_interestAmt);
        
        uint256 _fdId = userInfo[msg.sender].fdInfo[_fdIndex].fdId;
        
        require(contractBalance >= _amount, "Insufficient balance in contract");
        userInfo[msg.sender].totalUsrFD = userInfo[msg.sender].totalUsrFD.sub(_amount);
        contractBalance = contractBalance.sub(_amount); 
        totalFixedDeposit = totalFixedDeposit.sub(_amount);
    
        userInfo[msg.sender].fdInfo[_fdIndex] =  userInfo[msg.sender].fdInfo[_fdCount.sub(1)];
        userInfo[msg.sender].fdInfo.pop();
        
        msg.sender.transfer(_amount);
        
        emit WithdrawFD(_fdId, msg.sender, _amount);
    }
    
    /**
     * @notice Withdraw fixed deposit before maturity period.
     * @dev User withdraws his/her fixed deposit before maturity period with penality of 5 percent of the FD Interest.
     * @param _fdIndex Index of the Fixed deposit to be withdrawn.
     */
    function withdrawFDBeforeMaturity(uint256 _fdIndex) external {
        
        if(userInfo[msg.sender].fdInfo[_fdIndex].endTime >= now) {
            withdrawFD(_fdIndex);
        }
        else {
            uint256 _fdCount = userInfo[msg.sender].fdInfo.length;
            
            require(_fdIndex < _fdCount, "Invalid choice");
            uint256 _interest =  userInfo[msg.sender].fdInfo[_fdIndex].interest;
            uint256 _numOfDays = (userInfo[msg.sender].fdInfo[_fdIndex].endTime.sub(now)).div(1 days);
            uint256 _amount =  userInfo[msg.sender].fdInfo[_fdIndex].amount;
            uint256 _interestAmt = (_amount.div(100).mul(_interest)).div(365); // Interest Amount for 1 day.
            _interestAmt = _interestAmt.mul(_numOfDays);
            _amount = _amount.add(_interestAmt);
            _amount = _amount.sub(_interestAmt.div(100).mul(5)); // Penality deducted.
            
            require(contractBalance >= _amount, "Insufficient balance in contract");
            userInfo[msg.sender].totalUsrFD = userInfo[msg.sender].totalUsrFD.sub(_amount);
            contractBalance = contractBalance.sub(_amount); 
            totalFixedDeposit = totalFixedDeposit.sub(_amount);
            
            uint256 _fdId = userInfo[msg.sender].fdInfo[_fdIndex].fdId;
            
            userInfo[msg.sender].fdInfo[_fdIndex] =  userInfo[msg.sender].fdInfo[_fdCount.sub(1)];
            userInfo[msg.sender].fdInfo.pop();
            
            msg.sender.transfer(_amount);
            
            emit WithdrawFDBeforeMaturity(_fdId, msg.sender, _amount);
        }
    }
    
    /**
     * @notice Request for a loan.
     * @dev User requests for a loan.
     * @param _amount Loan amount.
     * @param _tariffId Tariff id for Loan.
     */
    function requestLoan(uint256 _amount, uint256 _tariffId) external {
        
        require(loanAvailable,"Loans Unavailable");
        if(!userInfo[msg.sender].acc_status) {
            userInfo[msg.sender].acc_status = true;
            userAddress.push(msg.sender);
        }
        
         uint256 _loanId = uint256(keccak256(abi.encodePacked(now, msg.sender)));
        userInfo[msg.sender].loanInfo.push(
            LnInfo(
                _loanId,
                _amount,
                lnTfIdToInfo[_tariffId].duration,
                lnTfIdToInfo[_tariffId].interest,
                0,
                0,
                LnStatus.WaitingForCollateralVerification
            ));
        loanIdsOfPendingRequests.push(_loanId);
        loanIdToUser[_loanId] = msg.sender;
         
        emit RequestLoan(_loanId, msg.sender, _amount, _tariffId);
    }
    
    /**
     * @notice Repay loan partially or completely.
      * @dev User repays the loan.
     * @param _loanIndex Index of this Loan.
     */
    function repayLoan(uint256 _loanIndex) external payable {
        
        uint256 _amount = msg.value; 
        uint256 _lnCount = userInfo[msg.sender].loanInfo.length;
        
        require(_loanIndex < _lnCount, "Invalid choice");
        
         if(userInfo[msg.sender].loanInfo[_loanIndex].endTime >= now){
            userInfo[msg.sender].loanInfo[_loanIndex].loanStatus = LnStatus.CrossedDeadline;
            emit LoanDeadLineCrosssed(userInfo[msg.sender].loanInfo[_loanIndex].loanId, msg.sender );
        }
        else{
            uint256 _repayAmount = userInfo[msg.sender].loanInfo[_loanIndex].repayAmountBal;
            
            require(_amount > _repayAmount , "Excess Payment");
            userInfo[msg.sender].loanInfo[_loanIndex].repayAmountBal = userInfo[msg.sender].loanInfo[_loanIndex].repayAmountBal.sub(_amount); 
            contractBalance = contractBalance.add(_repayAmount);
            
            emit RepayLoan(userInfo[msg.sender].loanInfo[_loanIndex].loanId, msg.sender, _amount);
            
            if( _repayAmount == 0 ) {
                emit LoanClosed(userInfo[msg.sender].loanInfo[_loanIndex].loanId, msg.sender);  
                
                uint256 _ownerShare = (userInfo[msg.sender].loanInfo[_loanIndex].amount
                    .div(100)
                    .mul(userInfo[msg.sender].loanInfo[_loanIndex].interest)
                    )
                    .div(100)
                    .mul(loanInterestAmountShare); // `loanInterestAmountShare` percent of intrest amount
                ownerBalance = ownerBalance.add(_ownerShare);
                contractBalance = contractBalance.sub(_ownerShare);
                userInfo[msg.sender].loanInfo[_loanIndex] =  userInfo[msg.sender].loanInfo[_lnCount.sub(1)];
                userInfo[msg.sender].loanInfo.pop();
            }
        }
    }
    
    /** 
     * @notice Request for a loan.
     * @dev User requests for a loan.
     * @param _loanIndex `loanInfo` index id of the loan.
     */
    function cancelLoanRequest(uint256 _loanIndex) external {
        
        require(userInfo[msg.sender].loanInfo[_loanIndex].loanStatus == LnStatus.WaitingForCollateralVerification, "Invalid Loan Id");

        for(uint256 i=0; i < loanIdsOfPendingRequests.length;i++){
            if(loanIdsOfPendingRequests[i] == userInfo[msg.sender].loanInfo[_loanIndex].loanId){
                loanIdsOfPendingRequests[i] = loanIdsOfPendingRequests.length.sub(1);
                loanIdsOfPendingRequests.pop();
            }
        }
        
        emit CancelLoanRequest(userInfo[msg.sender].loanInfo[_loanIndex].loanId, msg.sender);
        
        uint256 _lnCount = userInfo[msg.sender].loanInfo.length;
        userInfo[msg.sender].loanInfo[_loanIndex] =  userInfo[msg.sender].loanInfo[_lnCount.sub(1)];
        userInfo[msg.sender].loanInfo.pop();
    }
    
    /**
     * @notice View loan requests.
     * @dev Manager can view all loan requests waiting for approval.
     * @return _loans Loans waiting for approval.
     */
    function viewLoanRequests() external onlyByManager view returns(uint[] memory, address[] memory, uint256[] memory, uint256[] memory, uint256[] memory) {
       
        address[] memory _userAddrs = new address[](loanIdsOfPendingRequests.length);
        uint256[] memory _loanIds = new uint256[](loanIdsOfPendingRequests.length);
        uint256[] memory _amounts = new uint256[](loanIdsOfPendingRequests.length);
        uint256[] memory _durations = new uint256[](loanIdsOfPendingRequests.length);
        uint256[] memory _interests = new uint256[](loanIdsOfPendingRequests.length);
            
        uint256 _lnId;
        address _usrAdrs;
            
        for(uint256 i=0; i < loanIdsOfPendingRequests.length; i++ ){
            _lnId = loanIdsOfPendingRequests[i];
            _usrAdrs = loanIdToUser[_lnId];
            _loanIds[i] = _lnId;
            _userAddrs[i] = _usrAdrs;
            for(uint256 j= 0; j < userInfo[_usrAdrs].loanInfo.length; j++ ){
                if(userInfo[_usrAdrs].loanInfo[j].loanId == _lnId){
                    _amounts[i] = userInfo[_usrAdrs].loanInfo[j].amount;
                    _durations[i] = userInfo[_usrAdrs].loanInfo[j].duration;
                    _interests[i] = userInfo[_usrAdrs].loanInfo[j].interest;
                }
            }
        }
        return(_loanIds, _userAddrs, _amounts, _durations, _interests);
    }
    
    /**
     * @notice Approve or reject loan.
     * @dev Manager approve or reject loan.
     * @param _loanId Loan Id.
     * @param _approve `true` value indicates the approval and `false` indicates rejection.
     * 
     */
    function approveOrRejectLoan(uint _loanId, bool _approve) external onlyByManager {
        
        address _userAddrs = loanIdToUser[_loanId];
        for(uint256 i = 0; i < userInfo[_userAddrs].loanInfo.length ; i++) {
            if(userInfo[_userAddrs].loanInfo[i].loanId == _loanId){
                if(_approve){
                    userInfo[_userAddrs].loanInfo[i].loanStatus = LnStatus.Approved;
                    payable(_userAddrs).transfer(userInfo[_userAddrs].loanInfo[i].amount);
                    contractBalance = contractBalance.sub(userInfo[_userAddrs].loanInfo[i].amount);
                }
                else{
                    userInfo[_userAddrs].loanInfo[i] = 
                        userInfo[_userAddrs].loanInfo[userInfo[_userAddrs].loanInfo.length.sub(1)]; // Copy last element to current element's position.
                    userInfo[loanIdToUser[_loanId]].loanInfo.pop(); // Remove last element
                }
                for(uint256 j = 0; j < loanIdsOfPendingRequests.length; j++){
                    if(loanIdsOfPendingRequests[i] == _loanId){
                        loanIdsOfPendingRequests[i] = loanIdsOfPendingRequests[loanIdsOfPendingRequests.length.sub(1)]; // Copy last element to current element's position.
                        loanIdsOfPendingRequests.pop(); // Remove last element
                    }
                }
            }
        }
        emit ApproveOrRejectLoan(_loanId,_userAddrs, _approve);
    }
    
    /**
     * @notice Change Loan status to deadline crossed.
     * @dev Change Loan status to deadline crossed.
     * @param _loanId Loan Id of the loan.
     */
    function deadLineCrossed(uint256 _loanId) external onlyByManager {
        
        address _userAddrs = loanIdToUser[_loanId];
        for(uint256 i=0; i< userInfo[_userAddrs].loanInfo.length; i++) {
            if(userInfo[_userAddrs].loanInfo[i].loanId == _loanId ){
                require(userInfo[_userAddrs].loanInfo[i].endTime <= now, "Not reached the End time" );
                userInfo[_userAddrs].loanInfo[i].loanStatus = LnStatus.CrossedDeadline;
            }
        }
        emit LoanDeadLineCrosssed(_loanId, _userAddrs);
    }
    
    /**
     * @notice Prevent new deposits.
     * @dev Prevent new deposits.
     */
    function pauseNewDeposits() external onlyOwner {
        
        acceptDeposit = false;
        emit PausedNewDeposits();
    }
    
    /**
     * @notice Allow new deposits.
     * @dev Allow new deposits.
     */
    function resumeNewDeposits() external onlyOwner {
        
        acceptDeposit = true;
        emit ResumedNewDeposits();
    }
    
    /**
     * @notice Prevent new loans.
     * @dev Prevent new loans.
     */
    function pauseNewLoans() external onlyOwner {
        
        loanAvailable = false;
        emit PausedNewDeposits();
        
    }
    
    /**
     * @notice Allow new loans.
     * @dev Allow new loans.
     */
    function resumeNewLoans() external onlyOwner {
        
        loanAvailable = true;
        emit ResumedNewLoans();
    }
    
    /**
     * @notice Deposits Eth to the Bank.
     * @dev Owner deposits Eth to the Bank.
     */
    function depositEthToBank() external onlyOwner payable {
    
        contractBalance = contractBalance.add(msg.value);
        emit DepositEthToBank(msg.value);
    }
    
    /**
     * @notice Owner can withdraws profit.
     * @dev Owner withdraws profit.
     * @param _amount Withdraw amount.
     */
    function ownerWithdraw(uint256 _amount) external onlyOwner {
        
        contractBalance = contractBalance.sub(_amount);
        ownerBalance = ownerBalance.sub(_amount);
        emit OwnerWithdraw(_amount);
    }
    
    /**
     * @notice Get the fixed deposit details of an user.
     * @dev Get the fixed deposit details of an user.
     * @param _userAddrs User address.
     */
    function getUserFdDetails(address _userAddrs) public view returns(uint[] memory, uint256[] memory, uint256[] memory, uint256[] memory, uint256[] memory, uint256[] memory) {
       
        uint256[] memory _fdIndexes = new uint256[](userInfo[_userAddrs].fdInfo.length);
        uint256[] memory _fdIds = new uint256[](userInfo[_userAddrs].fdInfo.length);
        uint256[] memory _amounts = new uint256[](userInfo[_userAddrs].fdInfo.length);
        uint256[] memory _durations = new uint256[](userInfo[_userAddrs].fdInfo.length);
        uint256[] memory _interests = new uint256[](userInfo[_userAddrs].fdInfo.length);
        uint256[] memory _endTimes = new uint256[](userInfo[_userAddrs].fdInfo.length);
            
        for(uint256 i=0 ; i < userInfo[_userAddrs].fdInfo.length; i++ ){
            
            _fdIndexes[i] = i;
            _fdIds[i] = userInfo[_userAddrs].fdInfo[i].fdId;
            _amounts[i] = userInfo[_userAddrs].fdInfo[i].amount;
            _durations[i] = userInfo[_userAddrs].fdInfo[i].duration;
            _interests[i] = userInfo[_userAddrs].fdInfo[i].interest;
            _endTimes[i] =userInfo[_userAddrs].fdInfo[i].endTime;
        }
        return( _fdIndexes, _fdIds, _amounts, _durations, _interests, _endTimes);
    }
    
    /**
     * @notice Get the deposit details of an user.
     * @dev Get the deposit details of an user.
     * @param _userAddrs User address.
     */
    function getUserDepositDetails(address _userAddrs) public view returns(uint256 _balance, uint256 _totalFdAmount) {
        _balance = userInfo[_userAddrs].balance;
        _totalFdAmount = userInfo[_userAddrs].totalUsrFD;
    }
    
    /**
     * @notice Get the loan details of an user.
     * @dev Get the loan details of an user.
     * @param _userAddrs User address.
     */
    function getUserLoanDetails(address _userAddrs) public view 
        returns(uint256[] memory _loanIndexes, uint256[] memory _loanIds, uint256[] memory _amounts,
        uint256[] memory _durations, uint256[] memory _interests, uint256[] memory _endTimes, uint256[] memory _loanStatus) {
            
        for(uint256 i=0 ; i < userInfo[_userAddrs].loanInfo.length; i++ ){
            _loanIndexes[i] = i;
            _loanIds[i] = userInfo[_userAddrs].loanInfo[i].loanId;
            _amounts[i] = userInfo[_userAddrs].loanInfo[i].amount;
            _durations[i] = userInfo[_userAddrs].loanInfo[i].duration;
            _interests[i] = userInfo[_userAddrs].loanInfo[i].interest;
            _endTimes[i] = userInfo[_userAddrs].loanInfo[i].endTime;
        }
        _loanStatus = getUserLoanStatus(_userAddrs);
    }
    
    /**
     * @notice Get the loan status of an user.
     * @dev Get the loan status of an user.
     * @param _userAddrs User address.
     */
    function getUserLoanStatus(address _userAddrs) private view returns(uint256[] memory _loanStatus){
        
        for(uint256 i=0 ; i < userInfo[_userAddrs].loanInfo.length; i++ ){

           if(userInfo[_userAddrs].loanInfo[i].loanStatus == LnStatus.WaitingForCollateralVerification) {
                _loanStatus[i] = 1;
            }else if(userInfo[_userAddrs].loanInfo[i].loanStatus == LnStatus.Approved) {
                _loanStatus[i] = 2;
            }else if(userInfo[_userAddrs].loanInfo[i].loanStatus == LnStatus.CrossedDeadline) {
                _loanStatus[i] = 3;
            }
        }
    }
    
    /**
     * @notice Set a loan duration and its interest rate.
     * @dev Owner sets a loan duration and its interest rate.
     * @param _duration Loan duration.
     * @param _interest Loan interest.
     * 
     */
    function setLoanDurationAndInterest(uint256 _duration, uint256 _interest) external onlyByManager{
        uint256 _tariffId = uint256(keccak256(abi.encodePacked(now, _duration)));
        lnTfId.push(_tariffId);
        lnTfIdToInfo[_tariffId] = LoanTariff(_duration, _interest);
        
        emit SetLoanDurationAndInterest(_tariffId, _duration, _interest);
    }
    
    /**
     * @notice Get all loan durations and their interest rates
     * @dev Get all loan durations and their interest rates.
     * @return _duration Loan duration.
     * @return _interest Loan interest.
     */
    function getLoanDurationAndInterest() external view returns(uint256[] memory _duration, uint256[] memory  _interest) {
        for(uint256 i = 0; i < lnTfId.length; i++){
            _duration[i] = lnTfIdToInfo[lnTfId[i]].duration;
            _interest[i] = lnTfIdToInfo[lnTfId[i]].interest;
        }
    }
    
    /**
     * @notice Owner can remove a loan duration and its interest rate.
     * @dev Owner remove a loan duration and its interest rate.
     * @param _tariffId Loan tariff Id..
     */
    function removeLoanDurationAndInterest(uint256 _tariffId) external onlyOwner {
        for(uint256 i = 0; i < lnTfId.length; i++){
            if(lnTfId[i] == _tariffId){
                lnTfId[i] = lnTfId[lnTfId.length.sub(1)];
                lnTfId.pop();
            }
        }
        emit RemoveLoanDurationAndInterest(_tariffId);
    }
    
    
    /**
     * @notice Owner sets fixed deposit duration and its interest rate.
     * @dev Owner sets fixed deposit duration and its interest rate
     * @param _duration Fixed deposit duration.
     * @param _interest Interest rate for fixed deposit.
     */
    function setFDDurationAndInterest(uint256 _duration, uint256 _interest) external onlyByManager{
        uint256 _tariffId = uint256(keccak256(abi.encodePacked(now, _duration)));
        fdTfId.push(_tariffId);
        fdTariffIdToInfo[_tariffId] = FdTariff(_duration, _interest);
        emit SetFDDurationAndInterest(_tariffId, _duration, _interest);
    }
    
    /**
     * @notice Get all fixed deposit durations and their interest rates. 
     * @dev Get all fixed deposit durations and their interest rates. 
     * @return _duration Fixed deposit duration.
     * @return _interest Interest rate for fixed deposit.
     */
    function getFDDurationAndInterest() external view returns (uint256[] memory _duration, uint256[] memory _interest) {
        for(uint256 i = 0; i < fdTfId.length; i++){
            _duration[i] = fdTariffIdToInfo[fdTfId[i]].duration;
            _interest[i] = fdTariffIdToInfo[fdTfId[i]].interest;
        }
    }
    
    
     /**
     * @notice Owner can remove a fixed deposit duration and its interest rate.
     * @dev Owner remove a fixed deposit duration and its interest rate.
     * @param _tariffId Fixed deposit tariff.
     */
    function removeFDDurationAndInterest(uint256 _tariffId) external onlyOwner {
        for(uint256 i = 0; i < fdTfId.length; i++){
            if(fdTfId[i] == _tariffId){
                fdTfId[i] = fdTfId[fdTfId.length.sub(1)];
                fdTfId.pop();
            }
        }
        emit RemoveFDDurationAndInterest(_tariffId);
    }
    
     /**
     * @notice Owner can change the manager. 
     * @dev Owner changes the manager.
     * @param _managerAddrs Manager's address.
     */
    function setManager(address _managerAddrs) external onlyOwner {
        
        managerAddress = _managerAddrs; 
        
    }
    
         /**
     * @notice Manager can get addresses of all Users. 
     * @dev Manager can get addresses of all Users
     * @return _userAddrs Addresses of all Users.
     */
     
    function getAllUsers() external view onlyByManager returns(address[] memory _userAddrs) {
        
        _userAddrs = userAddress;
    }
}
