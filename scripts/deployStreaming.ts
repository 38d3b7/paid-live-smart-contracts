import { toNano } from '@ton/core';
import { Streaming } from '../wrappers/Streaming';
import { compile, NetworkProvider } from '@ton/blueprint';

export async function run(provider: NetworkProvider) {
    const streaming = provider.open(Streaming.createFromConfig({}, await compile('Streaming')));

    await streaming.sendDeploy(provider.sender(), toNano('0.05'));

    await provider.waitForDeploy(streaming.address);

    // run methods on `streaming`
}
