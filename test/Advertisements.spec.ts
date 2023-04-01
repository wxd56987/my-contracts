import { Advertisements } from '../typechain/Advertisements';
import { Wallet, BigNumber } from 'ethers'
import { ethers, waffle } from 'hardhat'
import { expect } from './shared/expect'
import { adFixture, signForComplete } from './shared/fixtures'

const createFixtureLoader = waffle.createFixtureLoader

describe('Advertisements', async () => {
    let wallet: Wallet, other: Wallet;

    let ad: Advertisements;

    let loadFixTure: ReturnType<typeof createFixtureLoader>;

    before('create fixture loader', async () => {
        [wallet, other] = await (ethers as any).getSigners()
        loadFixTure = createFixtureLoader([wallet])
    })

    beforeEach('deploy Contract', async () => {
        ; ({ ad } = await loadFixTure(adFixture));
    })

    describe('#createAd', async () => {
        it('success', async () => {
            let ipfs = 'ipfs/test'
            let inventory = BigNumber.from(2)
            let reward = BigNumber.from(ethers.constants.WeiPerEther)
            let type = BigNumber.from(0)
            let balanceBefore = await wallet.getBalance()
            await ad.createAd(ipfs, type, inventory, reward, { value: ethers.constants.WeiPerEther.mul(2) })
            let balanceAfter = await wallet.getBalance()
            expect(await ad.adLength()).to.eq(1)
            expect(balanceBefore.sub(balanceAfter)).to.gt(ethers.constants.WeiPerEther.mul(2))
            let gasConsume = BigNumber.from("250000000000000")
            expect(balanceBefore.sub(balanceAfter)).to.lt(ethers.constants.WeiPerEther.mul(2).add(gasConsume))
        })
    })

    describe('#completeAd', async () => {
        beforeEach('createAd', async () => {
            let ipfs = 'ipfs/test'
            let inventory = BigNumber.from(2)
            let reward = BigNumber.from(ethers.constants.WeiPerEther)
            let type = BigNumber.from(0)
            await ad.createAd(ipfs, type, inventory, reward, { value: ethers.constants.WeiPerEther.mul(2) })
        })

        it('success', async () => {
            let adIndex = BigNumber.from(0)
            let sig = await signForComplete(wallet, adIndex.toString(), other.address, ad.address)
            let balanceBefore = await other.getBalance()
            await ad.connect(other).completeAd(adIndex, sig)
            let balanceAfter = await other.getBalance()
            expect(balanceAfter.sub(balanceBefore)).to.gt(ethers.constants.WeiPerEther.div(2))
            expect(balanceAfter.sub(balanceBefore)).to.lt(ethers.constants.WeiPerEther)
        })
    })
})