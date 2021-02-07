const usdcPool = "0x4F7c28cCb0F1Dbd1388209C67eEc234273C878Bd";
const wethPool = "0x3DA9D911301f8144bdF5c3c67886e5373DCdff8e";

module.exports = {
  usdcPool,
  wethPool,
  pools: [
    // STABLECOINS
    /* USDC */ usdcPool,
    /* USDT */ "0x6ac4a7AB91E6fD098E13B7d347c6d4d1494994a2",
    /* DAI */ "0x15d3A64B2d5ab9E152F16593Cdebc4bB165B5B4A",

    // CHAIN
    /* ETH */ wethPool,
    /* WBTC */ "0x917d6480Ec60cBddd6CbD0C8EA317Bcc709EA77B",
    /* renBTC */ "0x7b8Ff8884590f44e10Ea8105730fe637Ce0cb4F6",
  ],
};
