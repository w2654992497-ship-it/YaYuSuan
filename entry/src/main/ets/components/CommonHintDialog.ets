export type HintIconType = 'success' | 'error' | 'info'

/**
 * 操作结果提示弹窗
 * success / error：Canvas 路径描绘动画（对号 / 叉号）
 * info：静态 "!" 文字
 */
@CustomDialog
export struct CommonHintDialog {
  controller?: CustomDialogController
  @Prop message: string = ''
  @Prop iconType: HintIconType = 'success'

  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  private animTimer: number = -1

  private getIconColor(): string {
    if (this.iconType === 'success') return '#4CAF50'
    if (this.iconType === 'error') return '#F44336'
    return '#FF9800'
  }

  // ── 对号路径动画 ──────────────────────────────────────
  private drawCheck(progress: number): void {
    const c = this.ctx
    const w = c.width
    const h = c.height
    c.clearRect(0, 0, w, h)
    if (progress <= 0) { return }

    const cx = w / 2
    const cy = h / 2
    const r = Math.min(w, h) * 0.33

    // P0 → P1 → P2（左侧 → 折点 → 右上）
    const x0 = cx - r * 0.55,  y0 = cy + r * 0.08
    const x1 = cx - r * 0.04,  y1 = cy + r * 0.50
    const x2 = cx + r * 0.60,  y2 = cy - r * 0.42

    const len1 = Math.sqrt(Math.pow(x1 - x0, 2) + Math.pow(y1 - y0, 2))
    const len2 = Math.sqrt(Math.pow(x2 - x1, 2) + Math.pow(y2 - y1, 2))
    const total = len1 + len2

    c.beginPath()
    c.moveTo(x0, y0)
    c.lineTo(x1, y1)
    c.lineTo(x2, y2)
    c.strokeStyle = '#FFFFFF'
    c.lineWidth = w * 0.075
    c.lineCap = 'round'
    c.lineJoin = 'round'
    // offset = total*(1-p) 时：dashOffset 把实线段推到路径末尾之外 → 空白
    // offset 逐渐减为 0 → 实线段从头开始显现（描绘效果）
    c.setLineDash([total, total])
    c.lineDashOffset = total * (1 - progress)
    c.stroke()
    c.setLineDash([])
  }

  // ── 叉号路径动画（两笔依次描绘） ──────────────────────
  private drawCross(progress: number): void {
    const c = this.ctx
    const w = c.width
    const h = c.height
    c.clearRect(0, 0, w, h)
    if (progress <= 0) { return }

    const cx = w / 2
    const cy = h / 2
    const r = Math.min(w, h) * 0.29
    const diagLen = r * 2 * Math.sqrt(2)

    c.strokeStyle = '#FFFFFF'
    c.lineWidth = w * 0.075
    c.lineCap = 'round'

    // 第一笔 \ ：progress 0 → 0.5
    const p1 = Math.min(progress * 2, 1)
    c.beginPath()
    c.moveTo(cx - r, cy - r)
    c.lineTo(cx + r, cy + r)
    c.setLineDash([diagLen, diagLen])
    c.lineDashOffset = diagLen * (1 - p1)
    c.stroke()

    // 第二笔 / ：progress 0.5 → 1
    if (progress > 0.5) {
      const p2 = (progress - 0.5) * 2
      c.beginPath()
      c.moveTo(cx + r, cy - r)
      c.lineTo(cx - r, cy + r)
      c.setLineDash([diagLen, diagLen])
      c.lineDashOffset = diagLen * (1 - p2)
      c.stroke()
    }
    c.setLineDash([])
  }

  // ── 启动帧动画 ────────────────────────────────────────
  private startAnimation(): void {
    if (this.animTimer !== -1) {
      clearInterval(this.animTimer)
    }
    const duration = 460
    const startTime = Date.now()
    this.animTimer = setInterval(() => {
      const t = Math.min((Date.now() - startTime) / duration, 1.0)
      // ease-out cubic：结尾减速，手写感更强
      const eased = 1 - Math.pow(1 - t, 3)
      if (this.iconType === 'success') {
        this.drawCheck(eased)
      } else if (this.iconType === 'error') {
        this.drawCross(eased)
      }
      if (t >= 1) {
        clearInterval(this.animTimer)
        this.animTimer = -1
      }
    }, 16)
  }

  aboutToDisappear(): void {
    if (this.animTimer !== -1) {
      clearInterval(this.animTimer)
      this.animTimer = -1
    }
  }

  build() {
    Column() {
      // 图标圆圈
      Column() {
        if (this.iconType === 'info') {
          Text('!')
            .fontSize(26)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Bold)
        } else {
          Canvas(this.ctx)
            .width(54)
            .height(54)
            .backgroundColor(Color.Transparent)
            .onReady(() => {
              this.startAnimation()
            })
        }
      }
      .width(54)
      .height(54)
      .borderRadius(27)
      .backgroundColor(this.getIconColor())
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .margin({ bottom: 14 })

      Text(this.message)
        .fontSize(15)
        .fontColor('#FFFFFF')
        .textAlign(TextAlign.Center)
        .maxLines(2)
    }
    .padding({ left: 32, right: 32, top: 24, bottom: 24 })
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#CC333333')
    .borderRadius(14)
  }
}
