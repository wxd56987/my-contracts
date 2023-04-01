import { TestERC20 } from './../../typechain/TestERC20';
import { Advertisements } from './../../typechain/Advertisements';
import { Wallet } from 'ethers'
import { ethers, network } from 'hardhat'
import { Fixture } from 'ethereum-waffle'

async function testERC20(): Promise<TestERC20> {
    let factory = await ethers.getContractFactory('TestERC20')
    let token = (await factory.deploy()) as TestERC20
    return token
}

interface AdFixture {
    ad: Advertisements
}

export const adFixture: Fixture<AdFixture> = async function ([wallet]: Wallet[]): Promise<AdFixture> {
    let adFactory = await ethers.getContractFactory('Advertisements')
    let ad = (await adFactory.deploy()) as Advertisements
    await ad.initialize(wallet.address)
    return { ad }
}

export const signForComplete = async function (
    wallet: Wallet,
    adIndex: string,
    user: string,
    addr: string
) {
    let types = ['uint256', 'address', 'address']
    let values = [adIndex, user, addr]
    let message = ethers.utils.solidityKeccak256(types, values)
    let s = await network.provider.send('eth_sign', [wallet.address, message])
    return s;
}