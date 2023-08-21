import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { getAllRoles } from './common.helpers';

import {
  AggregatorV3Interface,
  DataFeed,
  DepositVault,
  MidasAccessControl,
  RedemptionVault,
  StUSD,
} from '../../typechain-types';

type Params = {
  accessControl: MidasAccessControl;
  stUsd: StUSD;
  dataFeed: DataFeed;
  dataFeedEur: DataFeed;
  aggregator: AggregatorV3Interface;
  depositVault: DepositVault;
  aggregatorEur: AggregatorV3Interface;
  redemptionVault: RedemptionVault;
  owner: SignerWithAddress;
  execute?: (role: string, address: string) => Promise<any>;
};

export const initGrantRoles = async ({
  accessControl,
  depositVault,
  redemptionVault,
  stUsd,
  owner,
  execute,
}: Omit<
  Params,
  'aggregator' | 'dataFeed' | 'dataFeedEur' | 'aggregatorEur'
>) => {
  const roles = await getAllRoles(accessControl);

  const checkAndExecute = async (role: string, address: string) => {
    if (!(await accessControl.hasRole(role, address))) {
      if (execute) await execute(role, address);
      else {
        // console.log(`Granting role: ${role} to address: ${address}`);
        await accessControl
          .connect(owner)
          .grantRole(role, address)
          .then((tx) => tx.wait());
        console.log('Role granted.');
      }
    }
  };

  await checkAndExecute(roles.blacklistedOperator, stUsd.address);

  await checkAndExecute(roles.greenlistedOperator, depositVault.address);

  await checkAndExecute(roles.greenlistedOperator, redemptionVault.address);

  await checkAndExecute(roles.minter, depositVault.address);

  await checkAndExecute(roles.minter, redemptionVault.address);

  await checkAndExecute(roles.burner, redemptionVault.address);
};

export const postDeploymentTest = async (
  { ethers }: HardhatRuntimeEnvironment,
  {
    accessControl,
    aggregator,
    dataFeed,
    depositVault,
    redemptionVault,
    stUsd,
    dataFeedEur,
    aggregatorEur,
    owner,
  }: Params,
) => {
  const roles = await getAllRoles(accessControl);

  /** stUSD tests start */
  expect(await stUsd.name()).eq('stUSD');
  expect(await stUsd.symbol()).eq('stUSD');
  expect(await stUsd.paused()).eq(false);

  /** stUSD tests end */

  /** DataFeed tests start */

  expect(await dataFeed.aggregator()).eq(aggregator.address);

  expect(await dataFeedEur.aggregator()).eq(aggregatorEur.address);

  /** DataFeed tests end */

  /** DepositVault tests start */

  expect(await depositVault.stUSD()).eq(stUsd.address);

  expect(await depositVault.etfDataFeed()).eq(dataFeed.address);

  expect(await depositVault.eurUsdDataFeed()).eq(dataFeedEur.address);

  expect(await depositVault.PERCENTAGE_BPS()).eq('100');

  expect(await depositVault.minAmountToDepositInEuro()).eq('0');

  expect(await depositVault.vaultRole()).eq(
    await accessControl.DEPOSIT_VAULT_ADMIN_ROLE(),
  );

  expect(await depositVault.MANUAL_FULLFILMENT_TOKEN()).eq(
    ethers.constants.AddressZero,
  );

  /** DepositVault tests end */

  /** RedemptionVault tests start */

  expect(await redemptionVault.stUSD()).eq(stUsd.address);

  expect(await redemptionVault.etfDataFeed()).eq(dataFeed.address);

  expect(await redemptionVault.minUsdAmountToRedeem()).eq('0');

  expect(await redemptionVault.PERCENTAGE_BPS()).eq('100');

  expect(await redemptionVault.lastRequestId()).eq('0');

  expect(await redemptionVault.vaultRole()).eq(
    await accessControl.REDEMPTION_VAULT_ADMIN_ROLE(),
  );

  expect(await redemptionVault.MANUAL_FULLFILMENT_TOKEN()).eq(
    ethers.constants.AddressZero,
  );

  /** RedemptionVault tests end */

  /** Owners roles tests start */

  const { blacklisted: _, greenlisted: __, ...rolesToCheck } = roles;

  for (const role of Object.values(rolesToCheck)) {
    expect(await accessControl.hasRole(role, owner.address)).to.eq(true);
  }

  expect(await accessControl.getRoleAdmin(roles.blacklisted)).eq(
    roles.blacklistedOperator,
  );

  /** Owners roles tests end */

  /** Contracts roles tests start */

  expect(
    await accessControl.hasRole(roles.blacklistedOperator, stUsd.address),
  ).eq(true);
  expect(
    await accessControl.hasRole(
      roles.greenlistedOperator,
      depositVault.address,
    ),
  ).eq(true);
  expect(
    await accessControl.hasRole(
      roles.greenlistedOperator,
      redemptionVault.address,
    ),
  ).eq(true);

  expect(await accessControl.hasRole(roles.minter, depositVault.address)).eq(
    true,
  );

  expect(await accessControl.hasRole(roles.minter, redemptionVault.address)).eq(
    true,
  );
  expect(await accessControl.hasRole(roles.burner, redemptionVault.address)).eq(
    true,
  );

  /** Contracts roles tests end */
};
