const { assert, expect } = require("chai");
require("chai")
    .use(require("chai-as-promised"))
    .should();

const FAsset = artifacts.require("FAsset");
const DEVFEE = '1000';
const DECIMALS = 18
const PRECISION = 4;
const DELEGATION_LIMIT = 5;
const BN = web3.utils.BN;

let fAsset;


function toPercent(n){
    return n.div(new BN(Math.pow(10,PRECISION)));
}

contract("FAsset",async([dev,bob,lucy,ed])=>{
    before(async()=>{
        let block = await web3.eth.getBlockNumber();

        fAsset = await FAsset.new(DECIMALS,DEVFEE,PRECISION,DELEGATION_LIMIT,"THE NAME","PCP",{from:dev});
    });

    describe("Contract Deployment",async()=>{

        it("has a name", async()=>{
            const name = await fAsset.name();
            assert.equal(name,"THE NAME");
        });

        it("has a symbol", async()=>{
            const symbol = await fAsset.symbol();
            assert.equal(symbol,"PCP");
        });

        it("gives devFee", async()=>{
            const devFee = await fAsset.balanceOf(dev);
            assert.equal(devFee,DEVFEE);
        });
    });

    describe('ERC20 Functions', async() => {

        it('transfers tokens to Bob',async()=>{
            const amm = '20';
            await fAsset.approve(bob,amm,{from:dev});
            await fAsset.transferFrom(dev,bob,amm);
            const bal = await fAsset.balanceOf(bob);

            assert.equal(bal,amm);
        });

        it('transfers tokens to Lucy',async()=>{
            const amm = '10';
            await fAsset.approve(lucy,amm,{from:dev});
            await fAsset.transferFrom(dev,lucy,amm);
            const bal = await fAsset.balanceOf(lucy);

            assert.equal(bal,amm);
        });
    });

    describe('balanceOfAt', async() => {
        
        it('shows old balance for Bob at 0',async()=>{
            const bal = await fAsset.balanceOfAt(bob,0);
            assert.equal(bal,0);
        });

        it('shows new balance for Bob at current block', async()=>{
            const block = await web3.eth.getBlockNumber();
            const bal = await fAsset.balanceOfAt(bob,block);
            assert.equal(bal,'20');
        });

        it('shows new balance for Lucy at current block', async()=>{
            const block = await web3.eth.getBlockNumber();
            const bal = await fAsset.balanceOfAt(lucy,block);
            assert.equal(bal,'10');
        });
    });
    
    describe('votePower', async()=>{

        it('Bob has vote power equal to tokens to start', async()=>{
            const block = await web3.eth.getBlockNumber();
            const vp = await fAsset.votePowerAt(bob,block);
            const bal = await fAsset.balanceOfAt(bob,block);
            assert.equal(toPercent(vp).toString(),'20');
        });

        it('Bob delegates 50% to lucy', async()=>{
            await fAsset.delegate(lucy,5000,{from:bob});
            const block = await web3.eth.getBlockNumber();
            const vp = await fAsset.votePowerAt(lucy,block);
            assert.equal(toPercent(vp).toString(),'20');
        });

        it('Bob delegates 25% to Ed', async()=>{
            await fAsset.delegate(ed,2500,{from:bob});
            const block = await web3.eth.getBlockNumber();
            const vp = await fAsset.votePowerAt(ed,block);
            assert.equal(toPercent(vp).toString(),'5');
        });

        it('Bob has 5 vote power left', async()=>{
            const block = await web3.eth.getBlockNumber();
            const vp = await fAsset.votePowerAt(bob,block);
            assert.equal(toPercent(vp).toString(),'5');
        });
    });

    describe('votePower after token transfer', async()=>{
        
        it('Bob receives 16 tokens from dev ', async()=>{
            await fAsset.approve(bob,16,{from:dev});
            await fAsset.transferFrom(dev,bob,16);
            const bal = await fAsset.balanceOf(bob);
            assert.equal(bal.toString(),'36');
        });

        it('Vote power of Lucy is now 28', async()=>{
            const block = await web3.eth.getBlockNumber();
            const vp = await fAsset.votePowerAt(lucy,block);
            assert.equal(toPercent(vp).toString(),'28');
        });

        it('Vote power of Bob is now 9', async()=>{
            const block = await web3.eth.getBlockNumber();
            const vp = await fAsset.votePowerAt(bob,block);
            assert.equal(toPercent(vp).toString(),'9');
        });

        it('Vote power of Ed is now 9', async()=>{
            const block = await web3.eth.getBlockNumber();
            const vp = await fAsset.votePowerAt(ed,block);
            assert.equal(toPercent(vp).toString(),'9');
        });

    });

    describe('Lucy delegates 100% to Ed', async()=>{

        before(async()=>{
            await fAsset.delegate(ed,10000,{from:lucy});
        });

        it('Lucy has 18 vote power now', async()=>{
            const block = await web3.eth.getBlockNumber();
            const vp = await fAsset.votePowerAt(lucy,block);
            assert.equal(toPercent(vp).toString(),'18');
        });

        it('Ed has 19 vote power now', async()=>{
            const block = await web3.eth.getBlockNumber();
            const vp = await fAsset.votePowerAt(ed,block);
            assert.equal(toPercent(vp).toString(),'19');
        });
    })
});

