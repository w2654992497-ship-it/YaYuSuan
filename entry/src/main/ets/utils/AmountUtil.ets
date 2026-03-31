export class AmountUtil {
  static fen2Display(fen: number): string {
    const yuan = fen / 100
    return yuan.toFixed(2)
  }

  static yuan2Fen(yuan: string): number {
    const val = parseFloat(yuan)
    if (isNaN(val)) {
      return 0
    }
    return Math.round(val * 100)
  }

  static formatWithSign(fen: number, type: 'income' | 'expense'): string {
    const display = AmountUtil.fen2Display(fen)
    if (type === 'income') {
      return `+¥${display}`
    } else {
      return `-¥${display}`
    }
  }

  static shortFormat(fen: number): string {
    const yuan = fen / 100
    if (yuan >= 10000) {
      return `¥${(yuan / 10000).toFixed(1)}w`
    } else if (yuan >= 1000) {
      return `¥${(yuan / 1000).toFixed(1)}k`
    } else {
      return `¥${yuan.toFixed(2)}`
    }
  }
}
