// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./interfaces/IStaking.sol";
import "./interfaces/IAdmin.sol";
import "./interfaces/IAirdrops.sol";
import "./interfaces/IERC20D.sol";
import "hardhat/console.sol";

// TODO Write function for Emergency withdraw for all types of funds

contract Airdrops {
    using SafeERC20 for IERC20D;
    bytes32 public constant OPERATOR = keccak256("OPERATOR");

    IAdmin public admin;
    IStaking public staking;
    IERC20D public lpToken;

    uint256 public SBNB;
    uint256 public totalstakeBNB;
    uint256 public totalBNB;

    uint256 public SEBSC;
    uint256 public totalstakeEBSC;
    uint256 public totalEBSC;

    bool firstDistribution;

    address public marketingWallet; // Todo: setter function

    mapping(address => uint256) public s1BNB;
    mapping(address => uint256) public previousRewardBNB;

    mapping(address => uint256) public s1EBSC;
    mapping(address => uint256) public previousRewardEBSC;

    struct SaleState {
        bytes32 root;
        uint256 tokenAmount;
        uint256 lpAmount;
        uint256 valueAmount;
    }

    event Claimed(address user, address pool);

    mapping(address => SaleState) public saleStates;

    mapping(address => mapping(address => bool)) public claimed;
    // tokenSale => participants
    mapping(address => address[]) participants;

    //address of sale => user => claim

    constructor(
        address _staking,
        address _admin,
        address _lpToken
    ) {
        staking = IStaking(_staking);
        admin = IAdmin(_admin);
        lpToken = IERC20D(_lpToken);
    }

    receive() external payable {}

    function viewBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getReflection() public view returns (uint256) {
        return (lpToken.balanceOf(address(this)) - totalEBSC);
    }

    function pushEBSCAmount(uint256 _amount) external {
        totalEBSC += _amount * ((100 - lpToken._taxFee()) / 100);
    }

    function withdrawEBSC(address user, uint256 _amount) public {
        totalEBSC -= _amount;
        lpToken.safeTransfer(user, _amount);
    }

    function distributionEBSC() public {
        uint256 amount = getReflection();
        totalEBSC += amount * ((100 - lpToken._taxFee()) / 100);
        SEBSC +=
            (((amount * ((100 - lpToken._taxFee()) / 100)) + amount) * 10**18) /
            totalstakeEBSC;
        lpToken.safeTransferFrom(marketingWallet, address(this), amount);
    }

    function setShareForEBSCReward(address user) public {
        //stake[msg.sender] += amount;
        uint256 amount;
        (, , amount, ) = staking.getUserState(user);
        totalstakeEBSC += amount;
        //tokenTOLL.transferFrom(msg.sender, address(this),amount);
        s1EBSC[user] = SEBSC;
    }

    function userPendingEBSC(address user) public {
        uint256 amount;
        (, , amount, ) = staking.getUserState(user);
        previousRewardEBSC[user] += (amount * (SEBSC - s1EBSC[user])) / 10**18;
    }

    function getEBSCReward(address user, uint amount) external view returns(uint){
        return(previousRewardEBSC[user] + (amount * (SEBSC - s1EBSC[user])) / 10**18);
    }

    function claimEBSC() public {
        uint256 amount;
        uint256 lock;
        uint256 reward;
        (, lock, amount, ) = staking.getUserState(msg.sender);
        if (lock == 1) {
            reward = previousRewardEBSC[msg.sender];
        } else {
            reward =
                previousRewardEBSC[msg.sender] +
                (amount * (SEBSC - s1EBSC[msg.sender])) /
                10**18;
        }
        totalEBSC -= reward;
        s1EBSC[msg.sender] = SEBSC;
        lpToken.safeTransfer(msg.sender, reward);
    }

    function setTotalBNB(uint256 _amount) public {
        require(msg.sender == address(staking), "Only staking contract");
        totalBNB += _amount;
    }

    function setShareForBNBReward(address user) public {
        require(msg.sender == address(staking), "Only staking contract");
        //stake[msg.sender] += amount;
        uint256 amount;
        (, , amount, ) = staking.getUserState(user);
        totalstakeBNB += amount;
        //tokenTOLL.transferFrom(msg.sender, address(this),amount);
        s1BNB[user] = SBNB;
    }

    function distributionBNB() public {
        require(totalstakeBNB != 0 , "No user staked yet for reward distribution");
        if (!firstDistribution) {
            SBNB += (address(this).balance * 10**18) / totalstakeBNB;
            firstDistribution = true;
        } else {
            SBNB +=
                ((address(this).balance - totalBNB) * 10**18) /
                totalstakeBNB;
        }
    }

    function userPendingBNB(address user, uint256 amount) public {
        require(msg.sender == address(staking), "Only staking contract");
        // uint256 amount;
        // (, , amount, ) = staking.getUserState(user);
        previousRewardBNB[user] += (amount * (SBNB - s1BNB[user])) / 10**18;
        console.log(
            "previousRewardBNB[user]",
            previousRewardBNB[user],
            SBNB,
            s1BNB[user]
        );
    }

    function getBNBReward(address user, uint amount) external view returns(uint){
        return(previousRewardBNB[user] + (amount * (SBNB - s1BNB[user])) / 10**18);
    }

    function claimBNB() public {
        uint256 amount;
        uint256 lock;
        uint256 reward;
        uint256 tier;
        (tier, lock, amount, ) = staking.getUserState(msg.sender);
        if (uint8(tier) < 7) {
            reward = previousRewardBNB[msg.sender];
        } else {
            reward =
                previousRewardBNB[msg.sender] +
                (amount * (SBNB - s1BNB[msg.sender])) /
                10**18;
            //console.log("reward in else ",reward);
        }
        totalBNB -= reward;
        //console.log("totalBNB", totalBNB);
        s1BNB[msg.sender] = SBNB;
        // console.log(msg.sender.balance);
        (bool sent, ) = payable(msg.sender).call{value: reward}("");
        require(sent, "Failed to send Ether");
        //console.log(msg.sender.balance);
    }

    //    function unstake(uint amount) public {
    //     require(amount >0, 'Staking: amount should not be less than or equal to 0');
    //     require(amount <= stake[msg.sender]);
    //     previousReward[msg.sender] = previousReward[msg.sender] + (stake[msg.sender] * (S - s1[msg.sender]))/ 10 ** 18;
    //     stake[msg.sender] -= amount;
    //     totalstakeToken -= amount;
    //     tokenTOLL.transfer(msg.sender,amount);
    //     s1[msg.sender] = S;
    //  }

    modifier onlyOperator() {
        require(
            admin.hasRole(OPERATOR, msg.sender),
            "sender is not an operator"
        );
        _;
    }

    modifier onlyExits(address _pool) {
        require(admin.tokenSalesM(_pool), "pool does not exist yet");
        _;
    }
    modifier noRoot(address _pool) {
        require(saleStates[_pool].root == bytes32(0), "root is already set");
        _;
    }
    modifier validation(address _address) {
        require(_address != address(0), "zero address");
        _;
    }

    function setLptoken(address _address)
        external
        validation(_address)
        onlyOperator
    {
        lpToken = IERC20D(_address);
    }

    function setStaking(address _address)
        external
        validation(_address)
        onlyOperator
    {
        staking = IStaking(_address);
    }

    function setAdmin(address _address)
        external
        validation(_address)
        onlyOperator
    {
        admin = IAdmin(_address);
    }

    function depositAssets(
        address _pool,
        uint256 _tokenAmount,
        uint256 _lpAmount
    ) external payable {
        if (_tokenAmount > 0) {
            saleStates[_pool].tokenAmount += _tokenAmount;
            ITokenSale.Params memory p = admin.getParams(_pool);
            IERC20D(p.token).safeTransferFrom(
                msg.sender,
                address(this),
                _tokenAmount
            );
        }
        if (_lpAmount > 0) {
            saleStates[_pool].lpAmount += _lpAmount;
            lpToken.safeTransferFrom(msg.sender, address(this), _lpAmount);
        }
        if (msg.value > 0) {
            saleStates[_pool].valueAmount += msg.value;
        }
    }

    function setRoot(address _pool, bytes32 _root)
        external
        onlyExits(_pool)
        noRoot(_pool)
        onlyOperator
    {
        saleStates[_pool].root = _root;
    }

    function application(address _pool)
        external
        onlyExits(_pool)
        noRoot(_pool)
    {
        uint256 t;
        uint256 l;
        (t, l, , ) = staking.getUserState(msg.sender);
        require(_canApply(t, l), "cannot apply");
        participants[_pool].push(msg.sender);
    }

    function claim(
        address _pool,
        address _account,
        uint256 _tokenAmount,
        uint256 _lpAmount,
        uint256 _valueAmount,
        bytes32[] calldata _proof
    ) external onlyExits(_pool) {
        require(
            saleStates[_pool].root != bytes32(0),
            "pool does not have root"
        );
        require(!claimed[_pool][_account], "drop already claimed");
        ITokenSale.Params memory p = admin.getParams(_pool);
        require(p.privateStart <= block.timestamp, "pool has not started yet");
        bytes32 leaf = keccak256(
            abi.encodePacked(_account, _tokenAmount, _lpAmount, _valueAmount)
        );
        require(
            MerkleProof.verify(_proof, saleStates[_pool].root, leaf),
            "invalid proof"
        );
        claimed[_pool][_account] = true;
        if (_tokenAmount > 0) {
            IERC20D(p.token).safeTransfer(_account, _tokenAmount);
        }
        if (_lpAmount > 0) {
            lpToken.safeTransfer(_account, _lpAmount);
        }
        if (_valueAmount > 0) {
            (bool success, ) = _account.call{value: _valueAmount}("");
            require(success);
        }
        emit Claimed(_account, _pool);
    }

    function getParticipants(
        address _pool,
        uint256 cursor,
        uint256 _number
    ) external view returns (address[] memory values, uint256 newCursor) {
        uint256 length = _number;
        if (length > participants[_pool].length - cursor) {
            length = participants[_pool].length - cursor;
        }
        values = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            values[i] = participants[_pool][cursor + i];
        }

        return (values, cursor + length);
    }

    function takeLocked(address _pool) external onlyExits(_pool) onlyOperator {
        ITokenSale.Params memory p = admin.getParams(_pool);
        uint256 tokenAmount = saleStates[_pool].tokenAmount;
        uint256 valueAmount = saleStates[_pool].valueAmount;
        uint256 lpAmount = saleStates[_pool].lpAmount;
        if (tokenAmount > 0) {
            IERC20D(p.token).safeTransfer(admin.wallet(), tokenAmount);
        }
        if (tokenAmount > 0) {
            lpToken.safeTransfer(admin.wallet(), lpAmount);
        }
        if (valueAmount > 0) {
            (bool success, ) = admin.wallet().call{value: valueAmount}("");
            require(success);
        }
    }

    function _canApply(uint256 _tier, uint256 _level)
        internal
        pure
        returns (bool can)
    {
        if (_level == 4 || (uint8(_level) > 0 && uint8(_tier) > 2)) {
            can = true;
        }
    }
}