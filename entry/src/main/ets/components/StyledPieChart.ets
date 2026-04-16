import { CategoryStat } from '../model/StatResult'
import { AmountUtil } from '../utils/AmountUtil'

@Component
export struct StyledPieChart {
  @Watch('redraw')
  @Prop data: CategoryStat[] = []

  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  private readonly fallbackColors: string[] = ['#457B9D', '#1D3557', '#8ECAE6', '#76B041', '#EF476F', '#FFD166']
  private readonly textMultiplier: number = 2

  redraw(): void {
    this.drawChart()
  }

  private pickColor(stat: CategoryStat, index: number): string {
    if (stat.color && stat.color.length > 0) {
      return stat.color
    }
    return this.fallbackColors[index % this.fallbackColors.length]
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

  private drawEmpty(width: number, height: number): void {
    const ctx = this.context
    const cx = width / 2
    const cy = height / 2 + 4
    const radius = Math.min(width, height) * 0.25
    const layoutScale = this.scaleFactor(width)
    const textScale = this.textScaleFactor(width)

    ctx.strokeStyle = '#E6ECF2'
    ctx.lineWidth = Math.max(16, 16 * layoutScale)
    ctx.beginPath()
    ctx.arc(cx, cy, radius, 0, Math.PI * 2)
    ctx.stroke()

    ctx.fillStyle = '#98A2B3'
    ctx.font = this.font(Math.round(14 * textScale), 'sans-serif')
    ctx.textAlign = 'center'
    ctx.textBaseline = 'middle'
    ctx.fillText('暂无数据', cx, cy)
  }

  private drawChart(): void {
    const ctx = this.context
    const width = ctx.width
    const height = ctx.height

    ctx.clearRect(0, 0, width, height)

    const valid: CategoryStat[] = this.data.filter((item: CategoryStat) => item.total > 0)
    if (valid.length === 0) {
      this.drawEmpty(width, height)
      return
    }

    let total = 0
    for (const item of valid) {
      total += item.total
    }
    if (total <= 0) {
      this.drawEmpty(width, height)
      return
    }

    const cx = width / 2
    const cy = height / 2 + 4
    const radius = Math.min(width, height) * 0.27
    const ringWidth = Math.max(20, radius * 0.34)
    const gap = Math.PI / 180
    const textScale = this.textScaleFactor(width)

    ctx.strokeStyle = '#EDF2F7'
    ctx.lineWidth = ringWidth
    ctx.lineCap = 'round'
    ctx.beginPath()
    ctx.arc(cx, cy, radius, 0, Math.PI * 2)
    ctx.stroke()

    let start = -Math.PI / 2
    for (let i = 0; i < valid.length; i++) {
      const item = valid[i]
      const ratio = item.total / total
      let sweep = ratio * Math.PI * 2 - gap
      if (sweep <= 0) {
        sweep = 0.01
      }
      ctx.beginPath()
      ctx.strokeStyle = this.pickColor(item, i)
      ctx.lineWidth = ringWidth
      ctx.lineCap = 'round'
      ctx.arc(cx, cy, radius, start, start + sweep)
      ctx.stroke()
      start += sweep + gap
    }

    ctx.fillStyle = '#98A2B3'
    ctx.font = this.font(Math.round(14 * textScale), 'sans-serif')
    ctx.textAlign = 'center'
    ctx.textBaseline = 'middle'
    ctx.fillText('总支出', cx, cy - Math.round(28 * textScale / 2))

    ctx.fillStyle = '#2B2D42'
    ctx.font = this.font(Math.round(30 * textScale / 2), 'sans-serif', 'bold')
    ctx.fillText(`¥${AmountUtil.fen2Display(total)}`, cx, cy + 2)

    ctx.fillStyle = '#98A2B3'
    ctx.font = this.font(Math.round(13 * textScale), 'sans-serif')
    ctx.fillText(`${valid.length} 类分类`, cx, cy + Math.round(26 * textScale / 2))
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
