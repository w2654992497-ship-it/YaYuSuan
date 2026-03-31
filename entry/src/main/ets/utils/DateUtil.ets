export class DateUtil {
  static today(): string {
    return DateUtil.format(new Date())
  }

  static format(date: Date): string {
    const year = date.getFullYear()
    const month = (date.getMonth() + 1).toString().padStart(2, '0')
    const day = date.getDate().toString().padStart(2, '0')
    return `${year}-${month}-${day}`
  }

  static currentMonth(): string {
    const now = new Date()
    const year = now.getFullYear()
    const month = (now.getMonth() + 1).toString().padStart(2, '0')
    return `${year}-${month}`
  }

  static friendlyDate(dateStr: string): string {
    const today = DateUtil.today()
    if (dateStr === today) {
      return '今天'
    }
    const yesterdayDate = new Date()
    yesterdayDate.setDate(yesterdayDate.getDate() - 1)
    const yesterday = DateUtil.format(yesterdayDate)
    if (dateStr === yesterday) {
      return '昨天'
    }
    const parts = dateStr.split('-')
    if (parts.length !== 3) {
      return dateStr
    }
    const month = parseInt(parts[1], 10)
    const day = parseInt(parts[2], 10)
    const weekDays = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六']
    const d = new Date(dateStr)
    const weekDay = weekDays[d.getDay()]
    return `${month}月${day}日 ${weekDay}`
  }

  static getPrevMonth(month: string): string {
    const parts = month.split('-')
    let year = parseInt(parts[0], 10)
    let m = parseInt(parts[1], 10)
    m -= 1
    if (m === 0) {
      m = 12
      year -= 1
    }
    return `${year}-${m.toString().padStart(2, '0')}`
  }

  static getNextMonth(month: string): string {
    const parts = month.split('-')
    let year = parseInt(parts[0], 10)
    let m = parseInt(parts[1], 10)
    m += 1
    if (m === 13) {
      m = 1
      year += 1
    }
    return `${year}-${m.toString().padStart(2, '0')}`
  }

  static getLast6Months(currentMonth: string): string[] {
    const result: string[] = []
    let month = currentMonth
    for (let i = 0; i < 6; i++) {
      result.unshift(month)
      month = DateUtil.getPrevMonth(month)
    }
    return result
  }

  static formatMonthLabel(month: string): string {
    const parts = month.split('-')
    const m = parseInt(parts[1], 10)
    return `${m}月`
  }

  static formatMonthDisplay(month: string): string {
    const parts = month.split('-')
    const year = parseInt(parts[0], 10)
    const m = parseInt(parts[1], 10)
    return `${year}年${m}月`
  }

  static isCurrentMonth(month: string): boolean {
    return month === DateUtil.currentMonth()
  }

  static isSameDay(date1: Date, date2: Date): boolean {
    return date1.getFullYear() === date2.getFullYear() &&
      date1.getMonth() === date2.getMonth() &&
      date1.getDate() === date2.getDate()
  }

  /**
   * 将时间戳转换为相对时间描述
   * 1分钟内 → 刚刚；1小时内 → X分钟前；今天 → HH:mm；昨天 → 昨天 HH:mm；更早 → MM-DD
   */
  static getRelativeTime(timestamp: number): string {
    const now = Date.now()
    const diff = now - timestamp
    if (diff < 60000) return '刚刚'
    if (diff < 3600000) return `${Math.floor(diff / 60000)}分钟前`
    const date = new Date(timestamp)
    const today = new Date()
    const yesterday = new Date(today.getTime() - 86400000)
    if (DateUtil.isSameDay(date, today)) {
      const h = date.getHours().toString().padStart(2, '0')
      const m = date.getMinutes().toString().padStart(2, '0')
      return `${h}:${m}`
    }
    if (DateUtil.isSameDay(date, yesterday)) {
      const h = date.getHours().toString().padStart(2, '0')
      const m = date.getMinutes().toString().padStart(2, '0')
      return `昨天 ${h}:${m}`
    }
    const month = (date.getMonth() + 1).toString().padStart(2, '0')
    const day = date.getDate().toString().padStart(2, '0')
    return `${month}-${day}`
  }
}
