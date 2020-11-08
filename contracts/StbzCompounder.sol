// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./interfaces/operator.sol";
import "./interfaces/uniswap.sol";

import "./constants.sol";

// Based off https://github.com/abstracted-finance/sushi-farm
contract StbzCompounder is ERC20 {

    address owner;

    // Tokens
    IERC20 public stbz = IERC20(Constants.STBZ);
    IERC20 public univ2stbzEth = IERC20(Constants.UNIV2_STBZ_ETH);
    IERC20 public weth = IERC20(Constants.WETH);

    // Stabilizer 
    Operator public operator = Operator(Constants.OPERATOR);
    uint256 public stbzPoolId = 0;

    // Uniswap 
    UniswapRouterV2 public univ2 = UniswapRouterV2(Constants.UNIV2_ROUTER2);
    UniswapPair public univ2Pair = UniswapPair(address(univ2stbzEth));

    // Last time harvest() was called
    uint256 public lastHarvest = 0;

    // 0.05% reward for anyone who calls HARVEST
    uint256 public callerPercent = 5 ether / 100;

    // 0.01% reward to the owner 
    uint256 public devPercent = 1 ether / 100;

    // create the STBZ tokens
    constructor() ERC20("Compounded STBZ", "cmpSTBZ") {
      owner = msg.sender;
    }

    function deposit(uint256 _amount) public {
        // transfer stbz from user EOA to contract address
        stbz.transferFrom(msg.sender, address(this), _amount);

        // find the pool balance of this contract
        uint256 _poolBalance = stbzEthPoolBalance();

        // change STBZ to STBZ/ETH Pair and storing the amount 
        uint256 _before = univ2stbzEth.balanceOf(address(this));
        _stbzToUniV2STBZEth(_amount);
        uint256 _after = univ2stbzEth.balanceOf(address(this));
        // Additional check for deflationary tokens
        _amount = _after - _before; 

        // since we inherited from ERC20, totalSupply() is totalysupply of cmpSTBZ tokens
        uint256 shares = 0;
        if (totalSupply() == 0) {
          shares = _amount;
        } else {
          shares = _amount * (totalSupply()/_poolBalance)
        }

        // Deposit into STBZ operator contract to get rewards
        univ2stbzEth.approve(address(operator), _amount);
        operator.deposit(stbzPoolId, _amount);

        // since we inherited from ERC20, this is minting cmpSTBZ tokens
        _mint(msg.sender, shares);
    }

    // depoit all the stbz in the wallet of msg.sender
    function depositAll() external {
        deposit(stbz.balanceOf(msg.sender));
    }

    function withdraw(uint256 _shares) public {
        // find the pool balance of this contract
        uint256 _poolBalance = stbzEthPoolBalance();

        // how much LP amount owned based on _shares
        uint256 _amount = _shares * (_poolBalance/totalSupply())
        // burn cmpSTBZ tokens
        _burn(msg.sender, _shares);

        // withdraw from STBZ Operator contract
        operator.withdraw(stbzPoolId, _amount);

        // Retrive shares from Uniswap pool and converts to STBZ
        uint256 _before = stbz.balanceOf(address(this));
        _uniV2STBZEthToSTBZ(_amount);
        uint256 _after = stbz.balanceOf(address(this));
        _amount = _after - _before

        // Transfer back STBZ to the caller
        stbz.transfer(msg.sender, _amount);
    }

    function withdrawAll() external {
      // balance of cmpSTBZ
      withdraw(balanceOf(msg.sender));
    }

    function harvest() public {
        // Only callable once a day 
        if (lastHarvest > 0) {
            require(lastHarvest + 1 days <= block.timestamp, "it was called within a day");
        }
        lastHarvest = block.timestamp;

        uint256 _poolBalance = stbzEthPoolBalance();
        
        // claim stbz
        operator.getReward(stbzPoolId);
        uint256 amount = stbz.balanceOf(address(this));

        // calculate the reward for harvestor
        uint256 harvestorReward = (amount * callerPercent)/100 ethers;
        uint256 devReward = (amount * devPercent)/100 ethers;

        // Sends 5% fee to caller
        stbz.transfer(msg.sender, harvestorReward);

        // sends 1% to dev 
        stbz.transfer(owner, devreward);

        // subtract rewards from harvested stbz
        amount = amount - harvestorReward - devReward

        // Add to UniV2 pool
        _stbzToUniV2STBZEth(amount);

        // Deposit into stbz operator contract
        uint256 balance = univ2stbzEth.balanceOf(address(this));
        univ2stbzEth.approve(address(operator), balance);
        operator.deposit(stbzPoolId, balance);
    }

    // balance of LP for the compounder contract address in the stake pool of Stbz
    function stbzEthPoolBalance() public view returns (uint256) {
        uint256 _balance = operator.poolBalance(stbzPoolId, address(this));
        return _balance;
    }

    // Takes <x> amount of STBZ
    // Converts half of it into ETH,
    // Supplies them into STBZ/ETH pool
    function _stbzToUniV2STBZEth(uint256 _amount) internal {
      uint256 half = _amount/2;

      // Convert half of the stbz to ETH
      address[] memory path = new address[](2);
      path[0] = address(stbz);
      path[1] = address(weth);
      stbz.approve(address(univ2), half);
      univ2.swapExactTokensForTokens(half, 0, path, address(this), now + 60);

      // Supply liquidity
      uint256 wethBal = weth.balanceOf(address(this));
      uint256 stbzBal = stbz.balanceOf(address(this));
      stbz.approve(address(univ2), stbzBal);
      weth.approve(address(univ2), wethBal);
      univ2.addLiquidity(
          address(stbz),
          address(weth),
          stbzBal,
          wethBal,
          0,
          0,
          address(this),
          now + 60
      );
    }

    // Takes <x> amount of cmpSTBZ
    // And removes liquidity from STBZ/ETH pool
    // Converts the ETH into STBZ
    function _uniV2STBZEthToSTBZ(uint256 _amount) internal {
        require(
            univ2stbzEth.balanceOf(address(this)) >= _amount,
            "not-enough-liquidity"
        );
        univ2stbzEth.approve(address(univ2), _amount);
        univ2.removeLiquidity(
            address(stbz),
            address(weth),
            _amount,
            0,
            0,
            address(this),
            now + 60
        );

        // Convert ETH to STBZ
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(stbz);
        uint256 wethBal = weth.balanceOf(address(this));
        weth.approve(address(univ2), wethBal);
        univ2.swapExactTokensForTokens(
            wethBal,
            0,
            path,
            address(this),
            now + 60
        );
    }
}
