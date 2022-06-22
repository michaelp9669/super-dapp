// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract MultiSigWallet {
    struct Transaction {
        uint256 value;
        bytes data;
        address to;
        bool executed;
        uint8 confirmationCount;
    }

    address[] public owners;
    uint256 public requiredConfirmationCount;
    mapping(address => bool) public isOwner;
    mapping(uint256 => mapping(address => bool)) public isConfirmed;

    Transaction[] public transactions;

    event Depositted(address indexed sender, uint256 amount, uint256 balance);
    event TransactionSubmitted(
        address indexed owner,
        uint256 indexed txIndex,
        address indexed to,
        uint256 value,
        bytes data
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
            txIndex < transactions.length,
            "MultiSigWallet: tx does not exist"
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
            !isConfirmed[txIndex][msg.sender],
            "MultiSigWallet: tx already confirmed"
        );
        _;
    }

    constructor(
        address[] memory _owners,
        uint256 _requiredConfirmationCount,
        address _tokenContract
    ) {
        require(_owners.length > 0, "MultiSigWallet: owners required");
        require(
            _requiredConfirmationCount > 0 &&
                _requiredConfirmationCount <= _owners.length,
            "MultiSigWallet: invalid number of required confirmations"
        );

        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), "MultiSigWallet: invalid owner");
            require(!isOwner[_owners[i]], "MultiSigWallet: owner not unique");

            isOwner[_owners[i]] = true;
            owners.push(_owners[i]);
        }

        requiredConfirmationCount = _requiredConfirmationCount;
    }

    receive() external payable {
        emit Depositted(msg.sender, msg.value, address(this).balance);
    }

    function submitTransaction(
        address to,
        uint256 value,
        bytes memory data
    ) public onlyOwner {
        transactions.push(
            Transaction({
                value: value,
                data: data,
                to: to,
                executed: false,
                confirmationCount: 0
            })
        );

        emit TransactionSubmitted(
            msg.sender,
            transactions.length - 1,
            to,
            value,
            data
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
        isConfirmed[txIndex][msg.sender] = true;

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
            transaction.confirmationCount >= requiredConfirmationCount,
            "MultiSigWallet: not enough confirmations"
        );

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );

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
            isConfirmed[txIndex][msg.sender],
            "MultiSigWallet: tx not confirmed"
        );

        transaction.confirmationCount -= 1;
        isConfirmed[txIndex][msg.sender] = false;

        emit ConfirmationRevoked(msg.sender, txIndex);
    }

    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }
}
