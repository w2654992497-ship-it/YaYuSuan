import { BillDao } from '../database/BillDao'
import { CategoryStat } from '../model/StatResult'
import { FilterOptions } from '../model/FilterOptions'
import { SearchFilterOptions } from '../model/SearchFilterOptions'
import { Bill } from '../model/Bill'
import { getCategoryColor, getCategoryInfo } from '../model/Category'
import { WaterPageBg } from '../components/WaterPageBg'
import { AmountUtil } from '../utils/AmountUtil'
import { DateUtil } from '../utils/DateUtil'
import { LogUtils } from '../utils/LogUtils'
import { BudgetService } from '../services/BudgetService'
import { BudgetOverview, createEmptyBudgetOverview } from '../model/BudgetRule'

interface TrendBarData {
  label: string
  displayLabel?: string
  amount: number
  active: boolean
}

interface StatDateRange {
  startDate: string
  endDate: string
}

@Component
struct StatisticsBudgetMiniCard {
  @Prop title: string
  @Prop iconColor: ResourceColor
  @Prop totalFen: number = 0
  @Prop usedFen: number = 0
  @Prop remainFen: number = 0
  @Prop percent: number = 0
  @Prop activeRuleCount: number = 0
  @Prop categoryBudgetFen: number = 0

  private hasBudget(): boolean {
    return this.totalFen > 0 || this.categoryBudgetFen > 0 || this.activeRuleCount > 0
  }

  private displayTotalFen(): number {
    if (this.totalFen > 0) {
      return this.totalFen
    }
    return this.categoryBudgetFen
  }

  private amountText(value: number): string {
    if (value <= 0) {
      return '--'
    }
    return '¥' + AmountUtil.fen2Display(value)
  }

  private titleAmountText(): string {
    if (!this.hasBudget()) {
      return '未设置'
    }
    return this.amountText(this.displayTotalFen())
  }

  private remainText(): string {
    if (!this.hasBudget()) {
      return '--'
    }
    return this.amountText(this.remainFen)
  }

  private progressWidth(): string {
    if (!this.hasBudget() || this.percent <= 0) {
      return '0%'
    }
    const percent = Math.max(4, Math.min(100, this.percent))
    return percent.toString() + '%'
  }

