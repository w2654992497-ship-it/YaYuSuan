import { promptAction } from '@kit.ArkUI'

export class ToastUtils {
  static showShort(message: string): void {
    try {
      promptAction.showToast({ message: message, duration: 2000 })
    } catch {
      // ignore
    }
  }

  static showLong(message: string): void {
    try {
      promptAction.showToast({ message: message, duration: 3500 })
    } catch {
      // ignore
    }
  }

  static success(message: string): void {
    ToastUtils.showShort(message)
  }

  static error(message: string): void {
    ToastUtils.showLong(message)
  }

  static warning(message: string): void {
    ToastUtils.showShort(message)
  }
}
