# Global Travel Review Contract

This is the smart contract for global-level review system. Any user can participate in this system.

There are 2 types of users: 1) customer, and 2) seller.

Every user is a customer au the beginning state.

When a user add a product into the smart contract via "add product" function, he/she becomes a seller.

There are several functions in this system as followings:

1. ``addProduct(string memory _ipfsHash, uint256 _reviewValue)``: A user needs to upload the product information in form of JSON to the IPFS. Then upload its hash to the smart contract. And also define the "review value". The "review value" represents how much a seller willing to pay for a quality review posted to his/her product.

2. ``updateProduct(uint256 _productId, uint256 _reviewValue)``: A function to change review value of a product. When a seller wants to increase or decrease the amount of Ether paying for a quality review. Note that, updaing review value has timelock. After updating once, a seller needs to wait for a period of time. This way, the customers are more motivated to post reviews.

3. ``updateProductInfo(uint256 _productId, string memory _ipfsHash)``: A function to change a product information (IPFS hash). 

4. ``updateUserInfo(string memory _ipfsHash)``: Since an Ethereum address just represent the public key hash. There is no identity information of the review author. A user can upload his personal information to the IPFS and publish its hash to the smart contract. This function is an optional procedure. A user does not need to expose his identity. However, identity disclosure increases a review credibility.

5. ``createOrder(address payable _customer``, uint256 _productId, uint256 _price): When a customer wants to purchase something from a seller, he needs to request an order from the seller. Then a seller creates an order by determining the customer address, product id, and its price (in Ether). After that, a seller gets the order id and send back to the customer.

6. ``purchase(uint256 _orderId)``: After a customer gets an order id from a seller, he can purchase a product defined in the order. The product price is already defined when the product is created. In the step of purchasing, the money from a customer will be transfer to the smart contract. Then it is deduted by the product "review value" to keep in the smart contract. The remaining money will be transfered to the seller.

7. ``postReview(uint256 _orderId, string memory _ipfsHash)``: In this system, a customer can post a review only if he has purchased it. A customer can refer to a purchased order id to post a review.

8. ``updateReview(uint256 _orderId, string memory _ipfsHash)``: A posted review can be updated by calling this function. Note that, updating review is the step of pushing its latest version. All the previous versions are still available to every user.

9. ``deleteReview(uint256 _orderId)``: Like the update review function. When a customer calls this function, a review will be stamped as a deleted review. However, all the previous versions are still available publicly.

10. ``replyReview(uint256 _targetId, string memory _ipfsHash)``: Anyone can reply to a review by calling this function. The "target id" is the order id of the target review.

11. ``giveHelpful(uint256 _orderId, uint256 _targetId)``: When a customer has already purchased a product, he can give a helpful score to a review he thinks benefit to him in considering a product. The "review value" that is kept in the purchasing step will be transfered to the review author. A customer has another choice to ignore giving a helpful score. When the time passed for a while, he will not be able to give a helpful by using that order. Then the "review value" is available to be the additional reward for an issue. It can be picked up by anyone who opens an issue. (The timeout for helpful is defined by the HELPFUL_TIMEOUT variable in the smart contract. For now it is 30 days), 

12. ``openIssue(uint256 _orderId, uint256 _targetId, uint256 _timeout, uint256 _maxVal, string memory _ipfsHash,uint256 _nonGivenOrder)``: 
This is a function for fake review elimination. A customer who has purchased the same product with a likely fake review can open an issue to remove that review. He firstly refers to an order id who used to purchase the product. Then he refers to the target order id. After that he defines the issue options, which are timeout of the issue(the minimum value is defined in the ISSUE_MIN_TIMEOUT constant variable), and the maximum Ether of a user vote. He can upload an argument message to tell what is the mistake of that review. And lastly, if there exist an order that is not used for give a helpful score, he can use its "review value" to be the additional reward for the issue. The issuer can send Ether in the step of creating an issue. The amount of Ether represents the confidence level of his argument. This function can be called only if the issue still open.
       
13. ``voteYes(uint256 _orderId, uint256 _issueId, string memory _ipfsHash)``: A voter is limited to the customer who has purchased the same product. When he agrees with an issue, he can refer to his order id, and the issue id. He can also post some text for the reason he accepts that issue. Finally, he can transfer Ether to be the amount of vote he want to send.
    
14. ``voteNo(uint256 _orderId, uint256 _issueId, string memory _ipfsHash)``: Like the "vote yes" function, a voter is limited to only a customer who has purchased the same product. This function is the opposite side of the vote yes function.

15. ``getVotingReward(uint256 _issueId)``: When an issue time is up, the voting result is summarized. If the "yes" score is more than the "no" score, the target review is stamped to be a fake review. Losers lost their Ehter they transfer for voting. The winners get that Ether as the reward. The issue reward is divided by the portion of voting the winners send to the issue.
    
    
