
function keystoreProvider (providerURL) {
  const fs = require('fs');
  const EthereumjsWallet = require('ethereumjs-wallet');
  const HDWalletProvider = require('truffle-hdwallet-provider');

  const KEYFILE = process.env.KEYFILE;
  const PASSPHRASE = (process.env.PASSPHRASE || '');
  if (!KEYFILE) {
    throw new Error('Expected environment variable KEYFILE with path to ethereum wallet keyfile');
  }

  const KEYSTORE = JSON.parse(fs.readFileSync(KEYFILE));
  const wallet = EthereumjsWallet.fromV3(KEYSTORE, PASSPHRASE);
  return new HDWalletProvider(wallet._privKey.toString('hex'), providerURL);
}
const HDWalletProvider = require('truffle-hdwallet-provider');
const rinkeby = 'https://rinkeby.infura.io/v3/2521699167dc43c8b4c15f07860c208a';
module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",     // Localhost (default: none)
      port: 7545,            // Standard Ethereum port (default: none)
      network_id: "*",       // Any network (default: none)
//      gas: 7500000,
    },
    rinkeby : {
          provider: () => new HDWalletProvider("",
          rinkeby),
          network_id: 4,   // This network is yours, in the cloud.
  //       production: true    // Treats this network as if it was a public net. (default: false)
          timeoutBlocks: 300,  // # of blocks before a deployment times out  (minimum/default: 50)
          gasPrice: 1000000000,
        skipDryRun: true     // Skip dry run before migrations? (default: false for public nets )
    }
  },
  mocha: {

  },
  compilers: {
    solc: {
//      version: '0.5.0'
    }
  }
};
