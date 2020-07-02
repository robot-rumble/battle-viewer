import { bigInt } from 'wasm-feature-detect'

const lowerPromise = (async () => {
  if (await bigInt()) {
    return null
  } else {
    const mod = await import('@wasmer/wasm-transformer/lib/wasm-pack/bundler')
    return mod.lowerI64Imports
  }
})()

const runnerCache = Object.create(null)

const runnerMap = {
  Python: 'pyrunner',
  Javascript: 'jsrunner',
}
export default async (assetsPath, lang) => {
  const name = runnerMap[lang]
  if (name in runnerCache) return runnerCache[name]
  const prom = (async () => {
    const path = process.env.NODE_ENV === 'production'
      ? assetsPath + `/lang-runners/${name}.wasm`
      : assetsPath + `/dist/${name}.wasm`
    const res = await fetch(path)
    let wasm = await res.arrayBuffer()
    const lowerI64Imports = await lowerPromise
    if (lowerI64Imports) {
      wasm = lowerI64Imports(new Uint8Array(wasm))
    }
    return WebAssembly.compile(wasm)
  })()
  runnerCache[name] = prom
  return prom
}
