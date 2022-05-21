'reach 0.1'
//creator deploys the contract, participant1 will use api to get the information from the frontend

export const main = Reach.App(() => {
    const Creator = Participant('Creator', {
        getSale: Fun([], Object({
            nftId: Token,
            minBid: UInt,
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
        const { nftId, minBid, lenInBlocks } = declassify(interact.getSale());
    });
    Creator.publish(nftId, minBid, lenInBlocks);
    const amt = 1;
    //const minBid = 1
    commit();
    Creator.pay([[amt, nftId]]);
    assert(balance(nftId) == amt, "balance of NFT is wrong");
    const end = lastConsensusTime() + lenInBlocks;
    const [
        sellerAddress,
        nftid,
        minbid] =
        parallelReduce([Creator, nftId, minBid])
            .invariant(balance(nftId) == amt)
            .while(lastConsensusTime() <= end)
            .api(Seller.getSale1,
                ((y, x) => {
                    //assume(b == nftId);
                    assume(y == nftId);
                    assume(x == minBid);

                }),
                ((_, x) => x),
                ((y, x, otify) => {
                    //require(b == amt);
                    require(y == nftId);
                    require(x == minBid);
                    otify([sellerAddress, nftid, minbid]);
                    const who = this
                    return [who, y, x]
                })

            ).timeout(absoluteTime(end), () => {
                Creator.publish();
                return [sellerAddress, nftid, minbid];
            });
    //transfer(balance()).to(Creator)
    commit();
    exit();
});