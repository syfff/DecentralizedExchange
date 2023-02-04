// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;


import './token.sol';
import "hardhat/console.sol";

//TODO: should change msg.sender to tx.origin


contract TokenExchange is Ownable {
    string public exchange_name = 'MMSWAP';

    address tokenAddr=address(0x5FbDB2315678afecb367f032d93F642f64180aa3);//
    // TODO: paste token contract address here
    Token public token = Token(tokenAddr);                              

    // Liquidity pool for the exchange
    uint private token_reserves = 0;
    uint private eth_reserves = 0;

    uint private token_rewards = 0;
    uint private eth_rewards = 0;

    mapping(address => uint) private lps;
     
    // Needed for looping through the keys of the lps mapping
    address[] private lp_providers;                

    // liquidity rewards
    uint private swap_fee_numerator = 3;                // TODO Part 5: Set liquidity providers' returns.
    uint private swap_fee_denominator = 100;

    // Constant: x * y = k
    uint private k;

    constructor() {}
    

    // Function createPool: Initializes a liquidity pool between your Token and ETH.
    // ETH will be sent to pool in this transaction as msg.value
    // amountTokens specifies the amount of tokens to transfer from the liquidity provider.
    // Sets up the initial exchange rate for the pool by setting amount of token and amount of ETH.
    function createPool(uint amountTokens)
        external
        payable
        onlyOwner
    {
        // This function is already implemented for you; no changes needed.

        // require pool does not yet exist:
        require (token_reserves == 0, "Token reserves was not 0");
        require (eth_reserves == 0, "ETH reserves was not 0.");

        // require nonzero values were sent
        require (msg.value > 0, "Need eth to create pool.");
        uint tokenSupply = token.balanceOf(msg.sender);
        require(amountTokens <= tokenSupply, "Not have enough tokens to create the pool");
        require (amountTokens > 0, "Need tokens to create pool.");

        token.transferFrom(msg.sender, address(this), amountTokens);
        token_reserves = token.balanceOf(address(this));
        eth_reserves = msg.value;
        k = token_reserves * eth_reserves;
    }

    // Function removeLP: removes a liquidity provider from the list.
    // This function also removes the gap left over from simply running "delete".
    function removeLP(uint index) private {
        require(index < lp_providers.length, "specified index is larger than the number of lps");
        lp_providers[index] = lp_providers[lp_providers.length - 1];
        lp_providers.pop();
    }

    // Function getSwapFee: Returns the current swap fee ratio to the client.
    function getSwapFee() public view returns (uint, uint) {
        return (swap_fee_numerator, swap_fee_denominator);
    }

    // ============================================================
    //                    FUNCTIONS TO IMPLEMENT
    // ============================================================
    
    /* ========================= Liquidity Provider Functions =========================  */ 

    // Function addLiquidity: Adds liquidity given a supply of ETH (sent to the contract as msg.value).
    // You can change the inputs, or the scope of your function, as needed.
    function addLiquidity(uint max_exchange_rate, uint min_exchange_rate) 
        external 
        payable
    {
        /******* TODO: Implement this function *******/
        require(msg.value > 0, "Liquidity provide amount for ETH must be greater than 0.");
        //      While providing liquidity, the transaction should fail if the current price of the new asset
        //      has increased to more than the maximum exchange rate or fallen below the minimum exchange rate.
        require(eth_reserves * 100 <= max_exchange_rate * token_reserves, "go above max_change_rate.");
        require(eth_reserves * 100 >= min_exchange_rate * token_reserves, "fall below min_change_rate.");

        eth_reserves+=eth_rewards;
        token_reserves+=token_rewards;
        eth_rewards=0;
        token_rewards=0;
        
        uint256 amount = msg.value * token_reserves / eth_reserves;
        require(token.balanceOf(msg.sender) >= amount, "You don't have enough token.");
        require(token.transferFrom(msg.sender, address(this), amount), "transaction failed.");


        // //TODO: this can be change to store the fraction
        // if(lp_providers_denominator==0){
        //     lp_providers_numerator[msg.sender]+= msg.value;
        //     lp_providers_denominator+=msg.value;
        // }
        // else{
        //     lp_providers_numerator[msg.sender] += msg.value  * lp_providers_denominator / (eth_reserves+msg.value);
        //     lp_providers_denominator += msg.value  * lp_providers_denominator / (eth_reserves+msg.value);
        // }

        uint256 liquidity = msg.value * 1000 / (msg.value + eth_reserves);
        uint256 liquidityOthers = eth_reserves / (msg.value + eth_reserves);

        //update eth_reserves and token_reserves
        eth_reserves = eth_reserves + msg.value;
        token_reserves = token_reserves + amount;
        k = eth_reserves * token_reserves;

        for (uint i = 0; i < lp_providers.length; ++i) {
            if (lp_providers[i] != msg.sender) {
                lps[lp_providers[i]] = lps[lp_providers[i]] * liquidityOthers;
            }
        }
        lps[msg.sender] = lps[msg.sender] * liquidityOthers + liquidity;

    }


    // Function removeLiquidity: Removes liquidity given the desired amount of ETH to remove.
    // You can change the inputs, or the scope of your function, as needed.
    function removeLiquidity(uint amountETH, uint max_exchange_rate, uint min_exchange_rate)
        public 
        payable
    {
        /******* Implement this function *******/
        require(amountETH < eth_reserves, "can't remove more than the ETH pool");
        require(amountETH <= lps[msg.sender] * eth_reserves / 1000, "can't remove more than you provide");

        uint256 amount = amountETH * token_reserves / eth_reserves;
        require(amount < token_reserves, "can't remove more than the token pool has");

        require(eth_reserves * 100 <= max_exchange_rate * token_reserves, "go above max_change_rate.");
        require(eth_reserves * 100 >= min_exchange_rate * token_reserves, "fall below min_change_rate.");

        require(token.transfer(msg.sender, amount), "something is wrong");
        payable(msg.sender).transfer(amountETH);

        eth_reserves+=eth_rewards;
        token_reserves+=token_rewards;
        eth_rewards=0;
        token_rewards=0;

        // //TODO: this can be changed to fraction
        // lp_providers_numerator[msg.sender]=lp_providers_numerator[msg.sender] - (amountETH*lp_providers_denominator+eth_reserves*99/100) / (eth_reserves);
        // lp_providers_denominator-=amountETH*lp_providers_denominator / (eth_reserves);

        uint256 liquidity = lps[msg.sender] - 1000 * amountETH / (eth_reserves);
        uint256 liquidityOthers = eth_reserves / (eth_reserves - amountETH);

        eth_reserves = eth_reserves - amountETH;
        token_reserves = token_reserves - amount;
        k = eth_reserves * token_reserves;

        uint j=0;
        for (uint i = 0; i < lp_providers.length; ++i) {
            if (lp_providers[i] != msg.sender) {
                lps[lp_providers[i]] = lps[lp_providers[i]] * liquidityOthers;
            }
            else{
                j=i;
            }
        }
        lps[msg.sender] = liquidity;
        if(liquidity<=0){
            removeLP(j);
        }

    }

    // Function removeAllLiquidity: Removes all liquidity that msg.sender is entitled to withdraw
    // You can change the inputs, or the scope of your function, as needed.
    function removeAllLiquidity(uint max_exchange_rate, uint min_exchange_rate)
        external
        payable
    {
        /******* TODO: Implement this function *******/
        uint256 amount = lps[msg.sender] * eth_reserves / 1000;
        removeLiquidity(amount, max_exchange_rate, min_exchange_rate);
    }
    /***  Define additional functions for liquidity fees here as needed ***/


    /* ========================= Swap Functions =========================  */ 

    // Function swapTokensForETH: Swaps your token with ETH
    // You can change the inputs, or the scope of your function, as needed.
    function swapTokensForETH(uint amountTokens, uint max_exchange_rate)
        external 
        payable
    {
        /******* TODO: Implement this function *******/
        require(token.balanceOf(msg.sender) >= amountTokens, "not enough token");
        uint256 amountExchanged = amountTokens  - amountTokens * swap_fee_numerator / swap_fee_denominator;
        uint256 amountReward = amountTokens * swap_fee_numerator / swap_fee_denominator;
        //uint256 amountRewardedEth = eth_reserves * amountReward / token_reserves;
        uint256 amountEth = eth_reserves * amountExchanged / (token_reserves + amountExchanged);
        //      transfer token from the user, extract eth from the pool
        require(amountEth < eth_reserves, "eth reserved exceeded");
        //uint256 exchange_price = token_reserves * 100 / eth_reserves;
        require(token_reserves * 100 <= max_exchange_rate * eth_reserves, "go above max_change_rate.");
        require(token.transferFrom(msg.sender, address(this), amountTokens), "transfer failed");
        payable(msg.sender).transfer(amountEth);

        //      update the reserves
        token_reserves = token_reserves + amountTokens - amountReward;
        token_rewards += amountReward;
        eth_reserves = eth_reserves - amountEth;
    }

    // Function swapETHForTokens: Swaps ETH for your tokens
    // ETH is sent to contract as msg.value
    // You can change the inputs, or the scope of your function, as needed.
    function swapETHForTokens(uint max_exchange_rate)
        external
        payable 
    {
        /******* Implement this function *******/
        require(msg.value > 0);
        //require(eth_reserves / token_reserves <= max_exchange_rate, "max exchange rate exceeded");
        uint256 amountExchanged = msg.value - msg.value * swap_fee_numerator / swap_fee_denominator;
        uint256 amountToken = token_reserves * amountExchanged / (eth_reserves + amountExchanged);
        uint256 amountReward = msg.value * swap_fee_numerator / swap_fee_denominator;
        require(amountToken < token_reserves, "not enough token");
        //uint256 exchange_price = eth_reserves * 100 / token_reserves;
        require(100 * eth_reserves <= token_reserves * max_exchange_rate, "go above max_change_rate.");
        //      transfer token to the msg.sender
        require(token.transfer(msg.sender, amountToken), "transfer failed");

        //      update the reserves
        eth_reserves = eth_reserves + msg.value - amountReward;
        eth_rewards += amountReward;
        token_reserves = token_reserves - amountToken;

    }

    // function get_lpa__(address adr) payable external returns(address)
    //       {
    //     //uint amount=lp_providers_numerator[adr];
    //     return adr;
    // }
}
