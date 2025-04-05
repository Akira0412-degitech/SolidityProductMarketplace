// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

pragma solidity ^0.8.0;

contract ProductContract is ReentrancyGuard {

    // Struct for storing order details
    struct Detail {
        address buyer;
        address seller;
        uint timestamp;
        uint howmany;
        uint amount;
        uint productId;
        bool rated;
    }

    // Struct for storing product information
    struct Product {
        string name;
        uint price;
        uint shortage;
        uint totalRating;
        uint timesRated;
    }

    mapping(uint => Product) Products;  // Mapping from productId to Product
    uint[] product_Ids; // Array to track all product IDs
    mapping(uint => Detail) Details; // Mapping from orderId to order Detail
    mapping(uint => mapping(address => bool)) hasRated; // Mapping to check if a user has rated an order
    mapping(address => uint[]) buyerOrders; // Mapping from buyer address to list of orderIds

    uint public productId; // Counter for product IDs
    uint public orderId;   // Counter for order IDs
    address public owner;  // Owner of the contract

    // Events for logging activities
    event ProductAdded(uint indexed productId, string name, uint price, uint shortage);
    event OrderCreated(uint indexed orderId, address indexed buyer, address seller, uint productId, uint amount);
    event OrderConfirmed(uint indexed orderId, address indexed buyer, address seller, uint amount);
    event OrderRated(uint indexed orderId, uint productId, uint rating);
    event ReceivedEther(address indexed sender, uint amount);
    event FallbackCalled(address indexed sender, uint amount, bytes data);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "Only owner can execute");
        _;
    }

    modifier validProductNum(uint _productId) {
        require(_productId > 0 && _productId <= productId, "Invalid productId");
        _;
    }

    modifier onlyBuyer(uint _orderId) {
        require(msg.sender == Details[_orderId].buyer, "Only buyer of this product can confirm");
        _;
    }

    modifier validOrderId(uint _orderId) {
        require(_orderId > 0 && _orderId <= orderId, "Invalid orderId");
        _;
    }

    // Reject direct ETH transfers
    receive() external payable {
        emit ReceivedEther(msg.sender, msg.value);
        revert("Direct Ether transfer is not allowed. Use createOrder instead.");
    }

    // Fallback function for undefined calls
    fallback() external payable {
        emit FallbackCalled(msg.sender, msg.value, msg.data);
        revert("Fallback triggered. Function does not exist.");
    }

    // Allows the owner to add a new product with its name, stock, and price
    function addProduct(string memory _name, uint _shortage, uint _price) public onlyOwner {
        require(_shortage > 0, "You need at least one product to register");
        productId++;
        Products[productId] = Product(_name, _price, _shortage, 0, 0);
        product_Ids.push(productId);
        emit ProductAdded(productId, _name, _price, _shortage);
    }

    // Allows the owner to restock an existing product
    function restockProducts(uint _productId, uint _amount) public onlyOwner{
        require(_amount > 0, "You sould restock at least one");
        Products[_productId].shortage += _amount;
    }

    // Allows buyers to place an order for a product by sending Ether
    function createOrder(address _to, uint _productId, uint _howmany) public payable validProductNum(_productId) {
        require(_to != address(0), "Invalid address");
        require(msg.value > 0, "You must send some Ether");
        require(_howmany * Products[_productId].price == msg.value, "Send correct amount of Ether");
        require(Products[_productId].shortage >= _howmany, "Not enough stock available");

        orderId++;
        Details[orderId] = Detail(msg.sender, _to, block.timestamp, _howmany, msg.value, _productId, false);
        buyerOrders[msg.sender].push(orderId);

        emit OrderCreated(orderId, msg.sender, _to, _productId, msg.value);
    }

    // Allows the buyer to confirm delivery and send Ether to the seller
    function confirmOrder(uint _orderId) public nonReentrant onlyBuyer(_orderId) validOrderId(_orderId) {
        Detail storage d = Details[_orderId];
        require(!d.rated, "Already confirmed");
        require(Products[d.productId].shortage > 0, "No shortage at the moment");

        (bool success, ) = d.seller.call{value: d.amount}("");
        require(success, "Failed to send");

        Products[d.productId].shortage -= d.howmany;
        d.rated = true;

        emit OrderConfirmed(_orderId, d.buyer, d.seller, d.amount);
    }

    // Allows the buyer to rate the product after confirming the order
    function rateOrder(uint _orderId, uint _rate) public onlyBuyer(_orderId) validOrderId(_orderId) {
        Detail storage d = Details[_orderId];
        require(d.rated == true, "You have not confirmed yet. you can rate after confirmation");
        require(_rate > 0 && _rate <= 5, "Rate should be between 1 and 5");
        require(hasRated[_orderId][msg.sender] == false, "Already rated");

        Products[d.productId].totalRating += _rate;
        Products[d.productId].timesRated++;
        hasRated[_orderId][msg.sender] = true;

        emit OrderRated(_orderId, d.productId, _rate);
    }

    // Returns the list of all orders made by the caller with product info
    function getMyOrders() public view returns(
        uint[] memory, string[] memory, uint[] memory, uint[] memory, uint[] memory){

        uint len = buyerOrders[msg.sender].length;
        uint[] memory orders = buyerOrders[msg.sender];
        string[] memory names = new string[](len);
        uint[] memory timestamps = new uint[](len);
        uint[] memory amounts = new uint[](len);
        uint[] memory productids = new uint[](len);

        for (uint i = 0; i < len; i ++){
            uint Id = orders[i];
            Detail storage d = Details[Id];
            uint p = d.productId;
            Product storage P = Products[p];

            names[i] = P.name;
            timestamps[i] = d.timestamp;
            amounts[i] = d.howmany == 0 ? 0 : d.amount * d.howmany;
            productids[i] = p;
        }
        return(orders, names, timestamps, amounts, productids);
    }

    // Returns full order details for a given order ID (only accessible by buyer)
    function getOrderDetail(uint _orderId) public view onlyBuyer(_orderId) validOrderId(_orderId) returns (
        address, address, uint, uint, uint, string memory, bool
    ) {
        Detail memory d = Details[_orderId];
        return (d.buyer, d.seller, d.timestamp, d.howmany, d.amount, Products[d.productId].name, d.rated);
    }

    // Returns average rating and rating count for a product
    function getAverageRateProduct(uint _productId) public view validProductNum(_productId) returns (
        string memory, uint, uint, uint
    ) {
        Product memory p = Products[_productId];
        uint average = p.timesRated == 0 ? 0 : p.totalRating / p.timesRated;
        return (p.name, p.totalRating, p.timesRated, average);
    }

    // Returns basic details for a single product
    function productDetails(uint _productId) public view returns (uint, string memory, uint, uint){
        Product memory p = Products[_productId];
        return(_productId, p.name, p.price, p.shortage);
    }

    // Returns information of all products stored in the contract
    function getAllProducts() public view returns(
        uint[] memory, string[] memory, uint[] memory, uint[] memory, uint[] memory
    ){  
        uint length = product_Ids.length;
        string[] memory name = new string[](length);
        uint[] memory price = new uint[](length);
        uint[] memory shortage = new uint[](length);
        uint[] memory rates = new uint[](length);

        for (uint i = 0; i < length; i ++){
            uint id = product_Ids[i];
            Product storage p = Products[id];
            name[i] = p.name;
            price[i] = p.price;
            shortage[i] = p.shortage;  
            rates[i] = p.timesRated == 0 ? 0: p.totalRating / p.timesRated;
        }
        return(product_Ids, name, price, shortage, rates);
    }

}
