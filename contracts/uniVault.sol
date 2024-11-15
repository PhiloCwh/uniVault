
// SPDX-License-Identifier: MIT
//import "./lptoken.sol";
//import "./IERC20.sol";
//import "./IERC20.sol";
import "./lptoken.sol";
import "./standToken.sol";
import "./stakeToken.sol";



pragma solidity ^0.8.17;

contract AMM {
//全局变量    

    uint feeForLp;


    uint constant ONE_ETH = 10 ** 18;
    mapping(address => address) public pairCreator;//lpAddr pairCreator
    address [] public lpTokenAddressList;//lptoken的数组


    mapping(address => uint) reserve;//第一个address是lptoken的address ，第2个是相应token的资产，uint是资产的amount
    mapping (address => uint) ethReserve;
    //borrow
    mapping (address => mapping (address => uint)) userBorrowedAmount; //user token amount
    mapping (address => uint) borrowedAmount; //token amount
    mapping (address => uint) ethBalance;
    mapping (address => mapping (address => uint)) userEthBalance;//user token amount

    //staking

    mapping (address => mapping (address => uint)) userStakingPoin;

    mapping (address => mapping (address => uint)) userStakingReserve;//user toekn
    mapping (address => uint) stakingReserve;


    //检索lptoken
    mapping(address => address) findLpToken;

    //sstoken
    //mapping (address => address) findStakeToken;
    //mapping (address => uint) public stakeTokenShare;
    mapping (address => mapping (address => uint)) public userStakeTokenShare;// user token share
    mapping (address => uint) public stakeTokenShareTotalSupply;






    mapping (address => uint) public liquidatePool;//token eth
    //IWETH immutable WETH;
    //address immutable WETHAddr;

    //meme

    mapping (address => address) public userCreatedToken;
    mapping (address => mapping (address => uint)) public tokenLockingTime;//user token time
    mapping (address => mapping (address => uint)) public tokenLockingTimeStar;//user token starTime

    event Message(string message);
    event BuyTokenInfo(address indexed token,address indexed user,uint ethAmount,uint tokenOutAmount,uint time);
    event SellTokenInfo(address indexed token,address indexed user,uint ethAmount,uint tokenAmount,uint time);

    event AddLiquidity(address indexed token,address indexed user, uint ethAmount,uint tokenAmount,uint time);



    constructor(uint _fee)
    {
        feeForLp = _fee;
    }

    receive() payable external {}

    modifier reEntrancyMutex() {
        bool _reEntrancyMutex;

        require(!_reEntrancyMutex,"FUCK");
        _reEntrancyMutex = true;
        _;
        _reEntrancyMutex = false;

    }

    function getLpInfo(address _token) public view returns(uint _tokenLpReserve,uint _tokenStakingReserve, uint _ethReserve,uint _borrowedAmount,uint _feeForLp){

        _tokenLpReserve = reserve[_token];
        _tokenStakingReserve = stakingReserve[_token];
        _ethReserve = ethReserve[_token];
        _borrowedAmount = borrowedAmount[_token];
        _feeForLp = feeForLp;


    }

    function stakeToken(address _token, uint _amount) public {
        
        address user = msg.sender;
        IERC20 token = IERC20(_token);

        
        
        token.transferFrom(user, address(this), _amount);




        //share

        uint share =   calShareAmount(_token,_amount);

        //userStakingReserve[user][_token] += _amount;
        stakingReserve[_token] += _amount;
        userStakeTokenShare[msg.sender][_token] += share;

        stakeTokenShareTotalSupply[_token] += share;



        

        
    }

    function calShareAmount(address _token,uint _amount) public view returns(uint){
        //shares_received = assets_deposited * totalSupply() / totalAssets();


        uint share = _amount * (stakeTokenShareTotalSupply[_token] + ONE_ETH) /(stakingReserve[_token] + 1);
        return share;
    }

    function calShareTokenUnstakeAmount(address _token, uint _share) public view returns(uint){
        return 99 * stakingReserve[_token] * _share / stakeTokenShareTotalSupply[_token] / 100;
    }


    function unStakeToken(address _token, uint _share) public {
        address user = msg.sender;
        require((_share > 0)&&(_share <= userStakeTokenShare[user][_token]),"invalid amount");
        IERC20 token = IERC20(_token);

        uint amount = calShareTokenUnstakeAmount(_token,_share);
        uint amountWithFee = amount * 99 / 100;

        token.transfer(user, amountWithFee);

        //userStakingReserve[user][_token] -= _amount;
        stakingReserve[_token] -= amountWithFee;  

        userStakeTokenShare[user][_token] -= _share;

        stakeTokenShareTotalSupply[_token] -= _share;      
    }

    //borrowlogic

    function calBuyTokenOutputAmount(address _token, uint _amount) public view returns(uint){
        uint reserveIn = ethReserve[_token];
        uint reserveOut = reserve[_token];

        //swap logic

        //token.transferFrom(msg.sender, address(this), _amount);


        uint amountInWithFee = (_amount * (10000 - feeForLp)) / 10000;
        uint amountOut = (reserveOut * amountInWithFee) / (reserveIn + amountInWithFee);
        return amountOut;
    }

    function calSellTokenOutputAmount(address _token, uint _amount) public view returns(uint){
        uint reserveIn = reserve[_token];
        uint reserveOut = ethReserve[_token];

        //swap logic

        //token.transferFrom(msg.sender, address(this), _amount);


        uint amountInWithFee = (_amount * (10000 - feeForLp)) / 10000;
        uint amountOut = (reserveOut * amountInWithFee) / (reserveIn + amountInWithFee);
        return amountOut;
    }

    function calExactOutputTokenAmount(address _token, uint _amountOut) public view returns(uint){
        uint reserveIn = ethReserve[_token];
        uint reserveOut = reserve[_token];

        //swap logic

        //token.transferFrom(msg.sender, address(this), _amount);


        uint amountInWithFee = (_amountOut * (10000 - feeForLp)) / 10000;
        uint amountOut = (reserveOut * amountInWithFee) / (reserveIn + amountInWithFee);
        return amountOut;
    }

    function calSwapEthInAmount(address _token, uint _amountOut) public view returns (uint amountInWithFee) {

        require(_amountOut > 0, "amount in = 0");
        //require(_tokenIn != _tokenOut);
        //require(_amountIn >= 1000, "require amountIn >= 1000 wei token");

        //variable

        
        uint reserveIn = ethReserve[_token];
        uint reserveOut = reserve[_token];

        //swap logic



        //uint amountInWithFee = (_amountIn * 997) / 1000;
        // amountOut = (reserveOut * amountInWithFee) / (reserveIn + amountInWithFee);
        // amountOut*(reserveIn + amountInWithFee) = (reserveOut * amountInWithFee);
        // amountOut*amountInWithFee + amountOut*reserveIn = reserveOut * amountInWithFee;
        // amountOut*amountInWithFee - reserveOut * amountInWithFee= amountOut*reserveIn
        // amountInWithFee(reserveOut - amountOut) = amountOut*reserveIn;
        uint amountIn = _amountOut*reserveIn/(reserveOut - _amountOut);
        amountInWithFee = amountIn*1000/997;




    }
//borrow
    function stakeEthBorrowAsset(address _token,uint _percent) public payable {
        require((_percent > 0)&&(_percent < 71),"require percent 0---100");
        uint amount = msg.value;
        require(amount >= 100,"require more than 100wei");
        address user = msg.sender;
        uint amountOut = calBuyTokenOutputAmount(_token, amount) * _percent / 100;

        IERC20 token = IERC20(_token);
        token.transfer(user, amountOut);

        borrowedAmount[_token] += amountOut + amountOut * 3 / 100;
        userBorrowedAmount[user][_token] += amountOut + amountOut * 3 / 100;


        //update data

        stakingReserve[_token] += amountOut * 3 / 100;
        userEthBalance[user][_token] += amount;
        ethBalance[_token] += amount;

    }

    function addEthFund(address _token) public payable {
        uint amount = msg.value;
        address user = msg.sender;
        userEthBalance[user][_token] += amount;
        ethBalance[_token] += amount;
    }

    function checkPositionInfo(address _user,address _token)public view returns(uint _ethVault,uint _tokenVault,uint _borrowedTokenAmount ,uint _userEth,uint _userBorrowedTokenAmount,uint _healthyFactor){

        _ethVault = ethBalance[_token];
        _tokenVault = stakingReserve[_token];
        _borrowedTokenAmount = borrowedAmount[_token];
        _userEth = userEthBalance[_user][_token];
        _userBorrowedTokenAmount = userBorrowedAmount[_user][_token];
        uint userDebt = userBorrowedAmount[_user][_token];
        uint ethAmountWithToken = calBuyTokenOutputAmount(_token, userEthBalance[_user][_token]);
        if((_userEth == 0)||(_userBorrowedTokenAmount == 0)){
            _healthyFactor = 0;
        }else{
            _healthyFactor = userDebt * 10000 / ethAmountWithToken;
        }
        

    }

    function BorrowAsset(address _token, uint _amount) public  {
        
        //uint amount = msg.value;
        require(_amount >= 100,"require more than 100wei");
        address user = msg.sender;


        uint maxBorrowAmount = calBuyTokenOutputAmount(_token, userEthBalance[user][_token]) * 71 / 100;
        
        IERC20 token = IERC20(_token);
        token.transfer(user, _amount);


        stakingReserve[_token] += _amount * 3 / 100;

        borrowedAmount[_token] += _amount + _amount * 3 / 100;
        userBorrowedAmount[user][_token] += _amount + _amount * 3 / 100;
        //userEthBalance[user][_token] += amount;
        require(borrowedAmount[_token] < maxBorrowAmount,"exceed 70% token to borrow ,pls add eth fund");


    }

//repay 

    function repayAllToken(address _token) public {
        address payable user = payable ( msg.sender);
        uint amount = userBorrowedAmount[user][_token];

        IERC20 token = IERC20(_token);
        token.transferFrom(user,address(this), amount);
        borrowedAmount[_token] -= amount;
        userBorrowedAmount[user][_token] = 0;

        user.transfer(userEthBalance[user][_token]);
        ethBalance[_token] -= userEthBalance[user][_token];
        userEthBalance[user][_token] = 0;
        
        

    }

//liquidate

    function liquidate(address _user,address _token) public {
        address payable liquidator = payable (msg.sender);
        //maxBorrowAmount = calBuyTokenOutputAmount(_token, userEthBalance[user][_token]) * 71 / 100;
        uint userDebt = userBorrowedAmount[_user][_token];
        uint ethAmountWithToken = calBuyTokenOutputAmount(_token, userEthBalance[_user][_token]);

        //cal healthy factor  token basic uint: userDebt * 10000/userAsset = ??.?? %
        uint healthyFactor = userDebt * 10000 / ethAmountWithToken;

        require(healthyFactor > 8000,"require healthy factor > 8000");

        liquidator.transfer(userEthBalance[_user][_token]);

        IERC20 token = IERC20(_token);
        token.transferFrom(liquidator,address(this),userDebt);
        

        userEthBalance[_user][_token] = 0;
        userBorrowedAmount[_user][_token] = 0;
        borrowedAmount[_token] -= userDebt;



    }

    // function shortToken(address _token) public payable {
    //     uint amount = msg.value;
    //     require(amount >= 1000,"require more than 1000wei");
    //     address user = msg.sender;
    //     uint amountOut = calBuyTokenOutputAmount(_token, amount) * 50 / 100;

    //     IERC20 token = IERC20(_token);
    //     token.transfer(user, amountOut);

    //     borrowedAmount[_token] += amountOut + amountOut * 3 / 100;
    //     userBorrowedAmount[user][_token] += amountOut + amountOut * 3 / 100;
    //     userEthBalance[user][_token] += amount;

    //     sellToken(_token, amountOut);    
    // }

    // function closePosition(address _token) public payable {
    //     address user = msg.sender;
    //     uint userDebt = userBorrowedAmount[user][_token];
    //     uint userAsset = userEthBalance[user][_token];
    //     uint ethDebt;

    //     ethDebt = calSwapEthInAmount(_token, userDebt);
    //     //ethDebt = calBuyTokenOutputAmount(_token, userDebt);
    //     require(msg.value == ethDebt,"invalid eth amount");
    //     address payable  receiver = payable (msg.sender);
    //     receiver.transfer(userAsset);

    //     userBorrowedAmount[user][_token] = 0;
    //     userEthBalance[user][_token] = 0;
    //     borrowedAmount[_token] -= userDebt;

    // }

    function calClosePositionEthAmount(address _token) public view returns(uint ethDebt){
        address user = msg.sender;
        uint userDebt = userBorrowedAmount[user][_token];
        //uint userAsset = userEthBalance[user][_token];
        ethDebt = calSwapEthInAmount(_token, userDebt);


        //ethDebt = calBuyTokenOutputAmount(_token, userDebt);
    }

    function calRedeemEthAmount(address _token, uint _amount) public view returns(uint) {
        address user = msg.sender;
        uint userDebt = userBorrowedAmount[user][_token];
        uint userAsset = userEthBalance[user][_token];

        uint factor = ONE_ETH * _amount / userDebt;

        uint ethAmount = factor * userAsset / ONE_ETH;

        return ethAmount;
    }

    // function calUserHelthyFactor(address _user,address _token) public view returns(uint helthyFactor) {

        
    //     uint userDebt = userBorrowedAmount[_user][_token];
    //     uint userAsset = userEthBalance[_user][_token];

    //     if((userDebt == 0)||(userAsset == 0)){
    //         helthyFactor = 0;
    //     }else{

    //         uint userDebtToEth = calSellTokenOutputAmount(_token, userDebt);

    //         helthyFactor = ONE_ETH * userDebtToEth / userAsset;
    //     }

        


    //}

    // function liquidate(address _user, address _token) public {
    //     if(calUserHelthyFactor(_user, _token) >= 80 * 10**16){
    //         uint userDebt = userBorrowedAmount[_user][_token];
    //         uint userAsset = userEthBalance[_user][_token];
    //         IERC20 token = IERC20(_token);
    //         token.transferFrom(msg.sender, address(this),userDebt);
    //         payable (msg.sender).transfer(userAsset * 95 / 100);
    //         liquidatePool[_token] += userAsset * 5 / 100;

    //         userEthBalance[_user][_token] = 0;
    //         userBorrowedAmount[_user][_token] = 0;
    //         borrowedAmount[_token] -= userDebt;

    //     }
    // }

    // function liquidate2(address _user, address _token) public {
    //     if(calUserHelthyFactor(_user, _token) >= 90 * 10**16){
    //         uint userDebt = userBorrowedAmount[_user][_token];
    //         uint userAsset = userEthBalance[_user][_token];
    //         //IERC20 token = IERC20(_token);
    //         //token.transferFrom(msg.sender, address(this),userDebt);

    //         reserve[_token] -= userDebt;
    //         ethReserve[_token] += userAsset * 90 / 100;
    //         payable (msg.sender).transfer(userAsset * 5 / 100);
    //         liquidatePool[_token] += userAsset * 5 / 100;

    //     }
    // }

    

    // function redeemEth(address _token, uint _amount) public {
    //     address user = msg.sender;
    //     uint userDebt = userBorrowedAmount[user][_token];
    //     uint userAsset = userEthBalance[user][_token];

    //     uint factor = ONE_ETH * _amount / userDebt;

    //     uint ethAmount = factor * userAsset / ONE_ETH;

    //     userBorrowedAmount[user][_token] -= _amount;
    //     userEthBalance[user][_token] -= ethAmount;
    //     borrowedAmount[_token] -= _amount;


    //     payable (user).transfer(ethAmount);
    // }


    function calAddLiquidityEthAmount(address _token,uint _amount) public view returns(uint){
        if(findLpToken[_token] != address(0))
        {
            uint amount1 = ethReserve[_token] * _amount / reserve[_token];
            return amount1;
        }else{
            return 0;
        }
    }

    // function createTokenAndAddLiquidity(string memory _name,string memory _simple,uint _amount,uint _lockingTime) public payable returns (uint shares) {
    //     createToken( msg.sender,_name, _simple, _amount);
        
    //     Lp lptoken;//lptoken接口，为了mint 和 burn lptoken

    //     address _token = userCreatedToken[msg.sender];
    //     _amount = _amount * 10**18;
        
    //     require(_amount > 0 ,"require _amount > 0 ");
    //     //require(_token0 != _token1, "_token0 == _token1");
    //     //IERC20 token = IERC20(_token);
    //     //IERC20 token1 = IERC20(_token1);
    //     //token.transferFrom(msg.sender, address(this), _amount);
    //     //token1.transferFrom(msg.sender, address(this), _amount1);
    //     address lptokenAddr;
    //     //force cal amount1
    //     // if (findLpToken[_token] != address(0)) {
    //     //     lptokenAddr = findLpToken[_token];
    //     //     uint _amount1 = ethReserve[_token] * _amount / reserve[_token];
    //     //     require(msg.value == _amount1,"require eth amount == _amount1");
    //     // }

    //         //当lptoken = 0时，创建lptoken
    //     shares = _sqrt(_amount * msg.value);
    //     createPair(_token);
    //     lptokenAddr = findLpToken[_token];
    //     lptoken = Lp(lptokenAddr);//获取lptoken地址
    //     pairCreator[lptokenAddr] = msg.sender;
            
    
    //     require(shares > 0, "shares = 0");
    //     lptoken.mint(msg.sender,shares);
        
    //     reserve[_token] += _amount;
    //     ethReserve[_token] += msg.value;

    //     //memelaunch
    //     tokenLockingTime[msg.sender][_token] = _lockingTime;
    //     tokenLockingTimeStar[msg.sender][_token] = block.timestamp;
    // }

    function createTokenAndAddLiquidity2(string memory _name,string memory _simple,uint _amount,uint _lockingTime,uint _stakeAmount) public payable returns (uint shares) {
        createToken( msg.sender,_name, _simple, _amount);
        
        Lp lptoken;//lptoken接口，为了mint 和 burn lptoken

        address _token = userCreatedToken[msg.sender];
        _amount = _amount * 10**18;
        
        require(_amount > 0 ,"require _amount > 0 ");
        //require(_token0 != _token1, "_token0 == _token1");
        //IERC20 token = IERC20(_token);
        //IERC20 token1 = IERC20(_token1);
        //token.transferFrom(msg.sender, address(this), _amount);
        //token1.transferFrom(msg.sender, address(this), _amount1);
        address lptokenAddr;
        //force cal amount1
        // if (findLpToken[_token] != address(0)) {
        //     lptokenAddr = findLpToken[_token];
        //     uint _amount1 = ethReserve[_token] * _amount / reserve[_token];
        //     require(msg.value == _amount1,"require eth amount == _amount1");
        // }

            //当lptoken = 0时，创建lptoken
        shares = _sqrt(_amount * msg.value);
        createPair(_token);
        lptokenAddr = findLpToken[_token];
        lptoken = Lp(lptokenAddr);//获取lptoken地址
        pairCreator[lptokenAddr] = msg.sender;
            
    
        require(shares > 0, "shares = 0");
        lptoken.mint(msg.sender,shares);
        
        reserve[_token] += _amount;
        ethReserve[_token] += msg.value;

        //memelaunch


        //stakeToken(_token, _stakeAmount * ONE_ETH);

        //stakingReserve += _stakeAmount;

        stakeToken(_token, _stakeAmount);

        tokenLockingTime[msg.sender][_token] = _lockingTime;
        tokenLockingTimeStar[msg.sender][_token] = block.timestamp;

        emit AddLiquidity(_token, msg.sender, msg.value, _amount, block.timestamp);
    }


    function addLiquidityWithEth(address _token,uint _amount,uint _lockingTime,uint _stakeAmount) public payable returns (uint shares) {
        
        Lp lptoken;//lptoken接口，为了mint 和 burn lptoken
        
        require(_amount > 0 ,"require _amount > 0 ");
        //require(_token0 != _token1, "_token0 == _token1");
        IERC20 token = IERC20(_token);
        //IERC20 token1 = IERC20(_token1);
        token.transferFrom(msg.sender, address(this), _amount);
        //token1.transferFrom(msg.sender, address(this), _amount1);
        address lptokenAddr;
        //force cal amount1
        if (findLpToken[_token] != address(0)) {
            lptokenAddr = findLpToken[_token];
            uint _amount1 = ethReserve[_token] * _amount / reserve[_token];
            require(msg.value == _amount1,"require eth amount == _amount1");
        }

        if (findLpToken[_token] == address(0)) {
            //当lptoken = 0时，创建lptoken
            shares = _sqrt(_amount * msg.value);
            createPair(_token);
            lptokenAddr = findLpToken[_token];
            lptoken = Lp(lptokenAddr);//获取lptoken地址
            pairCreator[lptokenAddr] = msg.sender;
            //stakeToken
            //stakeTokenShareTotalSupply[_token] = ONE_ETH;
            
            
        } else {
            lptoken = Lp(lptokenAddr);//获取lptoken地址
            shares = _min(
                (_amount * lptoken.totalSupply()) / reserve[_token],
                (msg.value * lptoken.totalSupply()) / ethReserve[_token]
            );
            //获取lptoken地址
        }
        require(shares > 0, "shares = 0");
        lptoken.mint(msg.sender,shares);
        
        reserve[_token] += _amount;
        ethReserve[_token] += msg.value;
        stakeToken(_token, _stakeAmount);

        tokenLockingTime[msg.sender][_token] = _lockingTime;
        tokenLockingTimeStar[msg.sender][_token] = block.timestamp;

        emit AddLiquidity(_token, msg.sender, msg.value, _amount, block.timestamp);

        
    }
    //移除流动性

    function calTokenLockingLeftTime(address _user,address _token)public view returns(uint){

        
        if((block.timestamp - tokenLockingTimeStar[_user][_token]) <= tokenLockingTime[_user][_token]){
            return tokenLockingTime[_user][_token] - (block.timestamp - tokenLockingTimeStar[_user][_token]);
        }else{
            return 0;
        }

    }

    function removeLiquidity(
        address _token,
        uint _shares
    ) external returns (uint amount0, uint amount1) {
        require(calTokenLockingLeftTime(msg.sender,_token) == 0,"your lp token is locking now");
        Lp lptoken;//lptoken接口，为了mint 和 burn lptoken
        IERC20 token = IERC20(_token);
        address lptokenAddr = findLpToken[_token];

        lptoken = Lp(lptokenAddr);

        if(pairCreator[lptokenAddr] == msg.sender)
        {
            require(lptoken.balanceOf(msg.sender) - _shares > 100 ,"paieCreator should left 100 wei lptoken in pool");
        }

        amount0 = (_shares * reserve[_token]) / lptoken.totalSupply();//share * totalsuply/bal0
        amount1 = (_shares * ethReserve[_token]) / lptoken.totalSupply();
        require(amount0 > 0 && amount1 > 0, "amount0 or amount1 = 0");

        lptoken.burn(msg.sender, _shares);

        reserve[_token] -= amount0;
        ethReserve[_token] -= amount1;
        

        token.transfer(msg.sender, amount0);
        address payable user = payable( msg.sender);

        user.transfer(amount1);


    }

    //交易

    // function swapWithETH(address _tokenOut,uint _disirSli) public payable reEntrancyMutex
    // {
    //     uint amountIn = msg.value;
    //     WETH.depositETH{value : amountIn}();
    //     swapByLimitSli(WETHAddr,_tokenOut,amountIn, _disirSli);
    // }


    // function swapToETH(address _tokenIn, uint _amountIn, uint _disirSli)public {
    //     uint amountOut = swapByLimitSli(_tokenIn,WETHAddr,_amountIn, _disirSli);
    //     WETH.withdrawETH(amountOut);
    //     address payable user = payable(msg.sender);
    //     user.transfer(amountOut);

    // }

    function buyToken(address _token,uint _disirSli) public payable returns (uint amountOut) {
        require(
            findLpToken[_token] != address(0),
            "invalid token"
        );

        

        
        uint amountIn = msg.value;

        


        require(amountIn > 0, "amount in = 0");
        //require(_tokenIn != _tokenOut);
        require(amountIn >= 1000, "require amountIn >= 1000 wei token");

        //variable

        IERC20 token = IERC20(_token);
        //address lptokenAddr = findLpToken[_token];
        uint reserveIn = ethReserve[_token];
        uint reserveOut = reserve[_token];

        //swap logic

        //token.transferFrom(msg.sender, address(this), _amount);


        uint amountInWithFee = (amountIn * (10000 - feeForLp)) / 10000;
        amountOut = (reserveOut * amountInWithFee) / (reserveIn + amountInWithFee);
        token.transfer(msg.sender, amountOut);

        setSli(amountIn, reserveIn, reserveOut, _disirSli);

        //update data
        ethReserve[_token] += amountIn;
        reserve[_token] -= amountOut;

        emit BuyTokenInfo(_token,msg.sender, msg.value, amountOut, block.timestamp);


    }


    function sellToken(address _token, uint _amount,uint _disirSli) public returns (uint amountOut) {
        require(
            findLpToken[_token] != address(0),
            "invalid token"
        );
        //require(_amountIn > 0, "amount in = 0");
        //require(_tokenIn != _tokenOut);
        require(_amount >= 1000, "require amountIn >= 1000 wei token");

        //variable

        IERC20 token = IERC20(_token);
        //address lptokenAddr = findLpToken[_token];
        uint reserveIn = reserve[_token];
        uint reserveOut = ethReserve[_token];

        //swap logic

        token.transferFrom(msg.sender, address(this), _amount);


        uint amountInWithFee = (_amount * (10000 - feeForLp)) / 10000;
        amountOut = (reserveOut * amountInWithFee) / (reserveIn + amountInWithFee);


        //tokenOut.transfer(msg.sender, amountOut);

        setSli(_amount, reserveIn, reserveOut, _disirSli);

        //update data
        reserve[_token] += _amount; 
        ethReserve[_token] -= amountOut;

        address payable user = payable( msg.sender);

        user.transfer(amountOut);

        emit SellTokenInfo(_token,msg.sender, amountOut, _amount, block.timestamp);



        //_update(lptokenAddr,_tokenIn, _tokenOut, totalReserve0, totalReserve1);
    }
    //交易携带滑点限制
    // function swapByLimitSli(address _tokenIn, address _tokenOut, uint _amountIn, uint _disirSli) public returns(uint amountOut){
    //     require(
    //         findLpToken[_tokenIn][_tokenOut] != address(0),
    //         "invalid token"
    //     );
    //     require(_amountIn > 0, "amount in = 0");
    //     require(_tokenIn != _tokenOut);
    //     require(_amountIn >= 1000, "require amountIn >= 1000 wei token");

    //     IERC20 tokenIn = IERC20(_tokenIn);
    //     IERC20 tokenOut = IERC20(_tokenOut);
    //     address lptokenAddr = findLpToken[_tokenIn][_tokenOut];
    //     uint reserveIn = reserve[lptokenAddr][_tokenIn];
    //     uint reserveOut = reserve[lptokenAddr][_tokenOut];

    //     tokenIn.transferFrom(msg.sender, address(this), _amountIn);



    //     uint amountInWithFee = (_amountIn * 997) / 1000;
    //     amountOut = (reserveOut * amountInWithFee) / (reserveIn + amountInWithFee);

    //     //检查滑点
    //     setSli(amountInWithFee,reserveIn,reserveOut,_disirSli);


    //     tokenOut.transfer(msg.sender, amountOut);
    //     uint totalReserve0 = reserve[lptokenAddr][_tokenIn] + _amountIn; 
    //     uint totalReserve1 = reserve[lptokenAddr][_tokenOut] - amountOut;

    //     _update(lptokenAddr,_tokenIn, _tokenOut, totalReserve0, totalReserve1);

    // }

    //暴露数据查询方法

    // function getReserve(address _lpTokenAddr, address _tokenAddr) public view returns(uint)
    // {
    //     return reserve[_lpTokenAddr][_tokenAddr];
    // }

    // function getLptoken(address _tokenA, address _tokenB) public view returns(address)
    // {
    //     return findLpToken[_tokenA][_tokenB];
    // }

    // function lptokenTotalSupply(address _token0, address _token1, address user) public view returns(uint)
    // {
    //     Lp lptoken;
    //     lptoken = Lp(findLpToken[_token0][_token1]);
    //     uint totalSupply = lptoken.balanceOf(user);
    //     return totalSupply;
    // }

    function getLptokenLength() public view returns(uint)
    {
        return lpTokenAddressList.length;
    }

//依赖方法
    //creatpair

    function createPair(address addrToken) internal returns(address){
        bytes32 _salt = keccak256(
            abi.encodePacked(
                addrToken
            )
        );
        new Lp{
            salt : bytes32(_salt)
        }
        ();
        address lptokenAddr = getAddress(getBytecode(),_salt);

         //检索lptoken
        lpTokenAddressList.push(lptokenAddr);
        findLpToken[addrToken] = lptokenAddr;

        return lptokenAddr;
    }

    function createStakingToken(address addrToken) internal returns(address){
        bytes32 _salt = keccak256(
            abi.encodePacked(
                addrToken,"stakingToken"
            )
        );
        new Lp{
            salt : bytes32(_salt)
        }
        ();
        address lptokenAddr = getAddress(getBytecode(),_salt);

         //检索lptoken
        lpTokenAddressList.push(lptokenAddr);
        findLpToken[addrToken] = lptokenAddr;

        return lptokenAddr;
    }

    function createToken(address _user,string memory _name,string memory _simple, uint _totalSupply) internal {
        bytes32 _salt = keccak256(
            abi.encodePacked(
                _name,_simple,_totalSupply,_user,block.timestamp
            )
        );
        standToken tokenAddr = new standToken{
            salt : bytes32(_salt)
        }
        (_name,_simple,_totalSupply);
        //address tokenAddr = getAddress(getBytecode2(),_salt);
        

        userCreatedToken[_user] = address(tokenAddr);

    }

    function getBytecode() internal pure returns(bytes memory) {
        bytes memory bytecode = type(Lp).creationCode;
        return bytecode;
    }

    function getBytecode2() internal pure returns(bytes memory) {
        bytes memory bytecode = type(standToken).creationCode;
        return bytecode;
    }

    function getAddress(bytes memory bytecode, bytes32 _salt)
        internal
        view
        returns(address)
    {
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff), address(this), _salt, keccak256(bytecode)
            )
        );

        return address(uint160(uint(hash)));
    }

    //数据更新



//数学库

    function _sqrt(uint y) private pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function _min(uint x, uint y) private pure returns (uint) {
        return x <= y ? x : y;
    }

    function setSli(uint dx, uint x, uint y, uint _disirSli) private pure returns(uint){


        uint amountOut = (y * dx) / (x + dx);

        uint dy = dx * y/x;
        /*
        loseAmount = Idea - ammOut
        Sli = loseAmount/Idea
        Sli = [dx*y/x - y*dx/(dx + x)]/dx*y/x
        */
        uint loseAmount = dy - amountOut;

        uint Sli = loseAmount * 10000 /dy;
        
        require(Sli <= _disirSli, "Sli too large");
        return Sli;

    }



}
