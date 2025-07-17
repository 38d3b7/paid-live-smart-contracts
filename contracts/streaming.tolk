const min_tons_for_storage = 10000000; // ONE_TON / 100

@inline
fun saveData(
    ownerAddress: address,
    commissionAddress: address,
    balance: int,
    finalPay: int,
    targetAddress: address,
    streamingRate: int,
    lastUpdated: int,
    payFlag: int
) {
    contract.setData(
        beginCell()
            .storeAddress(ownerAddress)
            .storeAddress(commissionAddress)
            .storeCoins(balance)
            .storeCoins(finalPay)
            .storeAddress(targetAddress)
            .storeCoins(streamingRate)
            .storeUint(lastUpdated, 64)
            .storeUint(payFlag, 4)
        .endCell()
    );
}

@inline
fun loadData(): (address, address, int, int, address, int, int, int) {
    var ds: slice = contract.getData().beginParse();
    return (
        ds.loadAddress(),     // ownerAddress
        ds.loadAddress(),     // commissionAddress
        ds.loadCoins(),       // balance
        ds.loadCoins(),       // finalPay
        ds.loadAddress(),     // targetAddress
        ds.loadCoins(),       // streamingRate
        ds.loadUint(64),      // lastUpdated
        ds.loadUint(4)        // payFlag
    );
}

@inline
fun sendTon(toAddress: address, commissionAddress: address, amount: int, sendMode: int) {
    var commissionAmount: int = amount * 4 / 100;
    var exactAmount: int = amount - commissionAmount;

    var msg = beginCell()
        .storeUint(0x10, 6)
        .storeAddress(toAddress)
        .storeCoins(exactAmount)
        .storeUint(0, 1 + 4 + 4 + 64 + 32 + 1 + 1)
        .storeUint(0, 32)
    .endCell();
    sendRawMessage(msg, sendMode);

    var msg1 = beginCell()
        .storeUint(0x10, 6)
        .storeAddress(commissionAddress)
        .storeCoins(commissionAmount)
        .storeUint(0, 1 + 4 + 4 + 64 + 32 + 1 + 1)
        .storeUint(0, 32)
    .endCell();
    sendRawMessage(msg1, sendMode);
}

fun onInternalMessage(msgValue: int, inMsgFull: cell, inMsgBody: slice) {
    if (inMsgBody.isEmpty()) {
        return;
    }

    var cs: slice = inMsgFull.beginParse();
    var flags: int = cs.loadUint(4);
    if (flags & 1) { // ignore bounced
        return;
    }

    var senderAddress: address = cs.loadAddress();
    var (ownerAddress, commissionAddress, balance, finalPay, targetAddress, streamingRate, lastUpdated, payFlag) = loadData();

    var op: int = inMsgBody.loadUint(32);

    if (op == 1) { // Set target address
        assert(senderAddress.bitsEqual(ownerAddress)) throw 401;
        assert(finalPay < balance) throw 403;
        if (finalPay > 0) {
            sendTon(targetAddress, commissionAddress, finalPay, 1);
            balance -= finalPay;
            finalPay = 0;
        }
        targetAddress = inMsgBody.loadAddress();
    }

    if (op == 2) { // Set streaming rate
        assert(senderAddress.bitsEqual(ownerAddress)) throw 401;
        assert(finalPay < balance) throw 403;
        if (finalPay > 0) {
            sendTon(targetAddress, commissionAddress, finalPay, 1);
            balance -= finalPay;
            finalPay = 0;
        }
        streamingRate = inMsgBody.loadCoins();
    }

    if (op == 3) { // Start streaming
        assert(senderAddress.bitsEqual(ownerAddress)) throw 401;
        assert(payFlag == 0) throw 402;
        if (finalPay > 0) {
            sendTon(targetAddress, commissionAddress, finalPay, 1);
            balance -= finalPay;
            finalPay = 0;
        }
        targetAddress = inMsgBody.loadAddress();
        streamingRate = inMsgBody.loadCoins();
        lastUpdated = blockchain.now();
        payFlag = 1;
    }

    if (op == 4) { // Stop streaming
        assert(senderAddress.bitsEqual(ownerAddress)) throw 401;
        assert(payFlag == 1) throw 402;
        var withdrawAmount: int = streamingRate * (blockchain.now() - lastUpdated) / 60;
        if (withdrawAmount > balance) {
            sendTon(targetAddress, commissionAddress, balance, 1);
            finalPay = withdrawAmount - balance;
            balance = 0;
        } else {
            sendTon(targetAddress, commissionAddress, withdrawAmount, 1);
            balance -= withdrawAmount;
            finalPay = 0;
        }
        payFlag = 0;
    }

    if (op == 6) { // Top up balance
        balance += msgValue;
    }

    if (op == 7) { // Send service fee message
        reserveToncoinsOnBalance(min_tons_for_storage, 0);
        var messageBody: cell = beginCell()
            .storeUint(0, 32)
            .storeSlice("contract service fee")
            .endCell();
        var msg = beginCell()
            .storeUint(0x10, 6)
            .storeAddress(senderAddress)
            .storeCoins(0)
            .storeRef(messageBody);
        return sendRawMessage(msg.endCell(), 64 | 2);
    }

    saveData(ownerAddress, commissionAddress, balance, finalPay, targetAddress, streamingRate, lastUpdated, payFlag);
    return;
}

get fun get_streaming_info(): int {
    var (_, _, balance, _, _, rate, last, flag) = loadData();
    return rate * (blockchain.now() - last) / 60;
}

get fun get_config(): (address, address, int, int, address, int, int, int) {
    return loadData();
}