import { WASI } from "@wasmer/wasi";
import { WasmFs } from "@wasmer/wasmfs";
import wasiBindings from "@wasmer/wasi/lib/bindings/browser";
import * as Comlink from "comlink";

class WasiRunner {
  async setup(module, files) {
    this.wasmFs = new WasmFs();
    this.wasmFs.volume.fromJSON(files);
    this.wasi = new WASI({
      preopens: { '/': '/' },
      bindings: {
        ...wasiBindings,
        fs: this.wasmFs.fs,
      },
    });
    const {exports} = await WebAssembly.instantiate(module, { ...this.wasi.getImports(module) });
    this.wasmExports = exports;
    this.wasi.setMemory(exports.memory);
    this._initResult = null;
  }
  get init_result() {
    const {_initResult} = this;
    this._initResult = null;
    return _initResult;
  }
  set_input(input) {
    const ptr = this.wasmExports.__rr_prealloc(input.byteLength);
    const buf = new Uint8Array(this.wasmExports.memory.buffer, ptr, input.byteLength);
    buf.set(input);
  }
  get_output(len) {
    const ptr = this.wasmExports.__rr_io_addr();
    return new Uint8Array(this.wasmExports.memory.buffer, ptr, len);
  }
  init(input) {
    this.set_input(input)
    try {
      const len = this.wasmExports.__rr_init()
      this._initResult = this.get_output(len)
    } catch (e) {
      console.error("error while initializing", e, e && e.stack)
      return { output: new TextEncoder().encode('{"Err":{"InternalError":null}}'), logs }
    }
  }
  run_turn(input) {
    const {fs} = this.wasmFs
    fs.writeFileSync("/dev/stdout", "")
    this.set_input(input)
    let logs
    try {
      const len = this.wasmExports.__rr_run_turn()
      logs = fs.readFileSync("/dev/stdout", "utf8")
      return { output: this.get_output(len), logs }
    } catch (e) {
      console.error("error while running turn", e, e && e.stack)
      return { output: new TextEncoder().encode('{"robot_outputs":{"Err":{"InternalError":null}}}'), logs }
    }
  }
}

Comlink.expose(WasiRunner)
