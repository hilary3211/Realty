'reach 0.1';
//creator deploys the contract, participant1 will use api to get the information from the frontend

export const main = Reach.App(() => {
    const Creator = Participant('Creator', {
        getSale: Fun([], Object({
            nftId: Token,
            //minBid: UInt,
            lenInBlocks: UInt,
        })),
        auctionReady: Fun([], Null),
        seeBid: Fun([Address, UInt], Null),
        showOutcome: Fun([Address, UInt], Null),
    });

    const Seller = API('Seller', {
        getSale1: Fun([Token, UInt], Tuple(Address, Token, UInt)),
    });
    const Bidder = API('Bidder', {
        bid: Fun([UInt], Tuple(Address, UInt)),
    });
    init();

    Creator.only(() => {
        const { nftId, lenInBlocks } = declassify(interact.getSale());
    });
    Creator.publish(nftId, lenInBlocks);
    const amt = 1;
    const minBid = 1
    commit();
    Creator.pay([amt]);
    assert(balance(nftId) == amt, "balance of NFT is wrong");
    const end = lastConsensusTime() + lenInBlocks;
    const [
        sellerAddress,
        nftid,
        minbid] =
        parallelReduce([Creator, nftId, minBid])
            .invariant(balance(nftId) == amt && balance() == minBid)
            .while(lastConsensusTime() <= end)
            .api(Seller.getSale1,

                ((nftid, minbid) => { assume(nftid == amt, "bid is too low"); }),
                //((nftid, minbid) => getSale1),
                ((nftid, minbid, notify) => {
                    require()
                    notify([nftid, minbid]);
                    const who = this
                    return [who, nftid, minbid]
                })

            ).timeout(absoluteTime(end), () => {
                Creator.publish();
                return [sellerAddress, nftid, minbid];
            })
    const [
        highestBidder,
        lastPrice,
        isFirstBid,
    ] = parallelReduce([Creator, minBid, true])
        .invariant(balance(nftId) == amt && balance() == (isFirstBid ? 0 : lastPrice))
        .while(lastConsensusTime() <= end)
        .api(Bidder.bid, //user wats to bid
            ((bid) => { assume(bid > lastPrice, "bid is too low"); }),
            ((bid) => bid),
            ((bid, notify) => {
                require(bid > lastPrice, "bid is too low");
                notify([highestBidder, lastPrice]);
                if (!isFirstBid) {
                    transfer(lastPrice).to(highestBidder);
                }
                const who = this; //this signifies whoever is intracting with the contract at the momet 
                Creator.interact.seeBid(who, bid);
                return [who, bid, false];
            })
        ).timeout(absoluteTime(end), () => {
            Creator.publish();
            return [highestBidder, lastPrice, isFirstBid];
        });

    transfer(amt, nftId).to(highestBidder);
    if (!isFirstBid) { transfer(lastPrice).to(Creator); }
    Creator.interact.showOutcome(highestBidder, lastPrice);
    commit();
    exit();
});