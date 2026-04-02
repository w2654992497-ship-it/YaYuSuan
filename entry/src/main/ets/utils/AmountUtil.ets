export class AmountUtil {
  static fen2Display(fen: number): string {
    const safeFen = isNaN(fen) ? 0 : fen
    const yuan = safeFen / 100
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

  // 日历格子中的简短金额（无¥号，整数省略小数）
  static shortYuan(fen: number): string {
    const safeFen = isNaN(fen) ? 0 : fen
    const yuan = safeFen / 100
    if (yuan >= 10000) {
      return `${(yuan / 10000).toFixed(1)}w`
    } else if (yuan >= 1000) {
      return `${(yuan / 1000).toFixed(1)}k`
    } else if (yuan === Math.floor(yuan)) {
      return `${yuan}`
    } else {
      return yuan.toFixed(1)
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
