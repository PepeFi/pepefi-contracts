# PepeFi

* <a href="https://pepefi.gitbook.io/docs/" target="_blank">Documentation</a>


PepeFi allows NFT holders to take unliquidatable loans on their NFT while exposing LPs to yields similar to OTM PUT selling. In 2022, the yield for such selling averaged an APR of 50%.


PepeFi allows anyone to take a loan on any whitelisted financial asset as long as its valuation is retrievable onchain. As a result, PepeFi is highly customizable and works on a wide range of assets, from ERC721 NFTs with Chainlink Oracles to ERC721 financial assets like Uniswap Liquidity Positions.
The loans are provided by a Vault whose creators determine APR, LTV, duration, trait multiplier, and other parameters. Inside the Vault, LPs share prorated returns for all loans in a decentralized manner thru an innovative mechanism called Rollover Vaults.


In the end, PepeFi makes the Market more efficient thru its innovative dynamics by providing the wider ecosystem access to the lucrative NFT lending market while providing loans that don't liquidate at a high LTV to the borrower.

## Project Repository

The contracts are coded in hardhat inside contracts/ directory. tests are in /tests and deployment scripts are in /scripts. Create .env from .env-example by adding the private key of deployment contract and Alchemy API.

After installing the develepment and normal dependencies, contracts can then be compiled:
>npx hardhat compile

Start a local hardhat instance with a mainnet fork using:
>npx hardhat node

Then you can run the tests with
>npm run test

Testing is comprehensive and creates vaults, performs rollover and creates and repays loans for a trait-boosted BAYC and a Uniswap financial position
