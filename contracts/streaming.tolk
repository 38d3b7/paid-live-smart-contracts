// Storage structure
// storage#_ owner:MsgAddress balance:Coins
//            target_address:MsgAddress streaming_rate:Coins
//            last_updated:uint64 is_streaming:bool = Storage;

@inline
fun saveData(ownerAddress: address, commissionAddress: address, balance: int, finalPay: int, targetAddress: address, streamingRate: int, lastUpdated: int, payFlag: int) {
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
fun loadData(): (address, address, coins, coins, address, coins, int, int) {
    var ds: slice = contract.getData().beginParse();
    return (
        ds.loadAddress(),     // owner_address
        ds.loadAddress(),     // commission_address
        ds.loadCoins(),       // balance
        ds.loadCoins(),       // final_pay
        ds.loadAddress(),     // target_address
        ds.loadCoins(),       // streaming_rate
        ds.loadUint(64),      // last_updated timestamp
        ds.loadUint(4)        // pay_flag
    );
}

@inline
fun sendTon(toAddress: address, commissionAddress: address, amount: int, sendMode: int) {

    var commissionAmount: int = amount * 4 / 100;
    var exactAmount: int = amount - commissionAmount;
    // send TON coins to the destination address
    var msg = beginCell()
        .storeUint(0x10, 6) // non-bounce
        .storeAddress(toAddress)
        .storeCoins(exactAmount)
        .storeUint(0, 1 + 4 + 4 + 64 + 32 + 1 + 1)
        .storeUint(0, 32)
    .endCell();
    sendRawMessage(msg, sendMode);

    var msg1 = beginCell()
        .storeUint(0x10, 6) // non-bounce
        .storeAddress(commissionAddress)
        .storeCoins(commissionAmount)
        .storeUint(0, 1 + 4 + 4 + 64 + 32 + 1 + 1)
        .storeUint(0, 32)
    .endCell();
    sendRawMessage(msg1, sendMode);
}

// in the future, use: fun onInternalMessage(in: InMessage) {
fun onInternalMessage(msgValue: int, inMsgFull: cell, inMsgBody: slice) {

    if (inMsgBody.isEmpty()) { 
        return;
    }

    var cs: slice = inMsgFull.beginParse();
    var flags: int = cs.loadUint(4);
    if (flags & 1) { // ignore bounced messages
        return;
    }
    
    var senderAddress: address = cs.loadAddress();
    
    // Load contract data
    var (ownerAddress, commissionAddress, balance,finalPay, targetAddress, streamingRate, lastUpdated, payFlag) = loadData();
    
    // Add the received TON to the contract balance
   
    
    // Process streaming payment if active
    // if (is_streaming == 1 & (last_updated > 0)) {
    //     int current_time = now();
    //     int time_passed = current_time - last_updated;
        
    //     if (time_passed > 0) {
    //         int amount_to_stream = min(balance, streaming_rate * time_passed / 60);
            
    //         if (amount_to_stream > 0) {
    //             balance -= amount_to_stream;
    //             send_ton(target_address, amount_to_stream, 1); ;; mode 1 = pay transfer fees separately
    //         }
            
    //         last_updated = current_time;
    //     }
    // }
    var op: int = inMsgBody.loadUint(32);
    
    // Process commands
    if (op == 1) { // Set target address
        assert(senderAddress.bitsEqual(ownerAddress)) throw 401;
        assert(finalPay < balance) throw 403;
        if(finalPay > 0){
            sendTon(targetAddress, commissionAddress, finalPay, 1);
            balance = balance - finalPay;
            finalPay = 0;
        }

        targetAddress = inMsgBody.loadAddress();
    }
    
    if (op == 2) { // Set streaming rate
        assert(senderAddress.bitsEqual(ownerAddress)) throw 401;
        assert(finalPay < balance) throw 403;
        if(finalPay > 0){
            sendTon(targetAddress, commissionAddress, finalPay, 1);
            balance = balance - finalPay;
            finalPay = 0;
        }
        streamingRate = inMsgBody.loadCoins();
    }
    
    if (op == 3) { // Start streaming
        assert(senderAddress.bitsEqual(ownerAddress)) throw 401;
        assert(payFlag == 0) throw 402;
        if(finalPay > 0){
            sendTon(targetAddress, commissionAddress, finalPay, 1);
            balance = balance - finalPay;
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
        if(withdrawAmount > balance){
            sendTon(targetAddress, commissionAddress, balance, 1);
            finalPay = withdrawAmount - balance;
            balance = 0;
        }
        else {
            sendTon(targetAddress, commissionAddress, withdrawAmount, 1);
            balance = balance - withdrawAmount;
        }
        payFlag = 0;
    }
    
    if (op == 6){
        balance += msgValue;
    }
    
    // Save updated contract data
    saveData(ownerAddress,commissionAddress, balance, finalPay, targetAddress, streamingRate, lastUpdated, payFlag);
    return;
}

// Get method for external queries
get fun get_streaming_info(): int {
    var (ownerAddress,commissionAddress, balance,finalPay, targetAddress, streamingRate, lastUpdated, payFlag) = loadData();
    var withdrawAmount: int = streamingRate * (blockchain.now() - lastUpdated) / 60;
    return withdrawAmount;
}

get fun get_config(): (address, address, coins, coins, address, coins, int, int) {
    var (ownerAddress, commissionAddress, balance, finalPay, targetAddress, streamingRate, lastUpdated, payFlag) = loadData();
    return (ownerAddress, commissionAddress, balance, finalPay, targetAddress, streamingRate, lastUpdated, payFlag);
}
