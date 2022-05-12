// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MultiSigWallet {
    struct Transaction {
        uint256 value;
        bytes data;
        address to;
        bool executed;
        bool isERC20Transaction;
        uint8 confirmationCount;
    }

    IERC20 private _tokenContract;
    address[] private _owners;
    uint256 private _requiredConfirmationCount;
    mapping(address => bool) public isOwner;
    mapping(uint256 => mapping(address => bool)) private _isConfirmed;

    Transaction[] public transactions;

    event Depositted(address indexed sender, uint256 amount, uint256 balance);
    event TransactionSubmitted(
        address indexed owner,
        uint256 indexed txIndex,
        address indexed to,
        uint256 value,
        bytes data,
        bool isERC20Transaction
    );
    event TransactionConfirmed(address indexed owner, uint256 indexed txIndex);
    event ConfirmationRevoked(address indexed owner, uint256 indexed txIndex);
    event TransactionExecuted(address indexed owner, uint256 indexed txIndex);

    modifier onlyOwner() {
        require(isOwner[msg.sender], "MultiSigWallet: caller is not the owner");
        _;
    }

    modifier txExists(uint256 txIndex) {
        require(
            !transactions[txIndex].executed,
            "MultiSigWallet: tx already executed"
        );
        _;
    }

    modifier notExecuted(uint256 txIndex) {
        require(
            !transactions[txIndex].executed,
            "MultiSigWallet: tx already executed"
        );
        _;
    }

    modifier notConfirmed(uint256 txIndex) {
        require(
            !_isConfirmed[txIndex][msg.sender],
            "MultiSigWallet: tx already confirmed"
        );
        _;
    }

    constructor(
        address[] memory owners,
        uint256 requiredConfirmationCount,
        address tokenContract
    ) {
        require(owners.length > 0, "MultiSigWallet: owners required");
        require(
            requiredConfirmationCount > 0 &&
                requiredConfirmationCount <= owners.length,
            "MultiSigWallet: invalid number of required confirmations"
        );

        for (uint256 i = 0; i < owners.length; i++) {
            require(owners[i] != address(0), "MultiSigWallet: invalid owner");
            require(!isOwner[owners[i]], "MultiSigWallet: owner not unique");

            isOwner[owners[i]] = true;
            _owners.push(owners[i]);
        }

        _requiredConfirmationCount = requiredConfirmationCount;

        _tokenContract = IERC20(tokenContract);
    }

    receive() external payable {
        emit Depositted(msg.sender, msg.value, address(this).balance);
    }

    function submitTransaction(
        address to,
        uint256 value,
        bytes memory data,
        bool isERC20Transaction
    ) public onlyOwner {
        transactions.push(
            Transaction({
                value: value,
                data: data,
                to: to,
                executed: false,
                isERC20Transaction: isERC20Transaction,
                confirmationCount: 0
            })
        );

        emit TransactionSubmitted(
            msg.sender,
            transactions.length,
            to,
            value,
            data,
            isERC20Transaction
        );
    }

    function confirmTransaction(uint256 txIndex)
        public
        onlyOwner
        txExists(txIndex)
        notExecuted(txIndex)
        notConfirmed(txIndex)
    {
        Transaction storage transaction = transactions[txIndex];
        transaction.confirmationCount += 1;
        _isConfirmed[txIndex][msg.sender] = true;

        emit TransactionConfirmed(msg.sender, txIndex);
    }

    function executeTransaction(uint256 txIndex)
        public
        onlyOwner
        txExists(txIndex)
        notExecuted(txIndex)
    {
        Transaction storage transaction = transactions[txIndex];

        require(
            transaction.confirmationCount >= _requiredConfirmationCount,
            "MultiSigWallet: not enough confirmations"
        );

        transaction.executed = true;

        bool success;
        if (transaction.isERC20Transaction) {
            success = _tokenContract.transfer(
                transaction.to,
                transaction.value
            );
        } else {
            (success, ) = transaction.to.call{value: transaction.value}(
                transaction.data
            );
        }

        require(success, "MultiSigWallet: tx failed");

        emit TransactionExecuted(msg.sender, txIndex);
    }

    function revokeConfirmation(uint256 txIndex)
        public
        onlyOwner
        txExists(txIndex)
        notExecuted(txIndex)
    {
        Transaction storage transaction = transactions[txIndex];

        require(
            _isConfirmed[txIndex][msg.sender],
            "MultiSigWallet: tx not confirmed"
        );

        transaction.confirmationCount -= 1;
        _isConfirmed[txIndex][msg.sender] = false;

        emit ConfirmationRevoked(msg.sender, txIndex);
    }

    function getOwners() external view returns (address[] memory) {
        return _owners;
    }

    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }
}
