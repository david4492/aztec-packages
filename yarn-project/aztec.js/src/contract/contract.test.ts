import { AztecAddress, EthAddress } from '@aztec/circuits.js';
import { ABIParameterVisibility, ContractAbi, FunctionType } from '@aztec/foundation/abi';
import { randomBytes } from '@aztec/foundation/crypto';
import { DeployedContract, NodeInfo, Tx, TxHash, TxReceipt } from '@aztec/types';
import { TxExecutionRequest } from '@aztec/types';

import { MockProxy, mock } from 'jest-mock-extended';

import { Wallet } from '../aztec_rpc_client/wallet.js';
import { Contract } from './contract.js';

describe('Contract Class', () => {
  let wallet: MockProxy<Wallet>;

  const contractAddress = AztecAddress.random();
  const account = AztecAddress.random();

  const mockTx = { type: 'Tx' } as any as Tx;
  const mockTxRequest = { type: 'TxRequest' } as any as TxExecutionRequest;
  const mockTxHash = { type: 'TxHash' } as any as TxHash;
  const mockTxReceipt = { type: 'TxReceipt' } as any as TxReceipt;
  const mockViewResultValue = 1;
  const mockNodeInfo: NodeInfo = { version: 1, chainId: 2 };

  const defaultAbi: ContractAbi = {
    name: 'FooContract',
    functions: [
      {
        name: 'bar',
        functionType: FunctionType.SECRET,
        parameters: [
          {
            name: 'value',
            type: {
              kind: 'field',
            },
            visibility: ABIParameterVisibility.PUBLIC,
          },
          {
            name: 'value',
            type: {
              kind: 'field',
            },
            visibility: ABIParameterVisibility.SECRET,
          },
        ],
        returnTypes: [],
        bytecode: '0af',
      },
      {
        name: 'baz',
        functionType: FunctionType.OPEN,
        parameters: [],
        returnTypes: [],
        bytecode: '0be',
      },
      {
        name: 'qux',
        functionType: FunctionType.UNCONSTRAINED,
        parameters: [
          {
            name: 'value',
            type: {
              kind: 'field',
            },
            visibility: ABIParameterVisibility.PUBLIC,
          },
        ],
        returnTypes: [
          {
            kind: 'integer',
            sign: '',
            width: 32,
          },
        ],
        bytecode: '0cd',
      },
    ],
  };

  const randomContractAbi = (): ContractAbi => ({
    name: randomBytes(4).toString('hex'),
    functions: [],
  });

  const randomDeployContract = (): DeployedContract => ({
    abi: randomContractAbi(),
    address: AztecAddress.random(),
    portalContract: EthAddress.random(),
  });

  beforeEach(() => {
    wallet = mock<Wallet>();
    wallet.createAuthenticatedTxRequest.mockResolvedValue(mockTxRequest);
    wallet.sendTx.mockResolvedValue(mockTxHash);
    wallet.viewTx.mockResolvedValue(mockViewResultValue);
    wallet.getTxReceipt.mockResolvedValue(mockTxReceipt);
    wallet.getNodeInfo.mockResolvedValue(mockNodeInfo);
    wallet.simulateTx.mockResolvedValue(mockTx);
  });

  it('should create and send a contract method tx', async () => {
    const fooContract = new Contract(contractAddress, defaultAbi, wallet);
    const param0 = 12;
    const param1 = 345n;
    const sentTx = fooContract.methods.bar(param0, param1).send({
      origin: account,
    });
    const txHash = await sentTx.getTxHash();
    const receipt = await sentTx.getReceipt();

    expect(txHash).toBe(mockTxHash);
    expect(receipt).toBe(mockTxReceipt);
    expect(wallet.createAuthenticatedTxRequest).toHaveBeenCalledTimes(1);
    expect(wallet.sendTx).toHaveBeenCalledTimes(1);
    expect(wallet.sendTx).toHaveBeenCalledWith(mockTx);
  });

  it('should call view on an unconstrained function', async () => {
    const fooContract = new Contract(contractAddress, defaultAbi, wallet);
    const result = await fooContract.methods.qux(123n).view({
      from: account,
    });
    expect(wallet.viewTx).toHaveBeenCalledTimes(1);
    expect(wallet.viewTx).toHaveBeenCalledWith('qux', [123n], contractAddress, account);
    expect(result).toBe(mockViewResultValue);
  });

  it('should not call send on an unconstrained function', () => {
    const fooContract = new Contract(contractAddress, defaultAbi, wallet);
    expect(() =>
      fooContract.methods.qux().send({
        origin: account,
      }),
    ).toThrow();
  });

  it('should not call view on a secret or open function', () => {
    const fooContract = new Contract(contractAddress, defaultAbi, wallet);
    expect(() => fooContract.methods.bar().view()).toThrow();
    expect(() => fooContract.methods.baz().view()).toThrow();
  });

  it('should add contract and dependencies to aztec rpc', async () => {
    const entry = randomDeployContract();
    const contract = new Contract(entry.address, entry.abi, wallet);

    {
      await contract.attach(entry.portalContract);
      expect(wallet.addContracts).toHaveBeenCalledTimes(1);
      expect(wallet.addContracts).toHaveBeenCalledWith([entry]);
      wallet.addContracts.mockClear();
    }

    {
      const dependencies = [randomDeployContract(), randomDeployContract()];
      await contract.attach(entry.portalContract, dependencies);
      expect(wallet.addContracts).toHaveBeenCalledTimes(1);
      expect(wallet.addContracts).toHaveBeenCalledWith([entry, ...dependencies]);
    }
  });
});