  build() {
    Column() {
      Row() {
        Row() {
          Image($rawfile('icon_calendar.svg'))
            .width(18)
            .height(18)
            .fillColor($r('app.color.color_white'))
        }
        .width(26)
        .height(26)
        .borderRadius(13)
        .backgroundColor(this.iconColor)
        .justifyContent(FlexAlign.Center)
        .margin({ right: 5 })

        Text(this.title)
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_deep'))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.titleAmountText())
        .fontSize(this.hasBudget() ? 14 : 15)
        .fontWeight(FontWeight.Bolder)
        .fontColor(this.hasBudget() ? $r('app.color.color_text_deep') : $r('app.color.color_text_secondary'))
        .width('100%')
        .margin({ top: 12 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Row() {
        Text('已用')
          .fontSize(11)
          .fontColor($r('app.color.color_text_secondary'))
        Blank()
        Text(this.amountText(this.usedFen))
          .fontSize(11)
          .fontColor($r('app.color.color_text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .margin({ top: 10 })

      Row() {
        Text('剩余')
          .fontSize(11)
          .fontColor($r('app.color.color_text_secondary'))
        Blank()
        Text(this.remainText())
          .fontSize(11)
          .fontColor(this.hasBudget() ? this.iconColor : $r('app.color.color_text_secondary'))
          .fontWeight(this.hasBudget() ? FontWeight.Bold : FontWeight.Regular)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .margin({ top: 6 })

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(8)
          .borderRadius(4)
          .backgroundColor('#EAF1F2')
        Row()
          .width(this.progressWidth())
          .height(8)
          .borderRadius(4)
          .backgroundColor(this.iconColor)
      }
      .width('100%')
      .margin({ top: 10 })

      Text(this.hasBudget() ? this.percent.toString() + '%' : '--')
        .fontSize(11)
        .fontColor($r('app.color.color_text_secondary'))
        .width('100%')
        .textAlign(TextAlign.End)
        .margin({ top: 4 })
    }
    .layoutWeight(1)
    .height(142)
    .padding({ left: 10, right: 10, top: 12, bottom: 10 })
    .backgroundColor($r('app.color.color_surface'))
    .borderRadius(16)
    .border({ width: 1, color: $r('app.color.color_divider') })
  }
}

@Component
export struct ExpenseRankingAllPage {
  @Consume('appNavStack') navStack: NavPathStack
  @State currentMonth: string = DateUtil.currentMonth()
  @State rankingStats: CategoryStat[] = []
  @State expenseTotal: number = 0
  @StorageProp('statusBarHeight') sbHeight: number = 0

  aboutToAppear(): void {
    const month = AppStorage.get<string>('statisticsRankingMonth')
    if (month !== undefined && month.length > 0) {
      this.currentMonth = month
    }
    this.loadRanking()
  }

  private async loadRanking(): Promise<void> {
    try {
      const filter: FilterOptions = { month: this.currentMonth, type: 'all', category: '' }
      const bills = await BillDao.getInstance().queryByFilter(filter)
      this.rankingStats = this.buildCategoryStats(bills)
      this.expenseTotal = this.totalAmount(this.rankingStats)
    } catch (err) {
      LogUtils.error('Statistics', 'loadRanking error: %{public}s', JSON.stringify(err))
    }
  }

  private isExpenseBill(bill: Bill): boolean {
    return bill.type !== 'income'
  }

  private buildCategoryStats(bills: Bill[]): CategoryStat[] {
    const names: string[] = []
    const totals: number[] = []
    let grandTotal = 0

    for (let i = 0; i < bills.length; i++) {
      const bill = bills[i]
      if (!this.isExpenseBill(bill)) {
        continue
      }
      grandTotal += bill.amount
      const categoryName = bill.category.length > 0 ? bill.category : '其他'
      let foundIndex = -1
      for (let j = 0; j < names.length; j++) {
        if (names[j] === categoryName) {
          foundIndex = j
          break
        }
      }
      if (foundIndex >= 0) {
        totals[foundIndex] += bill.amount
      } else {
        names.push(categoryName)
        totals.push(bill.amount)
      }
    }

    const stats: CategoryStat[] = []
    for (let i = 0; i < names.length; i++) {
      stats.push({
        category: names[i],
        total: totals[i],
        percent: grandTotal > 0 ? Math.round(totals[i] / grandTotal * 100) : 0,
        color: getCategoryColor(names[i])
      })
    }
    stats.sort((a: CategoryStat, b: CategoryStat) => {
      return b.total - a.total
    })
    return stats
  }

  private totalAmount(stats: CategoryStat[]): number {
    let total = 0
    for (let i = 0; i < stats.length; i++) {
      total += stats[i].total
    }
    return total
  }

  private rankingWidth(stat: CategoryStat): string {
    if (this.expenseTotal <= 0 || stat.total <= 0) {
      return '0%'
    }
    const percent = Math.floor(stat.total / this.expenseTotal * 100)
    return `${Math.max(4, Math.min(100, percent))}%`
  }

  @Builder
  RankingRow(stat: CategoryStat, index: number) {
    Row() {
      Text((index + 1).toString())
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.color_text_secondary'))
        .width(26)
      Row() {
        Image($rawfile(getCategoryInfo(stat.category).icon + '.svg'))
          .width(20)
          .height(20)
          .fillColor($r('app.color.color_white'))
      }
      .width(36)
      .height(36)
      .borderRadius(18)
      .backgroundColor(stat.color)
      .justifyContent(FlexAlign.Center)
      .margin({ right: 10 })
      Column() {
        Row() {
          Text(stat.category)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.color_text_deep'))
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`¥${AmountUtil.fen2Display(stat.total)}`)
            .fontSize(13)
            .fontColor($r('app.color.color_text_deep'))
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Stack({ alignContent: Alignment.Start }) {
          Row()
            .width('100%')
            .height(8)
            .borderRadius(4)
            .backgroundColor($r('app.color.color_track'))
          Row()
            .width(this.rankingWidth(stat))
            .height(8)
            .borderRadius(4)
            .backgroundColor(stat.color)
        }
        .width('100%')
        .margin({ top: 8 })

        Text(`${stat.percent}%`)
          .fontSize(11)
          .fontColor($r('app.color.color_text_secondary'))
          .margin({ top: 5 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(18)
    .border({ width: 1, color: $r('app.color.color_divider') })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      WaterPageBg()

      Column() {
        Row() {
          Row() {
            Image($rawfile('icon_chevron_left.svg'))
              .width(18)
              .height(18)
              .fillColor($r('app.color.color_text_deep'))
          }
          .width(36)
          .height(36)
          .borderRadius(18)
          .backgroundColor($r('app.color.color_card_overlay'))
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            if (this.navStack) {
              this.navStack.pop()
            }
          })

          Text('支出排行榜')
            .fontSize(22)
            .fontWeight(FontWeight.Bolder)
            .fontColor($r('app.color.color_text_deep'))
            .margin({ left: 14 })
          Blank()
          Text(DateUtil.formatMonthDisplay(this.currentMonth))
            .fontSize(13)
            .fontColor($r('app.color.color_text_secondary'))
        }
        .width('100%')
        .height(this.sbHeight + 72)
        .padding({ left: 18, right: 18, top: this.sbHeight + 18 })
        .alignItems(VerticalAlign.Center)

        Row() {
          Text('总支出')
            .fontSize(13)
            .fontColor($r('app.color.color_text_secondary'))
          Blank()
          Text(`¥${AmountUtil.fen2Display(this.expenseTotal)}`)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.color_text_deep'))
        }
        .width('calc(100% - 36vp)')
        .height(58)
        .padding({ left: 16, right: 16 })
        .backgroundColor($r('app.color.color_card_overlay'))
        .borderRadius(20)
        .border({ width: 1, color: $r('app.color.color_divider') })
        .margin({ left: 18, right: 18, bottom: 10 })

        Scroll() {
          Column({ space: 10 }) {
            if (this.rankingStats.length === 0) {
              Column() {
                Text('暂无支出记录')
                  .fontSize(15)
                  .fontColor($r('app.color.color_text_secondary'))
              }
              .width('100%')
              .height(160)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
            } else {
              ForEach(this.rankingStats, (stat: CategoryStat, index: number) => {
                this.RankingRow(stat, index)
              }, (stat: CategoryStat, index: number) => `${stat.category}_${stat.total}_${index}`)
            }
          }
          .width('100%')
          .padding({ left: 18, right: 18, bottom: 24 })
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}

@Component
struct DonutRingChart {
  @Watch('redraw')
  @Prop data: CategoryStat[] = []
  @Watch('redraw')
  @Prop total: number = 0

  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  private readonly trackColor: string = '#E8EEF8'
  private readonly textColor: string = '#10233F'
  private readonly mutedColor: string = '#7A8AA0'

  redraw(): void {
    this.draw()
  }

  private drawEmpty(width: number, height: number): void {
    const ctx = this.context
    const cx = width / 2
    const cy = height / 2
    const radius = Math.min(width, height) * 0.38
    ctx.clearRect(0, 0, width, height)
    ctx.beginPath()
    ctx.strokeStyle = this.trackColor
    ctx.lineWidth = 18
    ctx.arc(cx, cy, radius, 0, Math.PI * 2)
    ctx.stroke()
  }

  private draw(): void {
    const ctx = this.context
    const width = ctx.width
    const height = ctx.height
    if (width <= 0 || height <= 0) {
      return
    }
    if (this.total <= 0 || this.data.length === 0) {
      this.drawEmpty(width, height)
      return
    }

    const cx = width / 2
    const cy = height / 2
    const radius = Math.min(width, height) * 0.38
    const ringWidth = Math.max(22, radius * 0.32)
    const gap = Math.PI / 180 * 1.8

    ctx.clearRect(0, 0, width, height)
    ctx.lineCap = 'round'
    ctx.strokeStyle = this.trackColor
    ctx.lineWidth = ringWidth
    ctx.beginPath()
    ctx.arc(cx, cy, radius, 0, Math.PI * 2)
    ctx.stroke()

    let start = -Math.PI / 2
    for (let i = 0; i < this.data.length; i++) {
      const stat = this.data[i]
      if (stat.total <= 0) {
        continue
      }
      let sweep = stat.total / this.total * Math.PI * 2 - gap
      if (sweep < 0.02) {
        sweep = 0.02
      }
      ctx.strokeStyle = stat.color
      ctx.lineWidth = ringWidth
      ctx.beginPath()
      ctx.arc(cx, cy, radius, start, start + sweep)
      ctx.stroke()
      start += sweep + gap
    }

    ctx.fillStyle = this.textColor
  }

  build() {
    Canvas(this.context)
      .width('100%')
      .height('100%')
      .onReady(() => {
        this.draw()
      })
  }
}

@Component
struct SummaryExpenseSparkline {
  @Watch('redraw')
  @Prop currentAmount: number = 0
  @Watch('redraw')
  @Prop lastAmount: number = 0

  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  private readonly lineColor: string = '#F36B86'
  private readonly fillColor: string = '#22EF5B73'
  private readonly softLineColor: string = '#88F36B86'

  redraw(): void {
    this.draw()
  }

  private pointValue(index: number): number {
    const current = this.currentAmount > 0 ? this.currentAmount : 1
    const previous = this.lastAmount > 0 ? this.lastAmount : current * 0.18
    if (index === 0) {
      return previous * 0.34
    }
    if (index === 1) {
      return previous * 0.40
    }
    if (index === 2) {
      return previous * 0.36
    }
    if (index === 3) {
      return previous * 0.52
    }
    if (index === 4) {
      return previous * 0.50
    }
    if (index === 5) {
      return current * 0.62
    }
    if (index === 6) {
      return current * 0.72
    }
    return current
  }

  private maxValue(): number {
    let value = this.currentAmount > this.lastAmount ? this.currentAmount : this.lastAmount
    if (value <= 0) {
      value = 100
    }
    return value
  }

  private xAt(index: number, left: number, width: number): number {
    return left + width / 7 * index
  }

  private yAt(index: number, top: number, height: number): number {
    const ratio = this.pointValue(index) / this.maxValue()
    return top + height - Math.max(0.08, Math.min(1, ratio)) * height
  }

  private drawSmoothPath(left: number, top: number, chartWidth: number, chartHeight: number): void {
    const ctx = this.context
    ctx.beginPath()
    ctx.moveTo(this.xAt(0, left, chartWidth), this.yAt(0, top, chartHeight))
    for (let i = 1; i < 8; i++) {
      const prevX = this.xAt(i - 1, left, chartWidth)
      const prevY = this.yAt(i - 1, top, chartHeight)
      const x = this.xAt(i, left, chartWidth)
      const y = this.yAt(i, top, chartHeight)
      const cx = (prevX + x) / 2
      ctx.quadraticCurveTo(prevX, prevY, cx, (prevY + y) / 2)
      ctx.quadraticCurveTo(cx, (prevY + y) / 2, x, y)
    }
  }

  private draw(): void {
    const ctx = this.context
    const width = ctx.width
    const height = ctx.height
    ctx.clearRect(0, 0, width, height)
    if (width <= 0 || height <= 0) {
      return
    }

    const left = 4
    const right = 4
    const top = 6
    const bottom = 6
    const chartWidth = width - left - right
    const chartHeight = height - top - bottom
    const bottomY = top + chartHeight

    this.drawSmoothPath(left, top, chartWidth, chartHeight)
    ctx.lineTo(width - right, bottomY)
    ctx.lineTo(left, bottomY)
    ctx.closePath()
    ctx.fillStyle = this.fillColor
    ctx.fill()

    this.drawSmoothPath(left, top, chartWidth, chartHeight)
    ctx.strokeStyle = this.softLineColor
    ctx.lineWidth = 2
    ctx.lineCap = 'round'
    ctx.lineJoin = 'round'
    ctx.stroke()

    const endX = this.xAt(7, left, chartWidth)
    const endY = this.yAt(7, top, chartHeight)
    ctx.beginPath()
    ctx.arc(endX, endY, 4, 0, Math.PI * 2)
    ctx.fillStyle = this.lineColor
    ctx.fill()
  }

  build() {
    Canvas(this.context)
      .width('100%')
      .height('100%')
      .onReady(() => {
        this.draw()
      })
  }
}

@Component
struct ExpenseTrendCanvas {
  @Watch('redraw')
  @Prop data: TrendBarData[] = []
  @Watch('redraw')
  @Prop axisMax: number = 3000
  @Watch('redraw')
  @Prop statMode: string = 'month'
  @Watch('redraw')
  @Prop selectedLabel: string = ''
  @Watch('redraw')
  @Prop emptyText: string = '暂无支出数据'
  onGestureActive: (active: boolean) => void = (active: boolean): void => {}
  onSelect: (label: string, amount: number) => void = (label: string, amount: number): void => {}

  @State viewScale: number = 1
  @State viewOffsetX: number = 0
  @State selectedIndex: number = -1
  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  private gestureStartScale: number = 1
  private gestureStartOffsetX: number = 0
  private readonly primaryColor: string = '#21A7A8'
  private readonly barColor: string = '#A9DEDE'
  private readonly emptyColor: string = '#EAF6F5'
  private readonly gridColor: string = '#EAF1F2'
  private readonly textColor: string = '#7A8AA0'
  private readonly deepTextColor: string = '#10233F'

  redraw(): void {
    this.draw()
  }

  private font(size: number, family: string, weight: string = ''): string {
    return weight.length > 0 ? weight + ' ' + size.toString() + 'px ' + family : size.toString() + 'px ' + family
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

  private displayLabel(item: TrendBarData): string {
    if (item.displayLabel !== undefined) {
      return item.displayLabel
    }
    return item.label
  }

  private axisValue(index: number): number {
    return Math.round(this.axisMax / 3 * (3 - index))
  }

  private activeIndex(): number {
    if (this.selectedLabel.length > 0) {
      for (let i = 0; i < this.data.length; i++) {
        if (this.data[i].label === this.selectedLabel) {
          return i
        }
      }
    }
    if (this.selectedIndex >= 0 && this.selectedIndex < this.data.length) {
      return this.selectedIndex
    }
    for (let i = 0; i < this.data.length; i++) {
      if (this.data[i].active) {
        return i
      }
    }
    return -1
  }

  private labelFontSize(): number {
    if (this.statMode === 'year') {
      return 30
    }
    if (this.data.length <= 7) {
      return 30
    }
    if (this.data.length <= 12) {
      return 26
    }
    return 22
  }

  private barPaintWidth(slot: number): number {
    if (this.statMode === 'year') {
      return Math.min(20, slot * 0.52)
    }
    if (this.data.length <= 7) {
      return Math.min(20, slot * 0.36)
    }
    if (this.data.length <= 12) {
      return Math.min(15, slot * 0.42)
    }
    return Math.min(8, slot * 0.5)
  }

  private clampScale(value: number): number {
    if (value < 1) {
      return 1
    }
    if (value > 2.6) {
      return 2.6
    }
    return value
  }

  private chartWidth(width: number): number {
    const left = 88
    const right = 20
    return Math.max(1, width - left - right)
  }

  private clampOffset(width: number, offset: number): number {
    const chartWidth = this.chartWidth(width)
    const contentWidth = chartWidth * this.viewScale
    if (contentWidth <= chartWidth) {
      return 0
    }
    const minOffset = chartWidth - contentWidth
    if (offset < minOffset) {
      return minOffset
    }
    if (offset > 0) {
      return 0
    }
    return offset
  }

  private updateScale(nextScale: number): void {
    const width = this.context.width
    const oldScale = this.viewScale
    this.viewScale = this.clampScale(nextScale)
    if (this.viewScale <= 1.01) {
      this.viewScale = 1
      this.viewOffsetX = 0
    } else if (oldScale > 0) {
      const chartWidth = this.chartWidth(width)
      const centerX = chartWidth / 2
      const ratio = this.viewScale / oldScale
      const nextOffset = centerX - (centerX - this.viewOffsetX) * ratio
      this.viewOffsetX = this.clampOffset(width, nextOffset)
    }
    this.draw()
  }

  private updateOffset(nextOffset: number): void {
    const width = this.context.width
    this.viewOffsetX = this.clampOffset(width, nextOffset)
    this.draw()
  }

  private selectAt(x: number): void {
    if (this.data.length === 0) {
      return
    }
    const width = this.context.width
    const left = 88
    const right = 20
    const chartWidth = width - left - right
    if (chartWidth <= 0) {
      return
    }
    const slot = chartWidth * this.viewScale / this.data.length
    if (slot <= 0) {
      return
    }
    let index = Math.floor((x - left - this.viewOffsetX) / slot)
    if (index < 0) {
      index = 0
    }
    if (index >= this.data.length) {
      index = this.data.length - 1
    }
    this.selectedIndex = index
    const item = this.data[index]
    this.onSelect(item.label, item.amount)
    this.draw()
  }

  private draw(): void {
    const ctx = this.context
    const width = ctx.width
    const height = ctx.height
    ctx.clearRect(0, 0, width, height)
    if (width <= 0 || height <= 0) {
      return
    }

    const left = 88
    const right = 20
    const top = 22
    const bottom = 54
    const chartWidth = width - left - right
    const chartHeight = height - top - bottom
    const axisBottom = top + chartHeight
    const maxValue = this.axisMax > 0 ? this.axisMax : 3000

    for (let i = 0; i < 4; i++) {
      const y = top + chartHeight / 3 * i
      ctx.setLineDash([4, 4])
      ctx.strokeStyle = this.gridColor
      ctx.lineWidth = 1
      ctx.beginPath()
      ctx.moveTo(left, y)
      ctx.lineTo(width - right, y)
      ctx.stroke()
      ctx.setLineDash([])

      ctx.fillStyle = this.textColor
      ctx.font = this.font(26, 'sans-serif', 'bold')
      ctx.textAlign = 'left'
      ctx.textBaseline = 'middle'
      ctx.fillText(AmountUtil.shortFormat(this.axisValue(i)), 4, y)
    }

    if (this.data.length === 0) {
      ctx.fillStyle = this.textColor
      ctx.font = this.font(21, 'sans-serif')
      ctx.textAlign = 'center'
      ctx.textBaseline = 'middle'
      ctx.fillText(this.emptyText, width / 2, height / 2)
      return
    }

    const slot = chartWidth * this.viewScale / this.data.length
    const barWidth = this.barPaintWidth(slot)
    const active = this.activeIndex()

    if (active >= 0) {
      const activeCenterX = left + this.viewOffsetX + slot * active + slot / 2
      if (activeCenterX >= left && activeCenterX <= width - right) {
        const bandWidth = Math.min(Math.max(slot * 0.5, 18), 42)
        this.drawRoundedRect(activeCenterX - bandWidth / 2, top, bandWidth, chartHeight, bandWidth / 2, '#F2F7FF')
      }
    }

    for (let i = 0; i < this.data.length; i++) {
      const item = this.data[i]
      const centerX = left + this.viewOffsetX + slot * i + slot / 2
      if (centerX < left - 40 || centerX > width - right + 40) {
        continue
      }
      let barHeight = 8
      if (item.amount > 0) {
        barHeight = Math.max(18, Math.min(chartHeight, chartHeight * item.amount / maxValue))
      }
      const isSelected = i === active
      const color = isSelected ? this.primaryColor : item.amount > 0 ? this.barColor : this.emptyColor
      const drawWidth = isSelected ? Math.min(barWidth + 4, slot * 0.7) : barWidth
      this.drawRoundedRect(centerX - drawWidth / 2, axisBottom - barHeight, drawWidth, barHeight, drawWidth / 2, color)

      const label = this.displayLabel(item)
      if (label.length > 0) {
        ctx.fillStyle = isSelected ? this.primaryColor : this.textColor
        ctx.font = this.font(this.labelFontSize(), 'sans-serif', isSelected ? 'bold' : '')
        ctx.textAlign = 'center'
        ctx.textBaseline = 'top'
        ctx.fillText(label, centerX, axisBottom + 10)
      }
    }
  }

  build() {
    Canvas(this.context)
      .width('100%')
      .height('100%')
      .onReady(() => {
        this.draw()
      })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down && event.touches.length === 1) {
          const touch = event.touches[0]
          this.selectAt(touch.x)
        } else if (event.type === TouchType.Move && event.touches.length === 1) {
          const touch = event.touches[0]
          this.selectAt(touch.x)
        }
      })
      .gesture(
        GestureGroup(GestureMode.Parallel,
          PinchGesture({ fingers: 2 })
            .onActionStart(() => {
              this.gestureStartScale = this.viewScale
              this.onGestureActive(true)
            })
            .onActionUpdate((event: GestureEvent) => {
              this.updateScale(this.gestureStartScale * event.scale)
            })
            .onActionEnd(() => {
              this.onGestureActive(false)
            }),
          PanGesture({ direction: PanDirection.Horizontal, distance: 1 })
            .onActionStart(() => {
              this.gestureStartOffsetX = this.viewOffsetX
              if (this.viewScale > 1) {
                this.onGestureActive(true)
              }
            })
            .onActionUpdate((event: GestureEvent) => {
              if (this.viewScale > 1) {
                this.updateOffset(this.gestureStartOffsetX + event.offsetX)
              }
            })
            .onActionEnd(() => {
              if (this.viewScale > 1) {
                this.getUIContext().animateTo({ duration: 160, curve: Curve.EaseOut }, () => {
                  this.viewOffsetX = this.clampOffset(this.context.width, this.viewOffsetX)
                  this.draw()
                })
              }
              this.onGestureActive(false)
            })
        )
      )
  }
}

@Component
export struct StatisticsPage {
  @Consume('appNavStack') navStack: NavPathStack
  @Watch('onTabChanged')
  @Consume activeTabIndex: number
  @State statMode: string = 'month'
  @State metricMode: string = 'expense'
  @State currentMonth: string = DateUtil.currentMonth()
  @State currentYear: string = new Date().getFullYear().toString()
  @State incomeTotal: number = 0
  @State expenseTotal: number = 0
  @State lastIncomeTotal: number = 0
  @State lastExpenseTotal: number = 0
  @State budgetTotal: number = 0
  @State budgetUsed: number = 0
  @State budgetPercent: number = 0
  @State dayBudgetOverview: BudgetOverview = createEmptyBudgetOverview()
  @State monthBudgetOverview: BudgetOverview = createEmptyBudgetOverview()
  @State yearBudgetOverview: BudgetOverview = createEmptyBudgetOverview()
  @State categoryStats: CategoryStat[] = []
  @State categoryDisplayStats: CategoryStat[] = []
  @State trendBars: TrendBarData[] = []
  @State monthBills: Bill[] = []
  @State trendRange: string = 'week'
  @State trendRangeMenuOpen: boolean = false
  @State trendChartGestureActive: boolean = false
  @State trendSelectionVisible: boolean = false
  @State trendSelectionLabel: string = ''
  @State trendSelectionAmount: number = 0
  @State summarySparkReveal: number = 1
  @State summaryIconMotion: number = 1
  @State summaryRenderVersion: number = 0
  @State slideOffsetX: number = 0
  @State showAllCategories: boolean = false
  @State showAllRanking: boolean = false
  @State showFilterSheet: boolean = false
  @State pendingStatMode: string = 'month'
  @State pendingYear: string = new Date().getFullYear().toString()
  @State pendingMonth: number = new Date().getMonth() + 1
  @StorageProp('statusBarHeight') sbHeight: number = 0
  @Watch('onAppDataVersionChanged')
  @StorageProp('appDataVersion') appDataVersion: number = 0
  private statisticsLoadToken: number = 0

  onTabChanged(): void {
    if (this.activeTabIndex === 3) {
      this.loadData()
    }
  }

  aboutToAppear(): void {
    this.loadData()
  }

  onAppDataVersionChanged(): void {
    this.loadData()
  }

  private async loadData(): Promise<void> {
    try {
      this.statisticsLoadToken += 1
      const loadToken = this.statisticsLoadToken
      const range = this.currentPeriodRange()
      const filter: SearchFilterOptions = {
        keyword: '',
        type: 'all',
        category: '',
        startDate: range.startDate,
        endDate: range.endDate
      }
      const bills = await BillDao.getInstance().queryBySearchFilter(filter)
      const lastRange = this.previousPeriodRange()
      const lastFilter: SearchFilterOptions = {
        keyword: '',
        type: 'all',
        category: '',
        startDate: lastRange.startDate,
        endDate: lastRange.endDate
      }
      const lastBills = await BillDao.getInstance().queryBySearchFilter(lastFilter)
      if (loadToken !== this.statisticsLoadToken) {
        return
      }

      this.monthBills = bills
      this.incomeTotal = this.sumByType(bills, 'income')
      this.expenseTotal = this.sumByType(bills, 'expense')
      this.lastIncomeTotal = this.sumByType(lastBills, 'income')
      this.lastExpenseTotal = this.sumByType(lastBills, 'expense')
      this.categoryStats = this.buildCategoryStats(bills)
      this.categoryDisplayStats = this.buildCategoryDisplayStats(this.categoryStats, this.metricTotal())
      this.summaryRenderVersion += 1
      if (this.isIncomeMode()) {
        this.budgetTotal = 0
        this.budgetUsed = 0
        this.budgetPercent = 0
      } else {
        await this.loadBudgetOverview(loadToken)
      }
      await this.loadTrendData(loadToken)
      if (loadToken !== this.statisticsLoadToken) {
        return
      }
      this.playSummaryMotion()
    } catch (err) {
      LogUtils.error('Statistics', 'loadData error: %{public}s', JSON.stringify(err))
    }
  }

  private playSummaryMotion(): void {
    this.summarySparkReveal = 0.08
    this.summaryIconMotion = 0
    this.getUIContext().animateTo({ duration: 620, curve: Curve.EaseOut }, () => {
      this.summarySparkReveal = 1
      this.summaryIconMotion = 1
    })
  }

  private async loadBudgetOverview(loadToken: number): Promise<void> {
    const dayOverview = await BudgetService.getInstance().buildOverview('day')
    const monthOverview = await BudgetService.getInstance().buildMonthOverview(this.currentMonth)
    const yearOverview = await BudgetService.getInstance().buildYearOverview(this.currentYear)
    if (loadToken !== this.statisticsLoadToken) {
      return
    }
    this.dayBudgetOverview = dayOverview
    this.monthBudgetOverview = monthOverview
    this.yearBudgetOverview = yearOverview
    const overview = this.statMode === 'year' ? yearOverview : monthOverview
    this.budgetTotal = overview.totalFen
    this.budgetUsed = overview.usedFen
    this.budgetPercent = overview.percent
    this.summaryRenderVersion += 1
  }

  private async loadTrendData(loadToken: number): Promise<void> {
    const range = this.currentTrendRange()
    const filter: SearchFilterOptions = {
      keyword: '',
      type: this.metricFilterType(),
      category: '',
      startDate: range.startDate,
      endDate: range.endDate
    }
    const bills = await BillDao.getInstance().queryBySearchFilter(filter)
    if (loadToken !== this.statisticsLoadToken) {
      return
    }
    if (this.statMode === 'year') {
      this.trendBars = this.buildSelectedYearTrendBars(bills, this.currentYear)
    } else {
      this.trendBars = this.buildSelectedMonthDayTrendBars(bills, this.currentMonth)
    }
    this.applyDefaultTrendSelection()
  }

  private applyDefaultTrendSelection(): void {
    if (this.trendBars.length === 0) {
      this.trendSelectionVisible = false
      this.trendSelectionLabel = ''
      this.trendSelectionAmount = 0
      return
    }
    let index = -1
    for (let i = 0; i < this.trendBars.length; i++) {
      if (this.trendBars[i].active) {
        index = i
        break
      }
    }
    if (index < 0) {
      index = this.trendBars.length - 1
    }
    this.trendSelectionLabel = this.trendBars[index].label
    this.trendSelectionAmount = this.trendBars[index].amount
    this.trendSelectionVisible = true
  }

  private currentTrendRange(): StatDateRange {
    if (this.statMode === 'year') {
      return this.currentPeriodRange()
    }
    const endDate = this.resolveTrendEndDate()
    if (this.trendRange === 'month') {
      return {
        startDate: this.currentMonth + '-01',
        endDate: this.currentMonth + '-' + this.two(this.monthLastDay(this.currentMonth))
      }
    }
    const startDate = new Date(endDate.getTime())
    if (this.trendRange === 'thirty') {
      startDate.setDate(endDate.getDate() - 29)
    } else {
      startDate.setDate(endDate.getDate() - 6)
    }
    return { startDate: DateUtil.format(startDate), endDate: DateUtil.format(endDate) }
  }

  private currentPeriodRange(): StatDateRange {
    if (this.statMode === 'year') {
      return { startDate: this.currentYear + '-01-01', endDate: this.currentYear + '-12-31' }
    }
    return { startDate: this.currentMonth + '-01', endDate: this.currentMonth + '-' + this.two(this.monthLastDay(this.currentMonth)) }
  }

  private previousPeriodRange(): StatDateRange {
    if (this.statMode === 'year') {
      const year = (parseInt(this.currentYear, 10) - 1).toString()
      return { startDate: year + '-01-01', endDate: year + '-12-31' }
    }
    const month = DateUtil.getPrevMonth(this.currentMonth)
    return { startDate: month + '-01', endDate: month + '-' + this.two(this.monthLastDay(month)) }
  }

  private currentPeriodText(): string {
    if (this.statMode === 'year') {
      return this.currentYear + '年'
    }
    return DateUtil.formatMonthDisplay(this.currentMonth)
  }

  private headerFilterText(): string {
    if (this.statMode === 'year') {
      return this.currentYear + '年'
    }
    return DateUtil.formatMonthDisplay(this.currentMonth)
  }

  private filterTitleText(): string {
    return (this.statMode === 'year' ? '年度' : '月度') + ' · ' + this.currentPeriodText()
  }

  private comparePeriodText(): string {
    return this.statMode === 'year' ? '较上年' : '较上月'
  }

  private trendCardTitle(): string {
    if (this.statMode === 'year') {
      return this.isIncomeMode() ? '年度收入趋势' : '年度支出趋势'
    }
    return this.isIncomeMode() ? '收入趋势' : '支出趋势'
  }

  private trendUnitTitle(): string {
    if (this.statMode === 'year') {
      return '按月'
    }
    if (this.trendRange === 'month') {
      return '本月'
    }
    return '近7天'
  }

  private metricModeTitle(): string {
    return this.isIncomeMode() ? '收入' : '支出'
  }

  private categoryCardTitle(): string {
    return this.metricModeTitle() + '分类'
  }

  private rankingCardTitle(): string {
    return this.metricModeTitle() + '排行榜'
  }

  private trendEmptyText(): string {
    return '暂无' + this.metricModeTitle() + '数据'
  }

  private sumByType(bills: Bill[], type: 'income' | 'expense'): number {
    let total = 0
    for (let i = 0; i < bills.length; i++) {
      if (type === 'income' && bills[i].type === 'income') {
        total += bills[i].amount
      }
      if (type === 'expense' && this.isExpenseBill(bills[i])) {
        total += bills[i].amount
      }
    }
    return total
  }

  private isExpenseBill(bill: Bill): boolean {
    return bill.type !== 'income'
  }

  private isIncomeMode(): boolean {
    return this.metricMode === 'income'
  }

  private metricFilterType(): 'income' | 'expense' {
    return this.isIncomeMode() ? 'income' : 'expense'
  }

  private isTrendBill(bill: Bill): boolean {
    if (this.isIncomeMode()) {
      return bill.type === 'income'
    }
    return this.isExpenseBill(bill)
  }

  private metricTotal(): number {
    return this.isIncomeMode() ? this.incomeTotal : this.expenseTotal
  }

  private lastMetricTotal(): number {
    return this.isIncomeMode() ? this.lastIncomeTotal : this.lastExpenseTotal
  }

  private buildCategoryStats(bills: Bill[]): CategoryStat[] {
    const names: string[] = []
    const totals: number[] = []
    let grandTotal = 0

    for (let i = 0; i < bills.length; i++) {
      const bill = bills[i]
      if (!this.isTrendBill(bill)) {
        continue
      }
      grandTotal += bill.amount
      const categoryName = bill.category.length > 0 ? bill.category : '其他'
      let foundIndex = -1
      for (let j = 0; j < names.length; j++) {
        if (names[j] === categoryName) {
          foundIndex = j
          break
        }
      }
      if (foundIndex >= 0) {
        totals[foundIndex] += bill.amount
      } else {
        names.push(categoryName)
        totals.push(bill.amount)
      }
    }

    const stats: CategoryStat[] = []
    for (let i = 0; i < names.length; i++) {
      stats.push({
        category: names[i],
        total: totals[i],
        percent: grandTotal > 0 ? Math.round(totals[i] / grandTotal * 100) : 0,
        color: getCategoryColor(names[i])
      })
    }

    stats.sort((a: CategoryStat, b: CategoryStat) => {
      return b.total - a.total
    })
    return stats
  }

  private buildCategoryDisplayStats(stats: CategoryStat[], total: number): CategoryStat[] {
    const result: CategoryStat[] = []
    if (stats.length === 0) {
      if (total > 0) {
        const category = this.isIncomeMode() ? '工资' : '餐饮'
        result.push({ category: category, total: total, percent: 100, color: getCategoryColor(category) })
        return result
      }
      if (this.isIncomeMode()) {
        result.push({ category: '工资', total: 0, percent: 0, color: getCategoryColor('工资') })
        result.push({ category: '兼职', total: 0, percent: 0, color: getCategoryColor('兼职') })
        result.push({ category: '理财', total: 0, percent: 0, color: getCategoryColor('理财') })
        result.push({ category: '其他', total: 0, percent: 0, color: getCategoryColor('其他') })
        return result
      }
      result.push({ category: '餐饮', total: 0, percent: 0, color: getCategoryColor('餐饮') })
      result.push({ category: '购物', total: 0, percent: 0, color: getCategoryColor('购物') })
      result.push({ category: '交通', total: 0, percent: 0, color: getCategoryColor('交通') })
      result.push({ category: '其他', total: 0, percent: 0, color: getCategoryColor('其他') })
      return result
    }
    const maxCount = this.showAllCategories ? stats.length : Math.min(4, stats.length)
    for (let i = 0; i < maxCount; i++) {
      result.push(stats[i])
    }
    return result
  }

  private buildSelectedMonthDayTrendBars(bills: Bill[], month: string): TrendBarData[] {
    if (this.trendRange === 'week') {
      return this.buildDailyTrendBars(bills, this.resolveTrendEndDate(), 7)
    }
    if (this.trendRange === 'thirty') {
      return this.buildDailyTrendBars(bills, this.resolveTrendEndDate(), 30)
    }
    const result: TrendBarData[] = []
    const lastDay = this.monthLastDay(month)
    let maxAmount = 0
    let activeIndex = -1
    for (let day = 1; day <= lastDay; day++) {
      const dateText = month + '-' + this.two(day)
      let amount = 0
      for (let i = 0; i < bills.length; i++) {
        const bill = bills[i]
        if (this.isTrendBill(bill) && bill.date === dateText) {
          amount += bill.amount
        }
      }
      if (amount >= maxAmount && amount > 0) {
        maxAmount = amount
        activeIndex = result.length
      }
      let displayLabel = ''
      if (day === 1 || day === lastDay || day === 10 || day === 20) {
        displayLabel = day.toString() + '日'
      }
      result.push({ label: day.toString() + '日', displayLabel: displayLabel, amount: amount, active: false })
    }
    if (activeIndex < 0 && result.length > 0) {
      activeIndex = 0
    }
    for (let i = 0; i < result.length; i++) {
      result[i].active = i === activeIndex
    }
    return result
  }

  private buildSingleDayTrendBars(bills: Bill[], day: Date): TrendBarData[] {
    const dateText = DateUtil.format(day)
    let amount = 0
    for (let i = 0; i < bills.length; i++) {
      const bill = bills[i]
      if (this.isTrendBill(bill) && bill.date === dateText) {
        amount += bill.amount
      }
    }
    return [{ label: dateText.substring(5), displayLabel: '当日', amount: amount, active: true }]
  }

  private buildSelectedYearTrendBars(bills: Bill[], year: string): TrendBarData[] {
    const result: TrendBarData[] = []
    let maxAmount = 0
    let activeIndex = -1
    for (let month = 1; month <= 12; month++) {
      const monthText = year + '-' + this.two(month)
      let amount = 0
      for (let i = 0; i < bills.length; i++) {
        const bill = bills[i]
        if (this.isTrendBill(bill) && bill.date.length >= 7 && bill.date.substring(0, 7) === monthText) {
          amount += bill.amount
        }
      }
      if (amount >= maxAmount && amount > 0) {
        maxAmount = amount
        activeIndex = result.length
      }
      result.push({ label: month.toString() + '月', displayLabel: month.toString() + '月', amount: amount, active: false })
    }
    if (activeIndex < 0 && result.length > 0) {
      activeIndex = new Date().getMonth()
    }
    for (let i = 0; i < result.length; i++) {
      result[i].active = i === activeIndex
    }
    return result
  }

  private buildTrendBars(bills: Bill[], startDate: Date, endDate: Date): TrendBarData[] {
    if (this.trendRange === 'year') {
      return this.buildYearTrendBars(bills, endDate)
    }
    if (this.trendRange === 'month') {
      return this.buildGroupedDayTrendBars(bills, startDate, endDate, 6)
    }
    return this.buildDailyTrendBars(bills, endDate)
  }

  private buildDailyTrendBars(bills: Bill[], endDate: Date, dayCount: number = 7): TrendBarData[] {
    const result: TrendBarData[] = []
    let maxAmount = 0
    let activeIndex = -1

    for (let i = dayCount - 1; i >= 0; i--) {
      const day = new Date(endDate.getTime())
      day.setDate(endDate.getDate() - i)
      const dateText = DateUtil.format(day)
      let amount = 0
      for (let j = 0; j < bills.length; j++) {
        const bill = bills[j]
        if (this.isTrendBill(bill) && bill.date === dateText) {
          amount += bill.amount
        }
      }
      if (amount >= maxAmount && amount > 0) {
        maxAmount = amount
        activeIndex = result.length
      }
      let displayLabel = dateText.substring(5)
      if (dayCount > 12) {
        displayLabel = ''
        if (i === dayCount - 1 || i === 0 || i === 19 || i === 9) {
          displayLabel = dateText.substring(5)
        }
      }
      result.push({ label: dateText.substring(5), displayLabel: displayLabel, amount: amount, active: false })
    }

    if (activeIndex < 0 && result.length > 0) {
      activeIndex = result.length - 1
    }
    for (let i = 0; i < result.length; i++) {
      result[i].active = i === activeIndex
    }
    return result
  }

  private buildGroupedDayTrendBars(bills: Bill[], startDate: Date, endDate: Date, bucketCount: number): TrendBarData[] {
    const result: TrendBarData[] = []
    const startTime = startDate.getTime()
    const endTime = endDate.getTime()
    const dayCount = Math.floor((endTime - startTime) / 86400000) + 1
    const bucketSize = Math.max(1, Math.ceil(dayCount / bucketCount))
    let maxAmount = 0
    let activeIndex = -1

    for (let i = 0; i < bucketCount; i++) {
      const bucketStart = new Date(startTime)
      bucketStart.setDate(startDate.getDate() + i * bucketSize)
      if (bucketStart.getTime() > endTime) {
        break
      }
      const bucketEnd = new Date(bucketStart.getTime())
      bucketEnd.setDate(bucketStart.getDate() + bucketSize - 1)
      if (bucketEnd.getTime() > endTime) {
        bucketEnd.setTime(endTime)
      }
      const startText = DateUtil.format(bucketStart)
      const endText = DateUtil.format(bucketEnd)
      let amount = 0
      for (let j = 0; j < bills.length; j++) {
        const bill = bills[j]
        if (this.isTrendBill(bill) && bill.date >= startText && bill.date <= endText) {
          amount += bill.amount
        }
      }
      if (amount >= maxAmount && amount > 0) {
        maxAmount = amount
        activeIndex = result.length
      }
      result.push({ label: `${startText.substring(5)}\n${endText.substring(5)}`, amount: amount, active: false })
    }

    if (activeIndex < 0 && result.length > 0) {
      activeIndex = result.length - 1
    }
    for (let i = 0; i < result.length; i++) {
      result[i].active = i === activeIndex
    }
    return result
  }

  private buildYearTrendBars(bills: Bill[], endDate: Date): TrendBarData[] {
    const result: TrendBarData[] = []
    let maxAmount = 0
    let activeIndex = -1
    const endMonth = `${endDate.getFullYear()}-${(endDate.getMonth() + 1).toString().padStart(2, '0')}`
    let month = endMonth
    const months: string[] = []
    for (let i = 0; i < 12; i++) {
      months.unshift(month)
      month = DateUtil.getPrevMonth(month)
    }

    for (let i = 0; i < months.length; i++) {
      const monthText = months[i]
      let amount = 0
      for (let j = 0; j < bills.length; j++) {
        const bill = bills[j]
        if (this.isTrendBill(bill) && bill.date.length >= 7 && bill.date.substring(0, 7) === monthText) {
          amount += bill.amount
        }
      }
      if (amount >= maxAmount && amount > 0) {
        maxAmount = amount
        activeIndex = result.length
      }
      result.push({ label: DateUtil.formatMonthLabel(monthText), amount: amount, active: false })
    }

    if (activeIndex < 0 && result.length > 0) {
      activeIndex = result.length - 1
    }
    for (let i = 0; i < result.length; i++) {
      result[i].active = i === activeIndex
    }
    return result
  }

  private resolveTrendEndDate(): Date {
    const now = new Date()
    if (this.currentMonth === DateUtil.currentMonth()) {
      return now
    }
    const parts = this.currentMonth.split('-')
    const year = parseInt(parts[0], 10)
    const month = parseInt(parts[1], 10)
    return new Date(year, month, 0)
  }

  private resolveTrendStartDate(endDate: Date): Date {
    const start = new Date(endDate.getTime())
    if (this.trendRange === 'year') {
      start.setMonth(endDate.getMonth() - 11)
      start.setDate(1)
      return start
    }
    if (this.trendRange === 'month') {
      start.setDate(endDate.getDate() - 29)
      return start
    }
    start.setDate(endDate.getDate() - 6)
    return start
  }

  private trendRangeTitle(): string {
    if (this.trendRange === 'week') {
      return '近7天'
    }
    if (this.trendRange === 'thirty') {
      return '近30天'
    }
    if (this.trendRange === 'month') {
      return '本月'
    }
    return '近七天'
  }

  private changeTrendRange(range: string): void {
    this.trendRange = range
    this.trendRangeMenuOpen = false
    this.trendSelectionVisible = false
    this.statisticsLoadToken += 1
    this.loadTrendData(this.statisticsLoadToken)
  }

  private showTrendSelection(label: string, amount: number): void {
    this.trendSelectionLabel = label
    this.trendSelectionAmount = amount
    this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
      this.trendSelectionVisible = true
    })
  }

  private doMonthSwitch(direction: number): void {
    if (direction < 0 && DateUtil.isCurrentMonth(this.currentMonth)) {
      this.getUIContext().animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
        this.slideOffsetX = 0
      })
      return
    }
    const next = direction > 0 ? DateUtil.getPrevMonth(this.currentMonth) : DateUtil.getNextMonth(this.currentMonth)
    const exitX = direction > 0 ? 360 : -360

    this.getUIContext().animateTo({
      duration: 150,
      curve: Curve.EaseIn,
      onFinish: () => {
        this.slideOffsetX = exitX * -1
        this.currentMonth = next
        this.currentYear = next.substring(0, 4)
        this.showAllCategories = false
        this.showAllRanking = false
        this.trendRangeMenuOpen = false
        this.loadData()
        this.getUIContext().animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
          this.slideOffsetX = 0
        })
      }
    }, () => {
      this.slideOffsetX = exitX
    })
  }

  private doYearSwitch(direction: number): void {
    const year = parseInt(this.currentYear, 10)
    if (isNaN(year)) {
      this.slideOffsetX = 0
      return
    }
    const next = (year - direction).toString()
    const exitX = direction > 0 ? 360 : -360
    const parts = this.currentMonth.split('-')
    const keepMonth = parts.length === 2 ? parts[1] : this.two(new Date().getMonth() + 1)
    this.getUIContext().animateTo({
      duration: 150,
      curve: Curve.EaseIn,
      onFinish: () => {
        this.slideOffsetX = exitX * -1
        this.currentYear = next
        this.currentMonth = next + '-' + keepMonth
        this.showAllCategories = false
        this.showAllRanking = false
        this.trendRangeMenuOpen = false
        this.loadData()
        this.getUIContext().animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
          this.slideOffsetX = 0
        })
      }
    }, () => {
      this.slideOffsetX = exitX
    })
  }

  private doPeriodSwitch(direction: number): void {
    if (this.statMode === 'year') {
      this.doYearSwitch(direction)
      return
    }
    this.doMonthSwitch(direction)
  }

  private switchStatMode(mode: string): void {
    if (this.statMode === mode) {
      return
    }
    this.statMode = mode
    if (mode === 'year' && this.currentMonth.length >= 4) {
      this.currentYear = this.currentMonth.substring(0, 4)
    }
    if (mode === 'month' && this.currentYear.length > 0) {
      const parts = this.currentMonth.split('-')
      const month = parts.length === 2 ? parts[1] : this.two(new Date().getMonth() + 1)
      this.currentMonth = this.currentYear + '-' + month
      if (this.trendRange === 'thirty') {
        this.trendRange = 'week'
      }
    }
    this.showAllCategories = false
    this.showAllRanking = false
    this.loadData()
  }

  private switchMetricMode(mode: string): void {
    if (this.metricMode === mode) {
      return
    }
    this.metricMode = mode
    this.showAllCategories = false
    this.showAllRanking = false
    this.trendSelectionVisible = false
    this.loadData()
  }

  private openFilterSheet(): void {
    this.pendingStatMode = this.statMode
    this.pendingYear = this.statMode === 'year' ? this.currentYear : this.currentMonth.substring(0, 4)
    const parts = this.currentMonth.split('-')
    if (parts.length === 2) {
      this.pendingMonth = parseInt(parts[1], 10)
    } else {
      this.pendingMonth = new Date().getMonth() + 1
    }
    this.showFilterSheet = true
  }

  private confirmFilterSheet(): void {
    this.statMode = this.pendingStatMode
    this.currentYear = this.pendingYear
    this.currentMonth = this.pendingYear + '-' + this.two(this.pendingMonth)
    this.showFilterSheet = false
    this.showAllCategories = false
    this.showAllRanking = false
    this.loadData()
  }

  private changePendingYear(offset: number): void {
    const year = parseInt(this.pendingYear, 10)
    if (isNaN(year)) {
      this.pendingYear = new Date().getFullYear().toString()
      return
    }
    this.pendingYear = (year + offset).toString()
  }

  private monthIndexes(): number[] {
    const result: number[] = []
    for (let i = 1; i <= 12; i++) {
      result.push(i)
    }
    return result
  }

  private monthLastDay(month: string): number {
    const parts = month.split('-')
    if (parts.length !== 2) {
      return 31
    }
    const year = parseInt(parts[0], 10)
    const monthIndex = parseInt(parts[1], 10)
    if (isNaN(year) || isNaN(monthIndex)) {
      return 31
    }
    return new Date(year, monthIndex, 0).getDate()
  }

  private trendLastDay(month: string): number {
    if (month === DateUtil.currentMonth()) {
      const today = DateUtil.today()
      if (today.length >= 10) {
        const day = parseInt(today.substring(8, 10), 10)
        if (!isNaN(day) && day > 0) {
          return day
        }
      }
    }
    return this.monthLastDay(month)
  }

  private two(value: number): string {
    if (value < 10) {
      return '0' + value.toString()
    }
    return value.toString()
  }

  private netBalance(): number {
    return this.incomeTotal - this.expenseTotal
  }

  private lastNetBalance(): number {
    return this.lastIncomeTotal - this.lastExpenseTotal
  }

  private compareText(current: number, last: number): string {
    if (last <= 0 && current <= 0) {
      return '持平'
    }
    if (last <= 0) {
      return '新增'
    }
    if (current === last) {
      return '持平'
    }
    const diff = Math.abs(current - last)
    const percent = Math.round(diff / last * 100)
    return current > last ? `上升 ${percent}%` : `下降 ${percent}%`
  }

  private compareColor(current: number, last: number): ResourceColor {
    if (current < last) {
      return $r('app.color.color_primary')
    }
    if (current > last) {
      return $r('app.color.color_expense')
    }
    return $r('app.color.color_text_secondary')
  }

  private compareColorByDirection(current: number, last: number, increaseGood: boolean): ResourceColor {
    if (current === last) {
      return $r('app.color.color_text_secondary')
    }
    if (current > last) {
      return increaseGood ? $r('app.color.color_primary') : $r('app.color.color_expense')
    }
    return increaseGood ? $r('app.color.color_expense') : $r('app.color.color_primary')
  }

  private totalCategoryAmount(): number {
    let total = 0
    for (let i = 0; i < this.categoryStats.length; i++) {
      total += this.categoryStats[i].total
    }
    return total
  }

  private defaultCategoryAt(index: number): CategoryStat {
    if (this.isIncomeMode()) {
      if (index === 0) {
        return { category: '工资', total: 0, percent: 0, color: getCategoryColor('工资') }
      }
      if (index === 1) {
        return { category: '兼职', total: 0, percent: 0, color: getCategoryColor('兼职') }
      }
      if (index === 2) {
        return { category: '理财', total: 0, percent: 0, color: getCategoryColor('理财') }
      }
      return { category: '其他', total: 0, percent: 0, color: getCategoryColor('其他') }
    }
    if (index === 0) {
      return { category: '餐饮', total: 0, percent: 0, color: '#FF9F1C' }
    }
    if (index === 1) {
      return { category: '购物', total: 0, percent: 0, color: '#3B82F6' }
    }
    if (index === 2) {
      return { category: '交通', total: 0, percent: 0, color: '#2563EB' }
    }
    return { category: '其他', total: 0, percent: 0, color: '#94A3B8' }
  }

  private categoryAt(index: number): CategoryStat {
    if (index < this.categoryStats.length) {
      return this.categoryStats[index]
    }
    if (this.categoryStats.length === 0 && this.metricTotal() > 0 && index === 0) {
      const category = this.isIncomeMode() ? '工资' : '餐饮'
      return { category: category, total: this.metricTotal(), percent: 100, color: getCategoryColor(category) }
    }
    return this.defaultCategoryAt(index)
  }

  private rankingIndexes(): number[] {
    const count = this.showAllRanking ? this.categoryStats.length : Math.min(3, this.categoryStats.length)
    const indexes: number[] = []
    const finalCount = count > 0 ? count : 3
    for (let i = 0; i < finalCount; i++) {
      indexes.push(i)
    }
    return indexes
  }

  private maxTrendAmount(): number {
    let maxValue = 0
    for (let i = 0; i < this.trendBars.length; i++) {
      if (this.trendBars[i].amount > maxValue) {
        maxValue = this.trendBars[i].amount
      }
    }
    return maxValue
  }

  private trendAxisMax(): number {
    const maxFen = this.maxTrendAmount()
    if (maxFen <= 0) {
      return 3000
    }
    const maxYuan = Math.ceil(maxFen / 100)
    if (maxYuan <= 30) {
      return 3000
    }
    if (maxYuan <= 100) {
      return Math.ceil(maxYuan / 10) * 1000
    }
    return Math.ceil(maxYuan / 50) * 5000
  }

  private trendAxisValue(index: number): number {
    const maxFen = this.trendAxisMax()
    return Math.round(maxFen / 3 * (3 - index))
  }

  private trendHeight(amount: number): number {
    const maxValue = this.trendAxisMax()
    if (amount <= 0) {
      return 10
    }
    const height = Math.floor(amount / maxValue * 112)
    return Math.max(22, Math.min(116, height))
  }

  private trendBarWidth(): number {
    return this.statMode === 'year' ? 16 : 5
  }

  private trendLabelWidth(): number {
    return this.statMode === 'year' ? 28 : 16
  }

  private trendLabelFontSize(): number {
    return this.statMode === 'year' ? 11 : 9
  }

  private trendBarColor(item: TrendBarData): ResourceColor {
    if (item.active) {
      return $r('app.color.color_primary')
    }
    if (item.amount > 0) {
      return '#BFD6FF'
    }
    return '#EDF4FF'
  }

  private trendDisplayLabel(item: TrendBarData): string {
    if (item.displayLabel !== undefined) {
      return item.displayLabel
    }
    return item.label
  }

  private trendTipText(item: TrendBarData): string {
    return item.label + '  ¥' + AmountUtil.fen2Display(item.amount)
  }

  private rankingWidth(stat: CategoryStat): string {
    if (this.metricTotal() <= 0 || stat.total <= 0) {
      return '0%'
    }
    const percent = Math.floor(stat.total / this.metricTotal() * 100)
    return `${Math.max(4, Math.min(100, percent))}%`
  }

  private rankingPercent(stat: CategoryStat): number {
    if (this.metricTotal() <= 0 || stat.total <= 0) {
      return 0
    }
    return Math.round(stat.total / this.metricTotal() * 100)
  }

  private budgetProgressText(): string {
    if (this.budgetTotal <= 0) {
      return '未设置'
    }
    return `${this.budgetPercent}%`
  }

  private budgetCompareText(): string {
    if (this.budgetTotal <= 0) {
      return '未设置'
    }
    return `已用 ¥${AmountUtil.fen2Display(this.budgetUsed)}`
  }

  private budgetTitleText(): string {
    return this.statMode === 'year' ? '年度预算' : '本月预算'
  }

  private budgetAmountText(): string {
    if (this.budgetTotal <= 0) {
      return '未设置'
    }
    return '¥' + AmountUtil.fen2Display(this.budgetTotal)
  }

  private budgetUsedRateText(): string {
    if (this.budgetTotal <= 0) {
      return '未设置'
    }
    return '已用' + this.budgetPercent.toString() + '%'
  }

  private summaryExpenseTitle(): string {
    return this.statMode === 'year' ? '本年支出' : '本月支出'
  }

  private summaryIncomeTitle(): string {
    return this.statMode === 'year' ? '本年收入' : '本月收入'
  }

  private summaryBalanceTitle(): string {
    return this.statMode === 'year' ? '本年结余' : '本月结余'
  }

  private summaryAmountFontSize(value: string): number {
    if (value.length >= 13) {
      return 12
    }
    if (value.length >= 11) {
      return 13
    }
    if (value.length >= 9) {
      return 14
    }
    if (value.length >= 7) {
      return 15
    }
    return 16
  }

  private summaryAmountMaxLines(value: string): number {
    return value.length >= 13 ? 2 : 1
  }

  private compactMoneyText(amount: number): string {
    const value = Math.abs(amount)
    if (value % 100 === 0) {
      return '¥' + Math.floor(value / 100).toString()
    }
    return '¥' + AmountUtil.fen2Display(value)
  }

  private compactSignedMoneyText(amount: number): string {
    if (amount < 0) {
      return '-' + this.compactMoneyText(amount)
    }
    return this.compactMoneyText(amount)
  }

  private compactBudgetAmountText(): string {
    if (this.budgetTotal <= 0) {
      return '未设置'
    }
    return this.compactMoneyText(this.budgetTotal)
  }

  private compactCompareText(current: number, last: number): string {
    const text = this.compareText(current, last)
    if (text.indexOf('上升') === 0) {
      return '上升'
    }
    if (text.indexOf('下降') === 0) {
      return '下降'
    }
    return text
  }

  private trendSelectionAmountText(): string {
    return '¥' + AmountUtil.fen2Display(this.trendSelectionAmount)
  }

  private budgetProgressWidth(): string {
    if (this.budgetTotal <= 0 || this.budgetPercent <= 0) {
      return '0%'
    }
    const percent = Math.max(4, Math.min(100, this.budgetPercent))
    return percent.toString() + '%'
  }

  private expenseCompareBadgeText(): string {
    const text = this.compareText(this.expenseTotal, this.lastExpenseTotal)
    if (text === '持平') {
      return this.comparePeriodText() + ' 持平'
    }
    if (text === '新增') {
      return this.comparePeriodText() + ' 新增'
    }
    return this.comparePeriodText() + ' ' + text
  }

  private summarySparkRevealWidth(): string {
    const value = Math.max(0.08, Math.min(1, this.summarySparkReveal))
    return Math.round(value * 100).toString() + '%'
  }

  @Builder
  Header() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Image($rawfile('illustration_fish_bowl.png'))
        .width(156)
        .height(96)
        .objectFit(ImageFit.Contain)
        .opacity(0.92)
        .margin({ top: this.sbHeight + 4, right: 8 })
        .hitTestBehavior(HitTestMode.None)

      Column() {
        Text('统计')
          .fontSize(30)
          .fontWeight(FontWeight.Bolder)
          .fontColor($r('app.color.color_text_deep'))
          .width('100%')
          .textAlign(TextAlign.Start)
          .padding({ left: 24 })
          .margin({ top: this.sbHeight + 18 })

        Row() {
          Row({ space: 4 }) {
            this.StatModePill('月度', 'month')
            this.StatModePill('年度', 'year')
          }
          .width(112)
          .height(40)
          .padding(4)
          .borderRadius(20)
          .backgroundColor($r('app.color.color_card_overlay'))
          .border({ width: 1, color: $r('app.color.color_divider') })
          .shadow({ radius: 10, color: $r('app.color.color_shadow_blue_09'), offsetX: 0, offsetY: 4 })
          .margin({ right: 12 })

          Row({ space: 8 }) {
            Image($rawfile('icon_calendar.svg'))
              .width(18)
              .height(18)
              .fillColor($r('app.color.color_primary'))
            Text(this.headerFilterText())
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.color_text_deep'))
            Image($rawfile('icon_chevron_down.svg'))
              .width(14)
              .height(14)
              .fillColor($r('app.color.color_text_deep'))
          }
          .height(40)
          .padding({ left: 20, right: 20 })
          .backgroundColor($r('app.color.color_card_overlay'))
          .borderRadius(20)
          .border({ width: 1, color: $r('app.color.color_divider') })
          .shadow({ radius: 12, color: $r('app.color.color_shadow_blue_09'), offsetX: 0, offsetY: 4 })
          .onClick(() => {
            this.openFilterSheet()
          })
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 8 })
      }
      .width('100%')
    }
    .width('100%')
    .height(this.sbHeight + 128)
  }

  @Builder
  StatModePill(label: string, mode: string) {
    Text(label)
      .fontSize(14)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.statMode === mode ? $r('app.color.color_white') : $r('app.color.color_text_secondary'))
      .height(32)
      .layoutWeight(1)
      .textAlign(TextAlign.Center)
      .borderRadius(16)
      .backgroundColor(this.statMode === mode ? $r('app.color.color_primary') : Color.Transparent)
      .onClick(() => {
        this.switchStatMode(mode)
      })
  }

  @Builder
  MetricModePill(label: string, mode: string) {
    Text(label)
      .fontSize(14)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.metricMode === mode ? $r('app.color.color_white') : $r('app.color.color_text_secondary'))
      .height(34)
      .layoutWeight(1)
      .textAlign(TextAlign.Center)
      .borderRadius(17)
      .backgroundColor(this.metricMode === mode ? $r('app.color.color_primary') : Color.Transparent)
      .onClick(() => {
        this.switchMetricMode(mode)
      })
  }

  @Builder
  MetricModeSwitch() {
    Row({ space: 4 }) {
      this.MetricModePill('支出', 'expense')
      this.MetricModePill('收入', 'income')
    }
    .width('calc(100% - 36vp)')
    .height(42)
    .padding(4)
    .borderRadius(21)
    .backgroundColor($r('app.color.color_card_overlay'))
    .border({ width: 1, color: $r('app.color.color_divider') })
    .shadow({ radius: 12, color: $r('app.color.color_shadow_blue_09'), offsetX: 0, offsetY: 5 })
    .margin({ left: 18, right: 18, top: 6, bottom: 8 })
  }

  @Builder
  SummaryMetricIcon(icon: string, tintColor: ResourceColor, bgColor: ResourceColor) {
    Row() {
      Image($rawfile(icon))
        .width(18)
        .height(18)
        .fillColor(tintColor)
    }
    .width(38)
    .height(38)
    .borderRadius(19)
    .backgroundColor(bgColor)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  ExpenseSparkLine() {
    Stack({ alignContent: Alignment.Start }) {
      Row() {
        SummaryExpenseSparkline({
          currentAmount: this.expenseTotal,
          lastAmount: this.lastExpenseTotal
        })
        .width(132)
        .height(42)
      }
      .width(this.summarySparkRevealWidth())
      .height(42)
      .clip(true)
    }
    .width('100%')
    .height(42)
  }

  @Builder
  SummaryTrendIcon() {
    Stack() {
      Row()
        .width(22)
        .height(18)
        .borderRadius(6)
        .backgroundColor('#20EF5B73')
        .position({ x: 1, y: 2 })

      Row()
        .width(7)
        .height(3)
        .borderRadius(2)
        .backgroundColor($r('app.color.color_expense'))
        .position({ x: 4, y: 13 })

      Row()
        .width(10)
        .height(3)
        .borderRadius(2)
        .backgroundColor($r('app.color.color_expense'))
        .rotate({ angle: -28 })
        .position({ x: 9, y: 10 })

      Row()
        .width(9)
        .height(3)
        .borderRadius(2)
        .backgroundColor($r('app.color.color_expense'))
        .rotate({ angle: -28 })
        .position({ x: 15, y: 6 })

      Row()
        .width(7)
        .height(3)
        .borderRadius(2)
        .backgroundColor($r('app.color.color_expense'))
        .rotate({ angle: 40 })
        .position({ x: 18, y: 5 })

      Row()
        .width(7)
        .height(3)
        .borderRadius(2)
        .backgroundColor($r('app.color.color_expense'))
        .rotate({ angle: -46 })
        .position({ x: 18, y: 9 })
    }
    .width(26)
    .height(22)
    .opacity(0.76 + this.summaryIconMotion * 0.24)
    .scale({ x: 0.88 + this.summaryIconMotion * 0.12, y: 0.88 + this.summaryIconMotion * 0.12 })
    .translate({ y: 4 - this.summaryIconMotion * 4 })
  }

  @Builder
  SmallSummaryMetric(title: string, amountText: string, compareText: string, icon: string, tintColor: ResourceColor, bgColor: ResourceColor, isBudget: boolean) {
    Column() {
      this.SummaryMetricIcon(icon, tintColor, bgColor)
      Text(title)
        .fontSize(12)
        .fontColor($r('app.color.color_text_secondary'))
        .margin({ top: 7 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(amountText)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(tintColor)
        .margin({ top: 6 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (isBudget) {
        Stack({ alignContent: Alignment.Start }) {
          Row()
            .width('100%')
            .height(7)
            .borderRadius(4)
            .backgroundColor($r('app.color.color_track'))
          Row()
            .width(this.budgetProgressWidth())
            .height(7)
            .borderRadius(4)
            .backgroundColor($r('app.color.color_primary'))
        }
        .width('100%')
        .margin({ top: 8 })
      } else {
        Row()
          .width(24)
          .height(4)
          .borderRadius(2)
          .backgroundColor(tintColor)
          .margin({ top: 8 })
      }
      Text(compareText)
        .fontSize(11)
        .fontColor($r('app.color.color_text_secondary'))
        .margin({ top: 6 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  SummaryColumn(title: string, value: string, valueColor: ResourceColor, showHelp: boolean, showBudgetProgress: boolean) {
    Column() {
      Row({ space: 5 }) {
        Text(title)
          .fontSize(12)
          .fontColor($r('app.color.color_text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (showHelp) {
          Image($rawfile('icon_help_circle.svg'))
            .width(13)
            .height(13)
            .fillColor($r('app.color.color_text_secondary'))
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(value)
        .fontSize(this.summaryAmountFontSize(value))
        .fontWeight(FontWeight.Bolder)
        .fontColor(valueColor)
        .margin({ top: 8 })
        .maxLines(this.summaryAmountMaxLines(value))
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (showBudgetProgress) {
        Text(this.budgetUsedRateText())
          .fontSize(11)
          .fontColor($r('app.color.color_text_secondary'))
          .margin({ top: 4 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Stack({ alignContent: Alignment.Start }) {
          Row()
            .width('100%')
            .height(7)
            .borderRadius(4)
            .backgroundColor($r('app.color.color_track'))
          Row()
            .width(this.budgetProgressWidth())
            .height(7)
            .borderRadius(4)
            .backgroundColor($r('app.color.color_primary'))
        }
        .width('100%')
        .margin({ top: 8 })
      }
    }
    .layoutWeight(1)
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  SummaryPanel() {
    Row() {
      Column() {
        Row({ space: 4 }) {
          Text(this.isIncomeMode() ? this.summaryIncomeTitle() : this.summaryExpenseTitle())
            .fontSize(11)
            .fontColor($r('app.color.color_text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Image($rawfile('icon_help_circle.svg'))
            .width(13)
            .height(13)
            .fillColor($r('app.color.color_text_secondary'))
        }
        .alignItems(VerticalAlign.Center)

        Text(this.compactMoneyText(this.metricTotal()))
          .fontSize(this.summaryAmountFontSize(this.compactMoneyText(this.metricTotal())))
          .fontWeight(FontWeight.Bolder)
          .fontColor(this.isIncomeMode() ? $r('app.color.color_primary') : $r('app.color.color_text_deep'))
          .margin({ top: 6 })
          .maxLines(this.summaryAmountMaxLines(this.compactMoneyText(this.metricTotal())))
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row()
          .width(24)
          .height(4)
          .borderRadius(2)
          .backgroundColor(this.isIncomeMode() ? $r('app.color.color_primary') : $r('app.color.color_text_deep'))
          .margin({ top: 7 })
        Text(this.comparePeriodText() + ' ' + this.compactCompareText(this.metricTotal(), this.lastMetricTotal()))
          .fontSize(10)
          .fontColor(this.compareColorByDirection(this.metricTotal(), this.lastMetricTotal(), this.isIncomeMode()))
          .margin({ top: 5 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .height('100%')
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
      Divider().vertical(true).height(64).color($r('app.color.color_divider'))
      Column() {
        Text(this.isIncomeMode() ? this.summaryExpenseTitle() : this.summaryIncomeTitle())
          .fontSize(11)
          .fontColor($r('app.color.color_text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.compactMoneyText(this.isIncomeMode() ? this.expenseTotal : this.incomeTotal))
          .fontSize(this.summaryAmountFontSize(this.compactMoneyText(this.isIncomeMode() ? this.expenseTotal : this.incomeTotal)))
          .fontWeight(FontWeight.Bolder)
          .fontColor(this.isIncomeMode() ? $r('app.color.color_expense') : $r('app.color.color_primary'))
          .margin({ top: 6 })
          .maxLines(this.summaryAmountMaxLines(this.compactMoneyText(this.isIncomeMode() ? this.expenseTotal : this.incomeTotal)))
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row()
          .width(24)
          .height(4)
          .borderRadius(2)
          .backgroundColor(this.isIncomeMode() ? $r('app.color.color_expense') : $r('app.color.color_primary'))
          .margin({ top: 7 })
        Text(this.comparePeriodText() + ' ' + this.compactCompareText(this.isIncomeMode() ? this.expenseTotal : this.incomeTotal, this.isIncomeMode() ? this.lastExpenseTotal : this.lastIncomeTotal))
          .fontSize(10)
          .fontColor(this.compareColorByDirection(this.isIncomeMode() ? this.expenseTotal : this.incomeTotal, this.isIncomeMode() ? this.lastExpenseTotal : this.lastIncomeTotal, !this.isIncomeMode()))
          .margin({ top: 5 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .height('100%')
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
      Divider().vertical(true).height(64).color($r('app.color.color_divider'))
      Column() {
        Text(this.summaryBalanceTitle())
          .fontSize(11)
          .fontColor($r('app.color.color_text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.compactSignedMoneyText(this.netBalance()))
          .fontSize(this.summaryAmountFontSize(this.compactSignedMoneyText(this.netBalance())))
          .fontWeight(FontWeight.Bolder)
          .fontColor(this.netBalance() < 0 ? $r('app.color.color_expense') : $r('app.color.color_primary'))
          .margin({ top: 6 })
          .maxLines(this.summaryAmountMaxLines(this.compactSignedMoneyText(this.netBalance())))
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row()
          .width(24)
          .height(4)
          .borderRadius(2)
          .backgroundColor(this.netBalance() < 0 ? $r('app.color.color_expense') : $r('app.color.color_primary'))
          .margin({ top: 7 })
        Text(this.comparePeriodText() + ' ' + this.compactCompareText(this.netBalance(), this.lastNetBalance()))
          .fontSize(10)
          .fontColor(this.compareColor(this.netBalance(), this.lastNetBalance()))
          .margin({ top: 5 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .height('100%')
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
    }
    .width('calc(100% - 36vp)')
    .height(118)
    .padding({ left: 12, right: 12, top: 16, bottom: 16 })
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(20)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .shadow({ radius: 14, color: $r('app.color.color_shadow_blue_09'), offsetX: 0, offsetY: 6 })
    .margin({ left: 18, right: 18, top: 6, bottom: 8 })
  }

  @Builder
  BudgetOverviewCard() {
    Column() {
      Row() {
        Row()
          .width(4)
          .height(20)
          .borderRadius(2)
          .backgroundColor($r('app.color.color_primary'))
          .margin({ right: 8 })
        Text('预算概览')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_deep'))
        Blank()
        Text(this.budgetProgressText())
          .fontSize(12)
          .fontColor($r('app.color.color_text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 12 })

      Row({ space: 10 }) {
        StatisticsBudgetMiniCard({
          title: '今日预算',
          iconColor: $r('app.color.color_primary'),
          totalFen: this.dayBudgetOverview.totalFen,
          usedFen: this.dayBudgetOverview.usedFen,
          remainFen: this.dayBudgetOverview.remainFen,
          percent: this.dayBudgetOverview.percent,
          activeRuleCount: this.dayBudgetOverview.activeRuleCount,
          categoryBudgetFen: this.dayBudgetOverview.categoryBudgetFen
        })
        StatisticsBudgetMiniCard({
          title: '本月预算',
          iconColor: $r('app.color.color_accent_deep'),
          totalFen: this.monthBudgetOverview.totalFen,
          usedFen: this.monthBudgetOverview.usedFen,
          remainFen: this.monthBudgetOverview.remainFen,
          percent: this.monthBudgetOverview.percent,
          activeRuleCount: this.monthBudgetOverview.activeRuleCount,
          categoryBudgetFen: this.monthBudgetOverview.categoryBudgetFen
        })
        StatisticsBudgetMiniCard({
          title: '本年预算',
          iconColor: $r('app.color.color_purple'),
          totalFen: this.yearBudgetOverview.totalFen,
          usedFen: this.yearBudgetOverview.usedFen,
          remainFen: this.yearBudgetOverview.remainFen,
          percent: this.yearBudgetOverview.percent,
          activeRuleCount: this.yearBudgetOverview.activeRuleCount,
          categoryBudgetFen: this.yearBudgetOverview.categoryBudgetFen
        })
      }
      .width('100%')
    }
    .width('calc(100% - 36vp)')
    .padding({ left: 12, right: 12, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(20)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .shadow({ radius: 14, color: $r('app.color.color_shadow_blue_09'), offsetX: 0, offsetY: 6 })
    .margin({ left: 18, right: 18, top: 6, bottom: 8 })
  }

  @Builder
  CategoryCard() {
    Column() {
      Row() {
        Row()
          .width(4)
          .height(20)
          .borderRadius(2)
          .backgroundColor($r('app.color.color_primary'))
          .margin({ right: 8 })
        Text(this.categoryCardTitle())
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_deep'))
        Blank()
        Row() {
          Text('占比')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.color_white'))
            .height(30)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .borderRadius(15)
            .backgroundColor($r('app.color.color_primary'))
          Text('排行')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.color_text_secondary'))
            .height(30)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
        }
        .width(104)
        .height(34)
        .padding(2)
        .borderRadius(17)
        .backgroundColor($r('app.color.color_surface'))
        .border({ width: 1, color: $r('app.color.color_divider') })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      ForEach(this.categoryDisplayStats, (stat: CategoryStat) => {
        this.CategoryAnalysisRow(stat)
      }, (stat: CategoryStat) => `${stat.category}_${stat.total}_${stat.percent}`)
    }
    .width('calc(100% - 36vp)')
    .padding({ left: 14, right: 14, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(20)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .shadow({ radius: 14, color: $r('app.color.color_shadow_blue_09'), offsetX: 0, offsetY: 6 })
    .margin({ left: 18, right: 18, top: 6, bottom: 8 })
  }

  @Builder
  CategoryAnalysisRow(stat: CategoryStat) {
    Row() {
      Row() {
        Image($rawfile(getCategoryInfo(stat.category).icon + '.svg'))
          .width(20)
          .height(20)
          .fillColor($r('app.color.color_white'))
      }
      .width(38)
      .height(38)
      .borderRadius(19)
      .backgroundColor(stat.total > 0 ? stat.color : $r('app.color.color_track'))
      .justifyContent(FlexAlign.Center)
      .margin({ right: 14 })

      Text(stat.category)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.color_text_deep'))
        .width(52)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(7)
          .borderRadius(4)
          .backgroundColor('#EEF3F5')
        Row()
          .width(this.rankingWidth(stat))
          .height(7)
          .borderRadius(4)
          .backgroundColor(stat.total > 0 ? stat.color : $r('app.color.color_track'))
      }
      .layoutWeight(1)
      .margin({ left: 8, right: 12 })

      Text(`¥${AmountUtil.fen2Display(stat.total)}`)
        .fontSize(13)
        .fontColor($r('app.color.color_text_deep'))
        .width(70)
        .textAlign(TextAlign.End)
      Text(`${this.rankingPercent(stat)}%`)
        .fontSize(13)
        .fontColor($r('app.color.color_text_secondary'))
        .width(44)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .height(54)
    .alignItems(VerticalAlign.Center)
    .margin({ top: 8 })
  }

  @Builder
  TrendRangeOption(label: string, range: string) {
    Text(label)
      .fontSize(13)
      .fontWeight(this.trendRange === range ? FontWeight.Bold : FontWeight.Medium)
      .fontColor(this.trendRange === range ? $r('app.color.color_white') : $r('app.color.color_text_secondary'))
      .height(32)
      .layoutWeight(1)
      .textAlign(TextAlign.Center)
      .backgroundColor(this.trendRange === range ? $r('app.color.color_primary') : Color.Transparent)
      .borderRadius(16)
      .onClick(() => {
        this.changeTrendRange(range)
      })
  }

  @Builder
  TrendCard() {
    Column() {
      Row() {
        Row()
          .width(4)
          .height(20)
          .borderRadius(2)
          .backgroundColor($r('app.color.color_primary'))
          .margin({ right: 8 })
        Text(this.trendCardTitle())
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_deep'))
        Blank()
        if (this.statMode === 'year') {
          Row({ space: 4 }) {
            Text(this.trendUnitTitle())
              .fontSize(12)
              .fontColor($r('app.color.color_text_deep'))
          }
          .height(26)
          .padding({ left: 12, right: 12 })
          .borderRadius(13)
          .border({ width: 1, color: $r('app.color.color_divider') })
        } else {
          Row() {
            this.TrendRangeOption('近7天', 'week')
            this.TrendRangeOption('本月', 'month')
          }
          .width(118)
          .height(36)
          .padding(2)
          .borderRadius(18)
          .backgroundColor($r('app.color.color_surface'))
          .border({ width: 1, color: $r('app.color.color_divider') })
        }
      }
      .width('100%')

      Row() {
        Text('当前')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.color_text_secondary'))
          .margin({ right: 10 })
        Text(this.trendSelectionLabel)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_deep'))
          .maxLines(1)
        Blank()
        Text(this.trendSelectionAmountText())
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .height(40)
      .padding({ left: 16, right: 16 })
      .borderRadius(20)
      .backgroundColor('#F2F7FF')
      .margin({ top: 10 })

        ExpenseTrendCanvas({
          data: this.trendBars,
          axisMax: this.trendAxisMax(),
          statMode: this.statMode,
          selectedLabel: this.trendSelectionLabel,
          emptyText: this.trendEmptyText(),
          onGestureActive: (active: boolean) => {
            this.trendChartGestureActive = active
          },
        onSelect: (label: string, amount: number) => {
          this.showTrendSelection(label, amount)
        }
      })
      .width('100%')
      .height(188)
      .margin({ top: 6 })
    }
    .width('calc(100% - 36vp)')
    .padding({ left: 12, right: 12, top: 12, bottom: 6 })
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(20)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .shadow({ radius: 14, color: $r('app.color.color_shadow_blue_09'), offsetX: 0, offsetY: 6 })
    .margin({ left: 18, right: 18, top: 6, bottom: 8 })
  }

  @Builder
  MedalBadge(index: number) {
    Row() {
      Text((index + 1).toString())
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(index === 0 ? '#7A4B00' : index === 1 ? '#536170' : '#8A4A22')
    }
    .width(28)
    .height(28)
    .borderRadius(14)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(index === 0 ? '#FFE49A' : index === 1 ? '#DDE6EF' : '#FFD1B1')
    .border({ width: 2, color: index === 0 ? '#FFB84D' : index === 1 ? '#B7C6D4' : '#F4A06B' })
  }

  @Builder
  RankingRow(index: number) {
    Row() {
      Row() {
        this.MedalBadge(index)
      }
      .margin({ right: 8 })
      Row() {
        Image($rawfile(getCategoryInfo(this.categoryAt(index).category).icon + '.svg'))
          .width(20)
          .height(20)
          .fillColor($r('app.color.color_white'))
      }
      .width(32)
      .height(32)
      .borderRadius(16)
      .backgroundColor(this.categoryAt(index).color)
      .justifyContent(FlexAlign.Center)
      .margin({ right: 10 })
      Text(this.categoryAt(index).category)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.color_text_deep'))
        .width(48)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(8)
          .borderRadius(4)
          .backgroundColor($r('app.color.color_track'))
        Row()
          .width(this.rankingWidth(this.categoryAt(index)))
          .height(8)
          .borderRadius(4)
          .backgroundColor(this.categoryAt(index).total > 0 ? this.categoryAt(index).color : '#E8EEF8')
      }
      .layoutWeight(1)

      Text(`¥${AmountUtil.fen2Display(this.categoryAt(index).total)}`)
        .fontSize(12)
        .fontColor($r('app.color.color_text_deep'))
        .width(58)
        .textAlign(TextAlign.End)
      Text(`${this.rankingPercent(this.categoryAt(index))}%`)
        .fontSize(12)
        .fontColor($r('app.color.color_text_secondary'))
        .width(32)
        .textAlign(TextAlign.End)
    }
    .width('100%')
      .height(40)
      .alignItems(VerticalAlign.Center)
  }

  @Builder
  RankingCard() {
    Column() {
      Row() {
        Row()
          .width(4)
          .height(20)
          .borderRadius(2)
          .backgroundColor($r('app.color.color_primary'))
          .margin({ right: 8 })
        Text(this.rankingCardTitle())
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_deep'))
        Blank()
        Text('查看全部')
          .fontSize(12)
          .fontColor($r('app.color.color_text_secondary'))
          .onClick(() => {
            if (this.isIncomeMode()) {
              this.showAllRanking = true
            } else if (this.statMode === 'year') {
              this.showAllRanking = true
            } else if (this.navStack) {
              AppStorage.setOrCreate<string>('statisticsRankingMonth', this.currentMonth)
              this.navStack.pushPathByName('expenseRankingAll', null)
            } else {
              this.showAllRanking = true
            }
          })
        Image($rawfile('icon_chevron_right.svg'))
          .width(16)
          .height(16)
          .fillColor($r('app.color.color_text_secondary'))
          .margin({ left: 5 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 8 })

      ForEach(this.rankingIndexes(), (index: number) => {
        this.RankingRow(index)
      }, (index: number) => index.toString())
    }
    .width('calc(100% - 36vp)')
    .padding({ left: 12, right: 12, top: 12, bottom: 10 })
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(20)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .shadow({ radius: 14, color: $r('app.color.color_shadow_blue_09'), offsetX: 0, offsetY: 6 })
    .margin({ left: 18, right: 18, top: 6, bottom: 12 })
  }

  @Builder
  FilterModeButton(label: string, mode: string) {
    Text(label)
      .fontSize(15)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.pendingStatMode === mode ? $r('app.color.color_white') : $r('app.color.color_text_secondary'))
      .height(34)
      .layoutWeight(1)
      .textAlign(TextAlign.Center)
      .borderRadius(17)
      .backgroundColor(this.pendingStatMode === mode ? $r('app.color.color_primary') : Color.Transparent)
      .onClick(() => {
        this.pendingStatMode = mode
      })
  }

  @Builder
  MonthPickerTile(month: number) {
    Text(month.toString() + '月')
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.pendingMonth === month ? $r('app.color.color_white') : $r('app.color.color_text_secondary'))
      .height(36)
      .width('100%')
      .textAlign(TextAlign.Center)
      .borderRadius(12)
      .backgroundColor(this.pendingMonth === month ? $r('app.color.color_primary') : $r('app.color.color_surface'))
      .border({
        width: 1,
        color: this.pendingMonth === month ? $r('app.color.color_primary') : $r('app.color.color_divider')
      })
      .onClick(() => {
        this.pendingMonth = month
      })
  }

  @Builder
  FilterSheet() {
    Stack({ alignContent: Alignment.Bottom }) {
      Row()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .onClick(() => {
          this.showFilterSheet = false
        })

      Column() {
        Row()
          .width(42)
          .height(5)
          .borderRadius(3)
          .backgroundColor($r('app.color.color_divider'))
          .margin({ top: 12, bottom: 18 })

        Text('统计设置')
          .fontSize(24)
          .fontWeight(FontWeight.Bolder)
          .fontColor($r('app.color.color_text_deep'))
          .width('100%')
          .textAlign(TextAlign.Start)

        Text(this.pendingStatMode === 'year' ? '查看某一年度的收入、支出、结余与预算执行情况' : '选择某个月份，页面卡片与趋势图会同步刷新')
          .fontSize(13)
          .fontColor($r('app.color.color_text_secondary'))
          .width('100%')
          .margin({ top: 8, bottom: 16 })

        Column() {
          Row() {
            Text('统计维度')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.color_text_deep'))
            Blank()
            Row() {
              this.FilterModeButton('月度', 'month')
              this.FilterModeButton('年度', 'year')
            }
            .width(150)
            .height(38)
            .padding(4)
            .borderRadius(19)
            .backgroundColor($r('app.color.color_surface'))
            .border({ width: 1, color: $r('app.color.color_divider') })
          }
          .width('100%')
          .height(48)
          .padding({ left: 4, right: 4 })

          Divider().color($r('app.color.color_divider'))

          Row() {
            Text(this.pendingStatMode === 'year' ? '统计年份' : '时间选择')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.color_text_deep'))
            Blank()
            Row({ space: 14 }) {
              Text('‹')
                .fontSize(24)
                .fontColor($r('app.color.color_primary'))
                .onClick(() => {
                  this.changePendingYear(-1)
                })
              Text(this.pendingYear + '年')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.color_text_deep'))
              Text('›')
                .fontSize(24)
                .fontColor($r('app.color.color_primary'))
                .onClick(() => {
                  this.changePendingYear(1)
                })
            }
          }
          .width('100%')
          .height(48)
          .padding({ left: 4, right: 4 })

          if (this.pendingStatMode === 'month') {
            Divider().color($r('app.color.color_divider'))
            Row() {
              Text('统计月份')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.color_text_deep'))
              Blank()
              Text(this.pendingMonth.toString() + '月')
                .fontSize(14)
                .fontColor($r('app.color.color_text_secondary'))
            }
            .width('100%')
            .height(44)
            .padding({ left: 4, right: 4 })

            Grid() {
              ForEach(this.monthIndexes(), (month: number) => {
                GridItem() {
                  this.MonthPickerTile(month)
                }
              }, (month: number) => month.toString())
            }
            .columnsTemplate('1fr 1fr 1fr 1fr')
            .columnsGap(8)
            .rowsGap(8)
            .width('100%')
            .height(124)
          }

          Divider().color($r('app.color.color_divider'))

          Row() {
            Text('趋势展示')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.color_text_deep'))
            Blank()
            Text(this.pendingStatMode === 'year' ? '年内月度趋势' : '默认近七天')
              .fontSize(14)
              .fontColor($r('app.color.color_text_secondary'))
          }
          .width('100%')
          .height(48)
          .padding({ left: 4, right: 4 })

          Row({ space: 8 }) {
            Image($rawfile('icon_list.svg'))
              .width(18)
              .height(18)
              .fillColor($r('app.color.color_primary'))
            Text(this.pendingStatMode === 'year' ? '切换年度后，趋势图显示该年 1-12 月走势。' : '月度模式下，趋势图可在按日、近七天和本月之间切换。')
              .fontSize(12)
              .fontColor($r('app.color.color_text_secondary'))
              .layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 12, bottom: 12 })
          .borderRadius(14)
          .backgroundColor($r('app.color.color_soft_blue'))
          .margin({ top: 12 })
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 10, bottom: 12 })
        .backgroundColor($r('app.color.color_card_overlay'))
        .borderRadius(18)
        .border({ width: 1, color: $r('app.color.color_divider') })

        Row({ space: 16 }) {
          Button('取消')
            .height(48)
            .layoutWeight(1)
            .fontSize(16)
            .fontColor($r('app.color.color_primary'))
            .backgroundColor(Color.Transparent)
            .border({ width: 1, color: $r('app.color.color_primary') })
            .borderRadius(18)
            .onClick(() => {
              this.showFilterSheet = false
            })
          Button('确认')
            .height(48)
            .layoutWeight(1)
            .fontSize(16)
            .fontColor($r('app.color.color_white'))
            .backgroundColor($r('app.color.color_primary'))
            .borderRadius(18)
            .onClick(() => {
              this.confirmFilterSheet()
            })
        }
        .width('100%')
        .margin({ top: 14 })
      }
      .width('100%')
      .height(this.pendingStatMode === 'month' ? 570 : 456)
      .padding({ left: 22, right: 22, bottom: 16 })
      .backgroundColor($r('app.color.color_surface'))
      .borderRadius({ topLeft: 28, topRight: 28 })
    }
    .width('100%')
    .height('100%')
    .transition(
      TransitionEffect.asymmetric(
        TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 380 }))
          .animation({ duration: 280, curve: Curve.EaseOut }),
        TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 380 }))
          .animation({ duration: 220, curve: Curve.EaseIn })
      )
    )
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      WaterPageBg()

      Column() {
        this.Header()

        Scroll() {
          Column() {
            this.MetricModeSwitch()
            this.SummaryPanel()
            if (!this.isIncomeMode()) {
              this.BudgetOverviewCard()
            }
            this.TrendCard()
            this.CategoryCard()
          }
          .width('100%')
          .translate({ x: this.slideOffsetX })
          .gesture(
            PanGesture({ direction: PanDirection.Horizontal, distance: 5 })
              .onActionUpdate((event: GestureEvent) => {
                if (this.trendChartGestureActive) {
                  return
                }
                if (event) {
                  this.slideOffsetX = event.offsetX
                }
              })
              .onActionEnd((event: GestureEvent) => {
                if (this.trendChartGestureActive) {
                  this.slideOffsetX = 0
                  return
                }
                if (!event) {
                  this.slideOffsetX = 0
                  return
                }
                if (event.offsetX > 80) {
                  this.doPeriodSwitch(1)
                } else if (event.offsetX < -80) {
                  this.doPeriodSwitch(-1)
                } else {
                  this.getUIContext().animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
                    this.slideOffsetX = 0
                  })
                }
              })
          )
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(Color.Transparent)

      if (this.showFilterSheet) {
        this.FilterSheet()
      }
    }
    .width('100%')
    .height('100%')
  }
}
