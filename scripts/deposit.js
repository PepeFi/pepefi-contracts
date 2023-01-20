import { ethers } from "ethers";

let vm_contract = new ethers.Contract( VAULT_MANAGER , VAULTMANAGER_ABI , signer)
await vm_contract.addLiquidity(amount, vault)
