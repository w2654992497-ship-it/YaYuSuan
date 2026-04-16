import { MonthStat } from '../model/StatResult'
import { AmountUtil } from '../utils/AmountUtil'

@Component
export struct StyledBarChart {
  @Watch('redraw')
  @Prop data: MonthStat[] = []

  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  private readonly incomeColor: string = '#76B041'
  private readonly expenseColor: string = '#EF476F'
  private readonly textMultiplier: number = 2

  redraw(): void {
    this.drawChart()
  }

  private scaleFactor(width: number): number {
    return Math.max(1, Math.min(3.5, width / 360))
  }

  private textScaleFactor(width: number): number {
    return Math.max(1.9, Math.min(3.4, width / 220)) * this.textMultiplier
  }

  private font(size: number, family: string, weight: string = ''): string {
    return weight.length > 0 ? `${weight} ${size}px ${family}` : `${size}px ${family}`
  }

  private formatMonth(month: string): string {
    const parts = month.split('-')
    if (parts.length < 2) {
      return month
    }
    const monthNum = parseInt(parts[1], 10)
    return `${monthNum}月`
  }

  private niceMax(value: number): number {
    if (value <= 0) {
      return 10000
    }
    const pow = Math.pow(10, Math.floor(Math.log10(value)))
    const scaled = value / pow
    if (scaled <= 1) return 1 * pow
    if (scaled <= 2) return 2 * pow
    if (scaled <= 5) return 5 * pow
    return 10 * pow
  }

  private drawRoundedRect(x: number, y: number, width: number, height: number, radius: number, color: string): void {
    const ctx = this.context
    const r = Math.min(radius, width / 2, height / 2)
    ctx.beginPath()
    ctx.moveTo(x + r, y)
    ctx.arcTo(x + width, y, x + width, y + height, r)
    ctx.arcTo(x + width, y + height, x, y + height, r)
    ctx.arcTo(x, y + height, x, y, r)
    ctx.arcTo(x, y, x + width, y, r)
    ctx.closePath()
    ctx.fillStyle = color
    ctx.fill()
  }

  private drawLegend(startX: number, y: number, width: number): void {
    const ctx = this.context
    const layoutScale = this.scaleFactor(width)
    const textScale = this.textScaleFactor(width)
    const marker = Math.max(10, Math.round(10 * layoutScale))
    const fontSize = Math.max(11, Math.round(11 * textScale))
    const gap = Math.max(14, Math.round(14 * layoutScale))
    const secondOffset = Math.max(54, Math.round(54 * layoutScale))

    this.drawRoundedRect(startX, y - marker / 2, marker, marker, Math.max(3, Math.round(3 * layoutScale)), this.incomeColor)
    ctx.fillStyle = '#5B6675'
    ctx.font = this.font(fontSize, 'sans-serif')
    ctx.textAlign = 'left'
    ctx.textBaseline = 'middle'
    ctx.fillText('收入', startX + gap, y)

    this.drawRoundedRect(startX + secondOffset, y - marker / 2, marker, marker, Math.max(3, Math.round(3 * layoutScale)), this.expenseColor)
    ctx.fillStyle = '#5B6675'
    ctx.fillText('支出', startX + secondOffset + gap, y)
  }

  private drawEmpty(width: number, height: number): void {
    const ctx = this.context
    const textScale = this.textScaleFactor(width)
    ctx.fillStyle = '#98A2B3'
    ctx.font = this.font(Math.max(14, Math.round(14 * textScale)), 'sans-serif')
    ctx.textAlign = 'center'
    ctx.textBaseline = 'middle'
    ctx.fillText('暂无数据', width / 2, height / 2)
  }

  private drawChart(): void {
    const ctx = this.context
    const width = ctx.width
    const height = ctx.height

    ctx.clearRect(0, 0, width, height)
    if (!this.data || this.data.length === 0) {
      this.drawEmpty(width, height)
      return
    }

    const scale = this.scaleFactor(width)
    const textScale = this.textScaleFactor(width)
    const paddingLeft = Math.round(40 * scale)
    const paddingTop = Math.round(28 * scale)
    const paddingRight = Math.round(14 * scale)
    const paddingBottom = Math.round(34 * scale)
    const chartWidth = width - paddingLeft - paddingRight
    const chartHeight = height - paddingTop - paddingBottom

    let rawMax = 0
    for (const item of this.data) {
      if (item.income > rawMax) rawMax = item.income
      if (item.expense > rawMax) rawMax = item.expense
    }
    const maxValue = this.niceMax(rawMax)

    const gridCount = 4
    for (let i = 0; i <= gridCount; i++) {
      const ratio = i / gridCount
      const y = paddingTop + ratio * chartHeight
      const value = Math.round((1 - ratio) * maxValue)

      ctx.setLineDash([3, 4])
      ctx.strokeStyle = '#E8EDF3'
      ctx.lineWidth = 1
      ctx.beginPath()
      ctx.moveTo(paddingLeft, y)
      ctx.lineTo(width - paddingRight, y)
      ctx.stroke()
      ctx.setLineDash([])

      ctx.fillStyle = '#98A2B3'
      ctx.font = this.font(Math.max(10, Math.round(10 * textScale)), 'sans-serif')
      ctx.textAlign = 'right'
      ctx.textBaseline = 'middle'
      ctx.fillText(AmountUtil.shortFormat(value), paddingLeft - Math.round(6 * scale), y)
    }

    this.drawLegend(paddingLeft, Math.round(14 * scale), width)

    const slotWidth = chartWidth / this.data.length
    const barWidth = Math.min(Math.round(14 * scale), slotWidth * 0.32)
    const barGap = Math.max(Math.round(4 * scale), barWidth * 0.45)
    const axisBottom = height - paddingBottom

    for (let i = 0; i < this.data.length; i++) {
      const stat = this.data[i]
      const centerX = paddingLeft + i * slotWidth + slotWidth / 2

      const incomeHeight = maxValue > 0 ? chartHeight * (stat.income / maxValue) : 0
      if (incomeHeight > 0) {
        this.drawRoundedRect(
          centerX - barGap / 2 - barWidth,
          axisBottom - incomeHeight,
          barWidth,
          incomeHeight,
          Math.max(4, Math.round(4 * scale)),
          this.incomeColor
        )
      }

      const expenseHeight = maxValue > 0 ? chartHeight * (stat.expense / maxValue) : 0
      if (expenseHeight > 0) {
        this.drawRoundedRect(
          centerX + barGap / 2,
          axisBottom - expenseHeight,
          barWidth,
          expenseHeight,
          Math.max(4, Math.round(4 * scale)),
          this.expenseColor
        )
      }

      ctx.fillStyle = '#7B8794'
      ctx.font = this.font(Math.max(10, Math.round(10 * textScale)), 'sans-serif')
      ctx.textAlign = 'center'
      ctx.textBaseline = 'top'
      ctx.fillText(this.formatMonth(stat.month), centerX, axisBottom + Math.round(4 * scale))
    }
  }

  build() {
    Canvas(this.context)
      .width('100%')
      .height(320)
      .onReady(() => {
        this.drawChart()
      })
  }
}
