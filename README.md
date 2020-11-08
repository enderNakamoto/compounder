# STBZ/ETH pool compounder 

There's juicy STBZ to be had in [Stabilize Finance](https://www.stabilize.finance) if we compounded frequently. For Example: 

if the APR is 250% , With compounding we get the following APY: 

Compounding Frequency| APY 
--- | --- 
Semi-Annually | 406.25%
Monthly | 868.82% 
Daily | 1107.91%

 [Source](https://www.aprtoapy.com/)

Compounding everyday manually will take a lot of effort and cost a lot of gas, Therefore, we crowdsource this in this contract 

This project is based off [sushi-farm](https://github.com/abstracted-finance/sushi-farm)
which in turn was based off yVaults. YAY! OpenSource

## Functions

#### Harvest

It is callable every day. This Harvests the STBZ profits STBZ-ETH pool and re-invests it. 
Function caller gets 0.05% of the profits to compensate for gas. 
Dev also gets 0.01% when the harvest() is called. 

```javascript
harvest()
```

#### Deposit

Converts normal `STBZ` into `cmpSTZ`. (compounded STBZ).

```javascript
deposit(uint256 _amount)
```

```javascript
depositAll()
```

#### Withdraw

Converts your `cmpSTZ` (compounded STBZ) for normal `STBZ`.

```javascript
withdraw(uint256 _shares)
```

```javascript
withdrawAll()
```