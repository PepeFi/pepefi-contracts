library VaultLib{
    struct loanDetails {
        uint256 timestamp; //unix timestamp of when the loan was made

        address collateral; //collaret nft
        uint256 assetId; //asset ID

        uint256 expiry; //expiry date of loan
        uint256 loanPrincipalAmount; //principal taken
        uint256 repaymentAmount; //repayment amount
    }

    struct loanCreation {
        address nftCollateralContract; 
        uint256 nftCollateralId;
        uint256 loanPrincipal; 
        uint256 apr;
        uint256 loanExpiry;
    }

    struct Contracts {
        address ASSET;
        address BASE_VAULT;
        address AUCTION_CONTRACT;
        address PEPEFI_ADMIN; 
        address VAULT_MANAGER; 
        address ORACLE_CONTRACT; 
    }

    struct VaultDetails {
        string VAULT_NAME;
        string VAULT_DESCRIPTION;
        Contracts CONTRACTS;
        address VAULT_CREATOR;
        address PREVIOUS_VAULT;
        bool EXTERNAL_LP_ENABLED; 
        address[] WHITELISTED_NFT_LPS; //nft holder allowed to LP
        uint256 CREATION_TIME;
        uint256 EXPIRY_IN;
    }

    struct creationParams{
        string VAULT_NAME;
        string VAULT_DESCRIPTION; 
        uint256 EXPIRY_IN;
        bool EXTERNAL_LP_ENABLED; 
        address PREVIOUS_VAULT;
        address[] WHITELISTED_NFT_LPS; //nft holders allowed to LP
    }


    struct Withdrawl{
        address user;
        uint256 shares;
    }

    enum COLLECTION_TYPE{
        Oracle,
        SmartContract,
        Custom
    }

    struct SUPPORTED_COLLECTIONS{
        address COLLECTION;
        COLLECTION_TYPE TYPE;
        address VAULUATION_PERFORMER; //for uni nft etc this has to be a function that returns the valuation of the nft. For basic NFT, this is the chainlink oracle
        uint32 MAX_LTV;
        uint32 MAX_DURATION;
        uint32 APR;
        uint32 slope;
        uint256 MAX_LOAN;
        string[] ALLOWED_TRAITS;
        uint32[] TRAIT_MULTIPLIER;
    }

    struct LoanDetails {
        address nftCollateralContract;
        uint256 nftCollateralId; 
        uint256 loanAmount; 
        uint32 duration; 
        address vault;
    }


}