import { MonthStat } from '../model/StatResult'
import { AmountUtil } from '../utils/AmountUtil'

@Component
export struct BarChart {
  @Watch('redraw')
  @Prop data: MonthStat[] = []

  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)

  redraw(): void {
    this.drawBar()
  }

  private drawBar(): void {
    const ctx = this.context
    const width = ctx.width
    const height = ctx.height

    ctx.clearRect(0, 0, width, height)

    const paddingLeft = 50
    const paddingBottom = 30
    const paddingTop = 20
    const paddingRight = 10

    const chartWidth = width - paddingLeft - paddingRight
    const chartHeight = height - paddingTop - paddingBottom

    // Draw axes
    ctx.strokeStyle = '#E0E0E0'
    ctx.lineWidth = 1
    ctx.beginPath()
    ctx.moveTo(paddingLeft, paddingTop)
    ctx.lineTo(paddingLeft, height - paddingBottom)
    ctx.lineTo(width - paddingRight, height - paddingBottom)
    ctx.stroke()

    if (!this.data || this.data.length === 0) {
      // Empty state
      ctx.fillStyle = '#9E9E9E'
      ctx.font = '14px sans-serif'
      ctx.textAlign = 'center'
      ctx.textBaseline = 'middle'
      ctx.fillText('暂无数据', width / 2, height / 2)
      return
    }

    // Find max value
    let maxVal = 0
    for (const stat of this.data) {
      if (stat.income > maxVal) {
        maxVal = stat.income
      }
      if (stat.expense > maxVal) {
        maxVal = stat.expense
      }
    }
    if (maxVal === 0) {
      maxVal = 100
    }

    // Y axis gridlines and labels
    const gridCount = 5
    for (let i = 0; i <= gridCount; i++) {
      const y = height - paddingBottom - (i / gridCount) * chartHeight
      const value = (i / gridCount) * maxVal

      // Dashed gridline
      ctx.setLineDash([4, 4])
      ctx.strokeStyle = '#E0E0E0'
      ctx.lineWidth = 1
      ctx.beginPath()
      ctx.moveTo(paddingLeft, y)
      ctx.lineTo(width - paddingRight, y)
      ctx.stroke()
      ctx.setLineDash([])

      // Y axis label
      ctx.fillStyle = '#9E9E9E'
      ctx.font = '10px sans-serif'
      ctx.textAlign = 'right'
      ctx.textBaseline = 'middle'
      ctx.fillText(AmountUtil.shortFormat(value), paddingLeft - 4, y)
    }

    // Draw bars
    const n = this.data.length
    const slotWidth = chartWidth / n

    for (let i = 0; i < n; i++) {
      const stat = this.data[i]
      const slotX = paddingLeft + i * slotWidth
      const barWidth = slotWidth * 0.35
      const gap = slotWidth * 0.1

      const centerX = slotX + slotWidth / 2
      const incomeX = centerX - gap / 2 - barWidth
      const expenseX = centerX + gap / 2

      // Income bar (blue)
      if (stat.income > 0) {
        const incomeH = (stat.income / maxVal) * chartHeight
        ctx.fillStyle = '#2196F3'
        ctx.fillRect(incomeX, height - paddingBottom - incomeH, barWidth, incomeH)
      }

      // Expense bar (red)
      if (stat.expense > 0) {
        const expenseH = (stat.expense / maxVal) * chartHeight
        ctx.fillStyle = '#F44336'
        ctx.fillRect(expenseX, height - paddingBottom - expenseH, barWidth, expenseH)
      }

      // X axis label
      const monthParts = stat.month.split('-')
      const monthLabel = `${parseInt(monthParts[1], 10)}月`
      ctx.fillStyle = '#9E9E9E'
      ctx.font = '10px sans-serif'
      ctx.textAlign = 'center'
      ctx.textBaseline = 'top'
      ctx.fillText(monthLabel, centerX, height - paddingBottom + 4)
    }

    // Legend at the bottom
    const legendY = height - 8
    const legendStartX = paddingLeft + chartWidth / 2 - 70

    // Income legend
    ctx.fillStyle = '#2196F3'
    ctx.fillRect(legendStartX, legendY - 8, 12, 12)
    ctx.fillStyle = '#212121'
    ctx.font = '11px sans-serif'
    ctx.textAlign = 'left'
    ctx.textBaseline = 'middle'
    ctx.fillText('收入', legendStartX + 16, legendY - 2)

    // Expense legend
    ctx.fillStyle = '#F44336'
    ctx.fillRect(legendStartX + 60, legendY - 8, 12, 12)
    ctx.fillStyle = '#212121'
    ctx.fillText('支出', legendStartX + 76, legendY - 2)
  }

  build() {
    Canvas(this.context)
      .width('100%')
      .height(260)
      .onReady(() => {
        this.drawBar()
      })
  }
}
