import { hilog } from '@kit.PerformanceAnalysisKit'

// 发布前改为 false 关闭 debug/info/warn 日志输出
const IS_DEBUG: boolean = false

export class LogUtils {
  private static readonly DOMAIN: number = 0x0000
  private static readonly TAG: string = 'YaYuSuan'

  static debug(tag: string, format: string, ...args: (string | number | boolean)[]): void {
    if (!IS_DEBUG) return
    hilog.debug(LogUtils.DOMAIN, `${LogUtils.TAG}_${tag}`, format, ...args)
  }

  static info(tag: string, format: string, ...args: (string | number | boolean)[]): void {
    if (!IS_DEBUG) return
    hilog.info(LogUtils.DOMAIN, `${LogUtils.TAG}_${tag}`, format, ...args)
  }

  static warn(tag: string, format: string, ...args: (string | number | boolean)[]): void {
    if (!IS_DEBUG) return
    hilog.warn(LogUtils.DOMAIN, `${LogUtils.TAG}_${tag}`, format, ...args)
  }

  static error(tag: string, format: string, ...args: (string | number | boolean)[]): void {
    // error 始终输出，不受 IS_DEBUG 控制
    hilog.error(LogUtils.DOMAIN, `${LogUtils.TAG}_${tag}`, format, ...args)
  }
}
