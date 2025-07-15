import { Blockchain, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { Cell, toNano } from '@ton/core';
import { Streaming } from '../wrappers/Streaming';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';

describe('Streaming', () => {
    let code: Cell;

    beforeAll(async () => {
        code = await compile('Streaming');
    });

    let blockchain: Blockchain;
    let deployer: SandboxContract<TreasuryContract>;
    let streaming: SandboxContract<Streaming>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();

        streaming = blockchain.openContract(Streaming.createFromConfig({}, code));

        deployer = await blockchain.treasury('deployer');

        const deployResult = await streaming.sendDeploy(deployer.getSender(), toNano('0.05'));

        expect(deployResult.transactions).toHaveTransaction({
            from: deployer.address,
            to: streaming.address,
            deploy: true,
            success: true,
        });
    });

    it('should deploy', async () => {
        // the check is done inside beforeEach
        // blockchain and streaming are ready to use
    });
});
