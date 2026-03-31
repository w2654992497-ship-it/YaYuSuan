import { CategoryStat } from '../model/StatResult'
import { AmountUtil } from '../utils/AmountUtil'

@Component
export struct PieChart {
  @Watch('redraw')
  @Prop data: CategoryStat[] = []

  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)

  redraw(): void {
    this.drawPie()
  }

  private drawPie(): void {
    const ctx = this.context
    const width = ctx.width
    const height = ctx.height

    ctx.clearRect(0, 0, width, height)

    if (!this.data || this.data.length === 0) {
      // Draw empty state
      const cx = width / 2
      const cy = height / 2
      const r = Math.min(width, height) * 0.4
      ctx.beginPath()
      ctx.arc(cx, cy, r, 0, 2 * Math.PI)
      ctx.fillStyle = '#E0E0E0'
      ctx.fill()

      // Inner hole
      ctx.beginPath()
      ctx.arc(cx, cy, r * 0.55, 0, 2 * Math.PI)
      ctx.fillStyle = '#FFFFFF'
      ctx.fill()

      // No data text
      ctx.fillStyle = '#757575'
      ctx.font = '14px sans-serif'
      ctx.textAlign = 'center'
      ctx.textBaseline = 'middle'
      ctx.fillText('暂无数据', cx, cy)
      return
    }

    const cx = width / 2
    const cy = height / 2
    const outerR = Math.min(width, height) * 0.4
    const innerR = outerR * 0.55
    const gap = 0.02

    let startAngle = -Math.PI / 2
    const total = this.data.reduce((sum, s) => sum + s.total, 0)

    for (const stat of this.data) {
      if (stat.total <= 0) {
        continue
      }
      const sliceAngle = (stat.total / total) * 2 * Math.PI - gap

      ctx.beginPath()
      ctx.moveTo(cx + innerR * Math.cos(startAngle + gap / 2), cy + innerR * Math.sin(startAngle + gap / 2))
      ctx.arc(cx, cy, outerR, startAngle + gap / 2, startAngle + sliceAngle + gap / 2)
      ctx.arc(cx, cy, innerR, startAngle + sliceAngle + gap / 2, startAngle + gap / 2, true)
      ctx.closePath()
      ctx.fillStyle = stat.color
      ctx.fill()

      startAngle += sliceAngle + gap
    }

    // Draw inner white hole
    ctx.beginPath()
    ctx.arc(cx, cy, innerR, 0, 2 * Math.PI)
    ctx.fillStyle = '#FFFFFF'
    ctx.fill()

    // Center text: total amount
    ctx.fillStyle = '#212121'
    ctx.font = 'bold 16px sans-serif'
    ctx.textAlign = 'center'
    ctx.textBaseline = 'middle'
    ctx.fillText(`¥${AmountUtil.fen2Display(total)}`, cx, cy - 10)

    // Center label
    ctx.fillStyle = '#757575'
    ctx.font = '12px sans-serif'
    ctx.fillText('总支出', cx, cy + 14)
  }

  build() {
    Canvas(this.context)
      .width('100%')
      .height(260)
      .onReady(() => {
        this.drawPie()
      })
  }
}
