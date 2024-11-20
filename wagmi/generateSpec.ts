
import fs from "fs"
const contractsToGenerate: string[] =
    [
        "AVault",
        "StandardOracle",
        "USDe_USDx_ys",
        "USDC_v1",
        "SFlax",
        "IsFlax",
        "Flax"
    ];
interface JSONFormat {
    abi: any[]
}
(function main() {
    const abis = contractsToGenerate.map(
        c => {
            const jsonFile: JSONFormat = JSON.parse(fs.readFileSync(`./out/${c}.sol/${c}.json`, "utf-8"))
            return { abi: jsonFile.abi, name: c }
        }
    )

    const template: string = `
   import { ContractConfig } from '@wagmi/cli';
    import { Abi } from 'viem';
    const contractSpec:  ContractConfig<number, undefined>[] =
      ${JSON.stringify(abis, null, 4)}
    export default contractSpec
   `
    fs.writeFileSync("./wagmi/auto.ts", template)
})()
