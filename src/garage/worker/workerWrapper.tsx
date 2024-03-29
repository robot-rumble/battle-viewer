import * as Comlink from 'comlink'
import { Lang } from '../utils/constants'
import { CallbackParams, MatchWorker, RunParams } from './match.worker'

const TIMER_CHECK_EVERY = 500
const TIMER_TIMEOUT = 15000

class Timer {
  private running = false

  constructor(private timedOutCb: () => void) { }

  start() {
    if (this.running) {
      throw new Error('Timer started while it is already running')
    }
    this.running = true

    const startTime = Date.now()
    const cb = () => {
      console.log(`Loading for: ${(Date.now() - startTime) / 1000} seconds`)
      if (this.running) {
        if (Date.now() - startTime > TIMER_TIMEOUT) {
          this.timedOutCb()
        } else {
          setTimeout(cb, TIMER_CHECK_EVERY)
        }
      }
    }

    setTimeout(cb, TIMER_CHECK_EVERY)
  }

  finish() {
    this.running = false
  }
}

export class WorkerWrapper {
  private worker!: Worker
  private matchWorker!: MatchWorker
  private running = false
  private timer!: Timer

  constructor(
    private finishedDownloadingCb: () => void,
    private finishedLoadingCb: () => void,
    timedOutCb: () => void,
    private workerCb: (params: CallbackParams) => void,
    private lang: Lang,
    assetsPath: string,
    workerUrl: string,
  ) {
    this.timer = new Timer(timedOutCb)
    this.initWorkers(assetsPath, workerUrl)
  }

  changeLang(lang: Lang, assetsPath: string, workerUrl: string) {
    this.timer.finish()
    setTimeout(() => {
      this.worker.terminate()
      this.lang = lang
      this.initWorkers(assetsPath, workerUrl)
    }, TIMER_CHECK_EVERY)
  }

  start(params: RunParams) {
    if (this.running) return
    this.running = true

    const runCallback = (params: CallbackParams) => {
      // ---- end time check ----
      this.timer.finish()

      if (params.type === 'error' || params.type === 'getOutput') {
        this.running = false
      }
      console.log(params)
      this.workerCb(params)
    }

    // ---- start time check ----
    this.timer.start()
    this.matchWorker.run(params, Comlink.proxy(runCallback))
  }

  private async initWorkers(assetsPath: string, workerUrl: string) {
    // ---- start time check ----
    this.timer.start()

    this.worker = new Worker(workerUrl)
    const MatchWorker = Comlink.wrap(this.worker)
    // @ts-ignore
    this.matchWorker = (await new MatchWorker()) as MatchWorker

    await this.matchWorker.init(
      assetsPath,
      this.lang,
      Comlink.proxy(this.finishedDownloadingCb),
    )
    this.finishedLoadingCb()

    // ---- end time check ----
    this.timer.finish()
  }
}
