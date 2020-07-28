pragma solidity ^0.5.0;

import "./lib_SafeMath.sol";

/* ---------- UPDATING LOG -----------------
    1. show realtime voting result publicly
    2. handle last minutes vote with extending voting time
    3. remove review list. use order to point review instead
    4. seller get order from another seller 
    5. check same product for issue and vote
*/

contract ReviewDev {
    using SafeMath for uint256;
    
    struct Product {
        uint256 reviewValue;
        uint256 updateLockTime;
    }
    
    struct Order {
        uint256 price;
        address payable customer;
        address payable seller;
        uint256 productId;
        uint256 reviewValue;
        uint256 helpfulTimeout;
        bool purchased;
        bool postedReview;
        bool gaveHelpful;
    }
    
    struct Issue {
        uint256 orderId;
        uint256 endTime;
        uint256 maxVal;
        uint256 additionalReward;
    }
    
    struct Vote {
        bool rewardOpened;
        uint256 voteYesTotal;
        uint256 voteNoTotal;
        mapping(address => uint256) voteYesOf;
        mapping(address => uint256) voteNoOf;
        mapping(address => bool) gotReward;
    }
    
    uint256 public constant UPDATE_LOCK_TIME = 30 days;
    uint256 public constant ISSUE_MIN_TIMEOUT = 6 hours;
    uint256 public constant HELPFUL_TIMEOUT = 30 days;
    uint256 public constant EXTEND_VOTING_TIME = 10 minutes;
    
    uint256 private reviewID = 0;
    mapping(address => Product[]) public productsOf;
    Order[] public orderList;
    Issue[] public issueList;
    Vote[] public voteList;
    
    constructor() public payable {}
    
    event ProductInfoUpdated(address indexed owner, uint256 indexed productId, string ipfsHash);
    event UserInfoUpdated(address indexed user, string ipfsHash);
    event OrderCreated(uint256 orderId, address indexed customer, address indexed seller, uint256 indexed  productId);
    event Purchased(uint256 indexed orderId);
    event ReviewCreated(uint256 orderId, address indexed author, address indexed seller, uint256 indexed productId, string ipfsHash);
    event ReviewUpdated(uint256 indexed orderId, string ipfsHash);
    event ReviewReplied(address indexed author, uint256 indexed targetId,string ipfsHash);
    event ReviewDeleted(uint256 indexed orderId);
    event ReviewClosed(uint256 indexed orderId, uint256 indexed issueId);
    event HelpfulGiven(uint256 indexed orderId, uint256 targetId, address indexed giver);
    event IssueOpenned(uint256 issueId, uint256 indexed targetId, string ipfsHash, uint256 amount);
    event Voted(uint256 indexed issueId, address indexed voter, uint256 amount, string ipfsHash);
    event GotReward(uint256 indexed issueId, address indexed voter);
    
    modifier onlyCustomer {
        require(productsOf[msg.sender].length <= 0, "Seller cannot call this function");
        _;
    }
    modifier onlyOwner(uint256 _orderId) {
        require(orderList[_orderId].customer == msg.sender, "Cannot use other's order");
        _;
    }
    modifier onlyPurchaseDone(uint256 _orderId) {
        require(orderList[_orderId].purchased, "You need to purchase first");
        _;
    }
    modifier onlySameProduct(uint256 _orderId, uint256 _targetId) {
        require( 
            orderList[_orderId].seller == orderList[_targetId].seller && 
            orderList[_orderId].productId == orderList[_targetId].productId,
            "Only same product"
        );
        _;
    }
    modifier isVoteOpen(uint256 _issueId) {
        require(now <= issueList[_issueId].endTime, "This issue was closed");
        _;
    }
    modifier isVoteClose(uint256 _issueId) {
        require(now > issueList[_issueId].endTime, "This issue is still opening");
        _;
    }
    
    //workflow
    function addProduct(string memory _ipfsHash, uint256 _reviewValue) public  {
        productsOf[msg.sender].push(Product(_reviewValue, now + UPDATE_LOCK_TIME));
        emit ProductInfoUpdated(msg.sender, productsOf[msg.sender].length - 1, _ipfsHash);
    }
    
    function updateProduct(uint256 _productId, uint256 _reviewValue) public {
        require(productsOf[msg.sender][_productId].updateLockTime <= now, "Updating still lock");
        productsOf[msg.sender][_productId].reviewValue = _reviewValue;
        productsOf[msg.sender][_productId].updateLockTime = now + UPDATE_LOCK_TIME;
    }
    
    function updateProductInfo(uint256 _productId, string memory _ipfsHash) public {
        emit ProductInfoUpdated(msg.sender, _productId, _ipfsHash);
    }
    
    function updateUserInfo(string memory _ipfsHash) public {
        emit UserInfoUpdated(msg.sender, _ipfsHash);
    }
    
    function createOrder(address payable _customer, uint256 _productId, uint256 _price) public {
        require(_customer != msg.sender, "Cannot purchase own product");
        require(productsOf[_customer].length <= 0, "Cannot create order for seller");
        require(_customer.balance >= _price, "Customer does not have enough money");
        uint256 reviewValue = productsOf[msg.sender][_productId].reviewValue;
        orderList.push(Order(_price, _customer, msg.sender, _productId, reviewValue, 0, false, false, false));
        emit OrderCreated(orderList.length - 1, _customer, msg.sender, _productId);
    }
    
    function purchase(uint256 _orderId) public payable onlyCustomer onlyOwner(_orderId) {
        require(msg.value == orderList[_orderId].price, "need to pay equal to the price");
        uint256 remain = orderList[_orderId].price - orderList[_orderId].reviewValue;
        orderList[_orderId].helpfulTimeout = now + HELPFUL_TIMEOUT;
        orderList[_orderId].purchased = true;
        orderList[_orderId].seller.transfer(remain); //transfer to business
        emit Purchased(_orderId);
    }
    
    function postReview(uint256 _orderId, string memory _ipfsHash) public onlyCustomer onlyOwner(_orderId) onlyPurchaseDone(_orderId) {
        require(!orderList[_orderId].postedReview, "This order is used to post a review already");
        orderList[_orderId].postedReview = true;
        emit ReviewCreated(reviewID++, msg.sender, orderList[_orderId].seller, orderList[_orderId].productId, _ipfsHash);
    }
    
    function updateReview(uint256 _orderId, string memory _ipfsHash) public onlyCustomer onlyOwner(_orderId) {
        require(orderList[_orderId].postedReview, "Need to post review first");
        emit ReviewUpdated(_orderId, _ipfsHash);
    }
    
    function deleteReview(uint256 _orderId) public onlyCustomer onlyOwner(_orderId) {
        require(orderList[_orderId].postedReview, "Need to post review first");
        emit ReviewDeleted(_orderId);
    }
    
    function replyReview(uint256 _targetId, string memory _ipfsHash) public {
        require(orderList[_targetId].postedReview, "Review does not exist");
        emit ReviewReplied(msg.sender, _targetId, _ipfsHash);
    }
    
    function giveHelpful(uint256 _orderId, uint256 _targetId) public payable onlyCustomer onlyOwner(_orderId) onlyPurchaseDone(_orderId) {
        require(!orderList[_orderId].gaveHelpful, "This order is used to give helpful already");
        require(msg.sender != orderList[_targetId].customer, "Cannot give helpful to yourself");
        require(now < orderList[_orderId].helpfulTimeout, "Helpful giving time is up");
        
        uint256 reviewValue = productsOf[orderList[_orderId].seller][orderList[_orderId].productId].reviewValue;
        orderList[_targetId].customer.transfer(reviewValue);
        orderList[_orderId].gaveHelpful = true;
        emit HelpfulGiven(_targetId, _orderId, msg.sender);
    }
    
    function openIssue(
            uint256 _orderId, 
            uint256 _targetId, 
            uint256 _timeout, 
            uint256 _maxVal, 
            string memory _ipfsHash,
            uint256 _nonGivenOrder
    ) public payable onlyCustomer onlyOwner(_orderId) onlyPurchaseDone(_orderId) onlySameProduct(_orderId, _targetId) {
        require(_timeout <= now + ISSUE_MIN_TIMEOUT, "timeout must more than ISSUE_MIN_TIMEOUT");
         if (_maxVal > 0) require (msg.value <= _maxVal, "value exceed");
         
        Issue memory issue = Issue(_targetId, _timeout, _maxVal, 0);
        
        if (_nonGivenOrder >= 0) {
            require(!orderList[_nonGivenOrder].gaveHelpful, "This order was already used to give helpful");
            require(now >= orderList[_nonGivenOrder].helpfulTimeout, "This order reward still lock");
            
            issue.additionalReward = orderList[_nonGivenOrder].reviewValue;
            orderList[_nonGivenOrder].reviewValue = 0;
        }
       
        issueList.push(issue);
        voteList.push(Vote(false, msg.value, 0));
        
        voteList[voteList.length - 1].voteYesOf[msg.sender] = msg.value;

        emit IssueOpenned(issueList.length - 1, _targetId, _ipfsHash, msg.value);
    }
    
    function voteYes(
        uint256 _orderId, 
        uint256 _issueId, 
        string memory _ipfsHash
    ) public payable onlyCustomer onlyOwner(_orderId) onlyPurchaseDone(_orderId) 
      onlySameProduct(_orderId, issueList[_issueId].orderId) isVoteOpen(_orderId) {
        if (issueList[_issueId].maxVal > 0)
            require (msg.value + voteList[_issueId].voteYesOf[msg.sender] <= issueList[_issueId].maxVal, "value exceed");
        voteList[_issueId].voteYesTotal += msg.value;
        voteList[_issueId].voteYesOf[msg.sender] += msg.value;
        if (now >= issueList[_issueId].endTime.sub(EXTEND_VOTING_TIME))
            issueList[_issueId].endTime = issueList[_issueId].endTime.add(EXTEND_VOTING_TIME);
        emit Voted(_issueId, msg.sender, msg.value, _ipfsHash);
    }
    
    function voteNo(
        uint256 _orderId, 
        uint256 _issueId, 
        string memory _ipfsHash
    ) public payable onlyCustomer onlyOwner(_orderId) onlyPurchaseDone(_orderId) 
      onlySameProduct(_orderId, issueList[_issueId].orderId) isVoteOpen(_orderId) {
        if (issueList[_issueId].maxVal > 0)
            require (msg.value + voteList[_issueId].voteNoOf[msg.sender] <= issueList[_issueId].maxVal, "value exceed");
        voteList[_issueId].voteNoTotal += msg.value;
        voteList[_issueId].voteNoOf[msg.sender] += msg.value;
        if (now >= issueList[_issueId].endTime.sub(EXTEND_VOTING_TIME))
            issueList[_issueId].endTime = issueList[_issueId].endTime.add(EXTEND_VOTING_TIME);
        emit Voted(_issueId, msg.sender, msg.value, _ipfsHash);
    }
    
    function getVotingReward(uint256 _issueId) public isVoteClose(_issueId) {
        require(!voteList[_issueId].gotReward[msg.sender], "cannot get reward more than once");
        
        if (voteList[_issueId].voteYesTotal > voteList[_issueId].voteNoTotal) {
            uint256 total = voteList[_issueId].voteNoTotal + issueList[_issueId].additionalReward;
            uint256 propotion = voteList[_issueId].voteYesOf[msg.sender].div(voteList[_issueId].voteYesTotal);
            uint256 reward = voteList[_issueId].voteYesOf[msg.sender].add(propotion.mul(total));
            address(msg.sender).transfer(reward);
            
            if (!voteList[_issueId].rewardOpened)
                emit ReviewClosed(issueList[_issueId].orderId, _issueId);
                
        } else if (voteList[_issueId].voteYesTotal < voteList[_issueId].voteNoTotal) {
            uint256 total = voteList[_issueId].voteYesTotal + issueList[_issueId].additionalReward;
            uint256 propotion = voteList[_issueId].voteNoOf[msg.sender].div(voteList[_issueId].voteNoTotal);
            uint256 reward = voteList[_issueId].voteNoOf[msg.sender].add(propotion.mul(total));
            address(msg.sender).transfer(reward);
        } else {
            uint256 totalVote = voteList[_issueId].voteYesTotal.add(voteList[_issueId].voteNoTotal);
            uint256 userVote = voteList[_issueId].voteYesOf[msg.sender].add(voteList[_issueId].voteNoOf[msg.sender]);
            uint256 propotion = userVote.div(totalVote);
            uint256 reward = propotion.mul(totalVote.add(issueList[_issueId].additionalReward));
            address(msg.sender).transfer(reward);
        }
        
        voteList[_issueId].rewardOpened = true;
        voteList[_issueId].gotReward[msg.sender] = true;
        emit GotReward(_issueId, msg.sender);
    }
    
    function () external {
        
    }
    
}
