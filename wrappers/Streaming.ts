import { Address, beginCell, Cell, Contract, contractAddress, ContractProvider, Sender, SendMode } from '@ton/core';

export type StreamingConfig = {};

export function streamingConfigToCell(config: StreamingConfig): Cell {
    return beginCell().endCell();
}

export class Streaming implements Contract {
    constructor(readonly address: Address, readonly init?: { code: Cell; data: Cell }) {}

    static createFromAddress(address: Address) {
        return new Streaming(address);
    }

    static createFromConfig(config: StreamingConfig, code: Cell, workchain = 0) {
        const data = streamingConfigToCell(config);
        const init = { code, data };
        return new Streaming(contractAddress(workchain, init), init);
    }

    async sendDeploy(provider: ContractProvider, via: Sender, value: bigint) {
        await provider.internal(via, {
            value,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell().endCell(),
        });
    }
}
