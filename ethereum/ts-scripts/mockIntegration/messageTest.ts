import * as wh from "@certusone/wormhole-sdk"
import { Implementation__factory } from "@certusone/wormhole-sdk/lib/cjs/ethers-contracts"
import { getSignatureSetData } from "@certusone/wormhole-sdk/lib/cjs/solana/wormhole"
import { LogMessagePublishedEvent } from "../../../sdk/src"
import {
  ChainInfo,
  getCoreRelayer,
  getCoreRelayerAddress,
  getMockIntegration,
  getMockIntegrationAddress,
  getRelayProviderAddress,
  init,
  loadChains,
} from "../helpers/env"
import * as grpcWebNodeHttpTransport from "@improbable-eng/grpc-web-node-http-transport"

init()
const chains = loadChains()

async function sendMessage(
  sourceChain: ChainInfo,
  targetChain: ChainInfo,
  fetchSignedVaa: boolean = false
) {
  console.log(
    `Sending message from chain ${sourceChain.chainId} to ${targetChain.chainId}...`
  )

  const sourceRelayer = getCoreRelayer(sourceChain)

  // todo: remove
  const registeredChain = await sourceRelayer.registeredCoreRelayerContract(
    sourceChain.chainId
  )
  console.log("The source chain should be registered to itself")
  console.log(registeredChain)
  console.log(getCoreRelayerAddress(sourceChain))
  console.log("")

  const defaultRelayerProvider = await sourceRelayer.getDefaultRelayProvider()
  console.log("Default relay provider should be this chains relayProvider ")
  console.log(defaultRelayerProvider)
  console.log(getRelayProviderAddress(sourceChain))
  console.log("")

  const relayQuote = await (
    await sourceRelayer.quoteGasDeliveryFee(
      targetChain.chainId,
      2000000,
      sourceRelayer.getDefaultRelayProvider()
    )
  ).add(10000000000)
  console.log("relay quote: " + relayQuote)

  const mockIntegration = getMockIntegration(sourceChain)
  const targetAddress = getMockIntegrationAddress(targetChain)

  const tx = await mockIntegration.sendMessage(
    Buffer.from("Hello World"),
    targetChain.chainId,
    targetAddress,
    targetAddress,
    {
      gasLimit: 1000000,
      value: relayQuote,
    }
  )
  const rx = await tx.wait()
  const sequences = wh.parseSequencesFromLogEth(rx, sourceChain.wormholeAddress)
  console.log("Tx hash: ", rx.transactionHash)
  console.log(`Sequences: ${sequences}`)
  if (fetchSignedVaa) {
    for (let i = 0; i < 120; i++) {
      try {
        const vaa1 = await fetchVaaFromLog(rx.logs[0], sourceChain.chainId)
        console.log(vaa1)
        const vaa2 = await fetchVaaFromLog(rx.logs[1], sourceChain.chainId)
        console.log(vaa2)
        break
      } catch (e) {
        console.error(`${i} seconds`)
        if (i === 0) {
          console.error(e)
        }
      }
      await new Promise((resolve) => setTimeout(resolve, 1_000))
    }
  }
  console.log("")
}

async function run() {
  console.log(process.argv)
  const fetchSignedVaa = !!process.argv.find((arg) => arg === "--fetchSignedVaa")
  if (process.argv[2] === "--from" && process.argv[4] === "--to") {
    await sendMessage(
      getChainById(process.argv[3]),
      getChainById(process.argv[5]),
      fetchSignedVaa
    )
  } else if (process.argv[4] === "--from" && process.argv[2] === "--to") {
    await sendMessage(
      getChainById(process.argv[5]),
      getChainById(process.argv[3]),
      fetchSignedVaa
    )
  } else if (process.argv[2] === "--per-chain") {
    for (let i = 0; i < chains.length; ++i) {
      await sendMessage(
        chains[i],
        chains[i === 0 ? chains.length - 1 : 0],
        fetchSignedVaa
      )
    }
  } else if (process.argv[2] === "--matrix") {
    for (let i = 0; i < chains.length; ++i) {
      for (let j = 0; i < chains.length; ++i) {
        await sendMessage(chains[i], chains[j], fetchSignedVaa)
      }
    }
  } else {
    await sendMessage(chains[0], chains[1], fetchSignedVaa)
  }
}

function getChainById(id: number | string): ChainInfo {
  id = Number(id)
  const chain = chains.find((c) => c.chainId === id)
  if (!chain) {
    throw new Error("chainId not found, " + id)
  }
  return chain
}

console.log("Start!")
run().then(() => console.log("Done!"))

export async function encodeEmitterAddress(
  myChainId: wh.ChainId,
  emitterAddressStr: string
): Promise<string> {
  if (myChainId === wh.CHAIN_ID_SOLANA || myChainId === wh.CHAIN_ID_PYTHNET) {
    return await wh.getEmitterAddressSolana(emitterAddressStr)
  }
  if (wh.isTerraChain(myChainId)) {
    return await wh.getEmitterAddressTerra(emitterAddressStr)
  }
  if (wh.isEVMChain(myChainId)) {
    return wh.getEmitterAddressEth(emitterAddressStr)
  }
  throw new Error(`Unrecognized wormhole chainId ${myChainId}`)
}

function fetchVaaFromLog(bridgeLog: any, chainId: wh.ChainId): Promise<wh.SignedVaa> {
  const iface = Implementation__factory.createInterface()
  const log = iface.parseLog(bridgeLog) as unknown as LogMessagePublishedEvent
  const sequence = log.args.sequence.toString()
  const emitter = wh.tryNativeToHexString(log.args.sender, "ethereum")
  return wh
    .getSignedVAA(
      "https://wormhole-v2-testnet-api.certus.one",
      chainId,
      emitter,
      sequence,
      { transport: grpcWebNodeHttpTransport.NodeHttpTransport() }
    )
    .then((r) => r.vaaBytes)
}
