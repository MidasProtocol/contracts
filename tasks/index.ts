import chalk from "chalk";
import { task, types } from "hardhat/config";
import { ST_USD_DEPLOY_TAG } from "../deploy/deploy_stUSD";
import { PopulatedTransaction } from "ethers";

import './prepareTx'


export const logPopulatedTx = (tx: PopulatedTransaction) => {
    console.log(
        {
            data: tx.data,
            to: tx.to
        }
    )
}

task('executeTx')
    .addPositionalParam('to', undefined, undefined, types.string)
    .addPositionalParam('data', undefined, undefined, types.string)
    .addOptionalParam('from', undefined, undefined, types.string)
    .addOptionalParam('value', undefined, undefined, types.float)
    .setAction(async ({
        to, data, from, value
    }, hre) => {
        const { deployer } = await hre.getNamedAccounts();
        const signer = await hre.ethers.getSigner(from ?? deployer);

        const valueParsed = value ? hre.ethers.utils.parseUnits(value.toString()) : undefined;

        const tx = await signer.sendTransaction({
            data: data,
            to,
            from,
            value: valueParsed
        })

        console.log(
            chalk.yellow('Transaction hash: ', tx.hash)
        )
    })