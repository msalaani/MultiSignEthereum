const MultiSign = artifacts.require("MultiSign");
const ReceiverContract = artifacts.require("ReceiverContract");

/*
 * uncomment accounts to access the test accounts made available by the
 * Ethereum client
 * See docs: https://www.trufflesuite.com/docs/truffle/testing/writing-tests-in-javascript
 */
contract("MultiSign", function (/* accounts */) {



  it("Deployment using Development network accounts, and threshold = 1, Nothing to Test!", async function () {
    var accounts = await web3.eth.getAccounts()
    await MultiSign.deployed();
    return assert.isTrue(true);
  });

  let wallet
  let accounts
  let THRESHOLD
  let owners
  let receiver
  beforeEach(async() => {
    accounts = await web3.eth.getAccounts()

    owners = [accounts[0], accounts[1], accounts[2]]
    THRESHOLD = 2;
    receiver = await ReceiverContract.new()
    wallet = await MultiSign.new(owners, THRESHOLD)
  })

  /*it ('First test without signing', async function () {
    const to = owners[0]
    const value = 0
    const data = "0x0"
    await wallet.submitTransaction(to, value, data)

    await wallet.confirmTransaction(0, { from: owners[0]})
    await wallet.confirmTransaction(0, { from: owners[1]})

    var tr = await wallet.getTransaction(0);
    console.log(tr);

    await wallet.executeTransaction(0);
    tr = await wallet.getTransaction(0);
    console.log(tr);

  }); // worked fine before modif1
  */

  // signing funct

  /*let createSigs = function( signers, data) {
    // var accounts = signers;
    const dataHash =  web3.eth.accounts.hashMessage(msg)
    let sigV = []
    let sigR = []
    let sigS = []

    for (var i = 0; i < signers.length; i++) {
      var signature = await web3.eth.sign(dataHash, signers[i])

      var r = signature.slice(0, 66);
      var s = "0x" + signature.slice(66, 130);
      var v = "0x" + signature.slice(130, 132);
      v = web3.utils.toDecimal(v);
      v = v + 27;

      sigV.push(v);
      sigR.push(r);
      sigS.push(s);
    }

    return {sigV: sigV, sigR: sigR, sigS: sigS}

  }*/

  // end sign func

    it ('Second test with signing', async function () {
    


    //console.log(owners);

    const to = receiver.address //owners[1]
    //console.log(to);
    const value = 15
    const data = '0x0000000000000000000000000000000000000000000000000000006d6168616d'
    await wallet.submitTransaction(to, value, data)

    await wallet.confirmTransaction(0, { from: owners[0]})
    await wallet.confirmTransaction(0, { from: owners[1]})

    console.log('Transaction before checking signatures')
    var tr = await wallet.getTransaction(0);
    console.log(tr);

    // signing config
    //var accounts = signers;
    var msg = data
    var signers = [owners[0],owners[1]]
    // console.log(signers)
    // const dataHash =  web3.eth.accounts.hashMessage(msg)
    const dataHash = await wallet.getTXHashfromID(0);
    
    // console.log("hash1")
    // console.log(dataHash);

    let sigV = []
    let sigR = []
    let sigS = []

    for (var i = 0; i < signers.length; i++) {
      var signature = await web3.eth.sign(dataHash, signers[i])

      var r = signature.slice(0, 66);
      var s = "0x" + signature.slice(66, 130);
      var v = "0x" + signature.slice(130, 132);
      v = web3.utils.toDecimal(v);
      v = v + 27;
        
      // testing 
      var result = await wallet.checkSignature(dataHash, v, r, s);
      //console.log('signer:')
      //console.log(result)
      
      sigV.push(v);
      sigR.push(r);
      sigS.push(s);
    }

    // end sig config

    let sigs = {sigV: sigV, sigR: sigR, sigS: sigS}
    //console.log(sigs);


    let ows = await wallet.getOwners();
    //console.log("owners:")
    //console.log(ows)
    
    console.log('\n\n=================================================')
    console.log('Transaction executed after checking signatures')
    await wallet.executeTransaction(0,sigV,sigR,sigS);
    tr = await wallet.getTransaction(0);
    console.log(tr);


  });

});
