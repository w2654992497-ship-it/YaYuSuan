import { CategoryRecord, getCategoryInfo, getUnifiedCategoryColor } from '../../model/Category'
import { PeriodRule } from '../../model/PeriodRule'
import { AmountUtil } from '../../utils/AmountUtil'

@Component
export struct SettingsPeriodPage {
  @Prop sbHeight: number
  @Prop selectedPeriodType: string = 'expense'
  @Prop periodRules: PeriodRule[] = []
  @Prop periodCategories: CategoryRecord[] = []
  @Prop showPeriodForm: boolean = false
  @Prop periodTitle: string = ''
  @Prop periodAmount: string = ''
  @Prop periodCategory: string = ''
  @Prop periodRemark: string = ''
  @Prop periodDay: string = '1'
  @Prop periodCycle: string = 'monthly'
  private periodScroller: Scroller = new Scroller()
  onBack: () => void = (): void => {}
  onSelectType: (periodType: string) => void = (periodType: string): void => {}
  onBeginAdd: () => void = (): void => {}
  onCloseForm: () => void = (): void => {}
  onToggleRule: (rule: PeriodRule) => void = (rule: PeriodRule): void => {}
  onDeleteRule: (rule: PeriodRule) => void = (rule: PeriodRule): void => {}
  onTitleChange: (value: string) => void = (value: string): void => {}
  onAmountChange: (value: string) => void = (value: string): void => {}
  onCategoryChange: (value: string) => void = (value: string): void => {}
  onRemarkChange: (value: string) => void = (value: string): void => {}
  onCycleChange: (value: string) => void = (value: string): void => {}
  onDayChange: (value: string) => void = (value: string): void => {}
  onSaveRule: () => void = (): void => {}
  onUnsupportedWeekly: () => void = (): void => {}
  onUnsupportedCustom: () => void = (): void => {}

  private scrollToTop(): void {
    try {
      this.periodScroller.scrollTo({ xOffset: 0, yOffset: 0 })
    } catch (err) {
    }
  }

  private nextDayText(): string {
    const dayText = this.periodDay.length > 0 ? this.periodDay : '1'
    if (this.periodCycle === 'yearly') {
      return `每年 ${new Date().getMonth() + 1} 月 ${dayText} 日`
    }
    return `每月 ${dayText} 日`
  }

  @Builder
  Header() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Row() {
        Image($rawfile('icon_chevron_left.svg'))
          .width(26)
          .height(26)
          .fillColor($r('app.color.color_text_primary'))
          .onClick(() => {
            this.onBack()
          })
        Text('周期记账')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Blank().width(26).height(26)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: this.sbHeight + 8, bottom: 9 })
      .alignItems(VerticalAlign.Center)

      Image($rawfile('illustration_fish_bowl.png'))
        .width(86)
        .height(66)
        .opacity(0.9)
        .margin({ top: this.sbHeight + 2, right: 8 })
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .margin({ bottom: 2 })
  }

  @Builder
  SwitchPill(enabled: boolean) {
    Row() {
      Circle()
        .width(16)
        .height(16)
        .fill($r('app.color.color_white'))
        .margin({ left: 2, right: 2 })
    }
    .width(36)
    .height(20)
    .borderRadius(10)
    .backgroundColor(enabled ? $r('app.color.color_primary') : $r('app.color.color_track'))
    .justifyContent(enabled ? FlexAlign.End : FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  PeriodInfoCard() {
    Row() {
      Column() {
        Image($rawfile('icon_calendar.svg'))
          .width(30)
          .height(30)
          .fillColor($r('app.color.color_primary'))
      }
      .width(56)
      .height(56)
      .borderRadius(28)
      .backgroundColor($r('app.color.color_soft_blue'))
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .margin({ right: 12 })

      Column() {
        Text('关于周期记账')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_primary'))
        Text('周期记账可自动按设定周期记录固定发生的收支，省时又省心。')
          .fontSize(13)
          .fontColor($r('app.color.color_text_secondary'))
          .lineHeight(20)
          .margin({ top: 5 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('calc(100% - 32vp)')
    .padding({ left: 14, right: 14, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.color_surface'))
    .borderRadius(18)
    .shadow({ radius: 8, color: $r('app.color.color_shadow_blue_08'), offsetY: 3 })
    .margin({ left: 16, right: 16, bottom: 10 })
  }

  @Builder
  PeriodTabs() {
    Row() {
      Button('支出')
        .layoutWeight(1)
        .height(38)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.selectedPeriodType === 'expense' ? $r('app.color.color_white') : $r('app.color.color_text_primary'))
        .backgroundColor(this.selectedPeriodType === 'expense' ? $r('app.color.color_primary') : Color.Transparent)
        .borderRadius(13)
        .onClick(() => {
          this.onSelectType('expense')
          this.scrollToTop()
        })
      Button('收入')
        .layoutWeight(1)
        .height(38)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.selectedPeriodType === 'income' ? $r('app.color.color_white') : $r('app.color.color_text_primary'))
        .backgroundColor(this.selectedPeriodType === 'income' ? $r('app.color.color_primary') : Color.Transparent)
        .borderRadius(13)
        .onClick(() => {
          this.onSelectType('income')
          this.scrollToTop()
        })
    }
    .width('calc(100% - 32vp)')
    .height(46)
    .padding(4)
    .backgroundColor($r('app.color.color_surface'))
    .borderRadius(16)
    .shadow({ radius: 8, color: $r('app.color.color_shadow_blue_08'), offsetY: 3 })
    .margin({ left: 16, right: 16, bottom: 10 })
  }

  @Builder
  PeriodRow(rule: PeriodRule) {
    Row() {
      Column() {
        Image($rawfile(getCategoryInfo(rule.category).icon + '.svg'))
          .width(20)
          .height(20)
          .fillColor($r('app.color.color_white'))
      }
      .width(42)
      .height(42)
      .borderRadius(21)
      .backgroundColor(getUnifiedCategoryColor(rule.category))
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .margin({ right: 10 })

      Column() {
        Text(rule.title)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_primary'))
        Row() {
          Text(rule.cycle === 'monthly' ? `每月 ${rule.day}日` : `每年 ${rule.month}月${rule.day}日`)
            .fontSize(12)
            .fontColor($r('app.color.color_text_secondary'))
          Text(rule.cycle === 'monthly' ? '每月' : '每年')
            .fontSize(12)
            .fontColor($r('app.color.color_text_secondary'))
            .margin({ left: 10 })
        }
        .margin({ top: 4 })
        Text(rule.category)
          .fontSize(11)
          .fontColor($r('app.color.color_text_secondary'))
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor($r('app.color.color_bg'))
          .borderRadius(6)
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Column() {
        Text(`${rule.type === 'income' ? '+' : '-'}${AmountUtil.fen2Display(rule.amount)}`)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(rule.type === 'income' ? $r('app.color.color_primary') : $r('app.color.color_accent'))
        Text(`下次记账日 ${rule.nextDate}`)
          .fontSize(10)
          .fontColor($r('app.color.color_text_secondary'))
          .margin({ top: 6 })
      }
      .alignItems(HorizontalAlign.End)
      .margin({ right: 6 })

      Column() {
        Row() {
          this.SwitchPill(rule.enabled === 1)
        }
        .onClick(() => {
          this.onToggleRule(rule)
        })
        Text('删除')
          .fontSize(10)
          .fontColor($r('app.color.color_expense'))
          .margin({ top: 6 })
          .onClick(() => {
            this.onDeleteRule(rule)
          })
      }
    }
    .width('100%')
    .height(82)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  PeriodList() {
    Column() {
      if (this.periodRules.length === 0) {
        Text('还没有周期账单')
          .fontSize(14)
          .fontColor($r('app.color.color_text_secondary'))
          .width('100%')
          .height(72)
          .textAlign(TextAlign.Center)
      } else {
        ForEach(this.periodRules, (rule: PeriodRule, index: number) => {
          this.PeriodRow(rule)
          if (index < this.periodRules.length - 1) {
            Divider().color($r('app.color.color_divider')).margin({ left: 52, right: 8 })
          }
        }, (rule: PeriodRule) => rule.id.toString())
      }
    }
    .width('calc(100% - 32vp)')
    .padding({ left: 12, right: 10, top: 6, bottom: 6 })
    .backgroundColor($r('app.color.color_surface'))
    .borderRadius(18)
    .shadow({ radius: 8, color: $r('app.color.color_shadow_blue_08'), offsetY: 3 })
    .margin({ left: 16, right: 16, bottom: 12 })
  }

  @Builder
  CategoryPicker() {
    Row() {
      Text('分类')
        .width(56)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.color_text_primary'))
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.periodCategories, (cat: CategoryRecord) => {
            Column() {
              Image($rawfile(cat.icon + '.svg'))
                .width(20)
                .height(20)
                .fillColor(this.periodCategory === cat.name ? $r('app.color.color_primary') : $r('app.color.color_text_secondary'))
              Text(cat.name)
                .fontSize(12)
                .fontColor($r('app.color.color_text_primary'))
                .margin({ top: 2 })
            }
            .width(58)
            .height(58)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .backgroundColor(this.periodCategory === cat.name ? '#E6FAFA' : $r('app.color.color_bg'))
            .borderRadius(12)
            .border({
              width: this.periodCategory === cat.name ? 1 : 0,
              color: this.periodCategory === cat.name ? $r('app.color.color_primary') : Color.Transparent
            })
            .onClick(() => {
              this.onCategoryChange(cat.name)
            })
          }, (cat: CategoryRecord) => cat.id.toString())
        }
        .padding({ right: 4 })
      }
      .layoutWeight(1)
      .height(62)
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .margin({ bottom: 12 })
  }

  @Builder
  PeriodForm() {
    Column() {
      Row()
        .width(42)
        .height(5)
        .borderRadius(3)
        .backgroundColor($r('app.color.color_track'))
        .margin({ top: 10, bottom: 12 })

      Row() {
        Text('新增周期账单')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_primary'))
          .layoutWeight(1)
        Button('×')
          .width(34)
          .height(34)
          .fontSize(22)
          .fontColor($r('app.color.color_text_primary'))
          .backgroundColor($r('app.color.color_bg'))
          .borderRadius(17)
          .onClick(() => {
            this.onCloseForm()
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 14 })

      Scroll() {
        Column() {
          Row() {
            Text('名称')
              .width(56)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.color_text_primary'))
            TextInput({ placeholder: '例如：房租', text: this.periodTitle })
              .layoutWeight(1)
              .height(48)
              .fontSize(15)
              .backgroundColor('#F5F8FC')
              .borderRadius(12)
              .padding({ left: 14, right: 14 })
              .onChange((value: string) => {
                this.onTitleChange(value)
              })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .margin({ bottom: 12 })

          Row() {
            Text('金额')
              .width(56)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.color_text_primary'))
            Row() {
              Text('¥')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.color_text_primary'))
                .margin({ left: 12, right: 8 })
              TextInput({ placeholder: '请输入金额', text: this.periodAmount })
                .layoutWeight(1)
                .height(48)
                .fontSize(15)
                .type(InputType.NUMBER_DECIMAL)
                .backgroundColor(Color.Transparent)
                .padding({ left: 0, right: 12 })
                .onChange((value: string) => {
                  this.onAmountChange(value)
                })
            }
            .layoutWeight(1)
            .height(48)
            .backgroundColor('#F5F8FC')
            .borderRadius(12)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .margin({ bottom: 12 })

          this.CategoryPicker()

          Row() {
            Text('周期')
              .width(56)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.color_text_primary'))
            Row({ space: 10 }) {
              Text('每周')
                .layoutWeight(1)
                .height(42)
                .fontSize(14)
                .textAlign(TextAlign.Center)
                .fontColor($r('app.color.color_text_primary'))
                .backgroundColor($r('app.color.color_bg'))
                .borderRadius(12)
                .onClick(() => {
                  this.onUnsupportedWeekly()
                })
              Text('每月')
                .layoutWeight(1)
                .height(42)
                .fontSize(14)
                .textAlign(TextAlign.Center)
                .fontColor(this.periodCycle === 'monthly' ? $r('app.color.color_white') : $r('app.color.color_text_primary'))
                .backgroundColor(this.periodCycle === 'monthly' ? $r('app.color.color_primary') : $r('app.color.color_bg'))
                .borderRadius(12)
                .onClick(() => {
                  this.onCycleChange('monthly')
                })
              Text('每年')
                .layoutWeight(1)
                .height(42)
                .fontSize(14)
                .textAlign(TextAlign.Center)
                .fontColor(this.periodCycle === 'yearly' ? $r('app.color.color_white') : $r('app.color.color_text_primary'))
                .backgroundColor(this.periodCycle === 'yearly' ? $r('app.color.color_primary') : $r('app.color.color_bg'))
                .borderRadius(12)
                .onClick(() => {
                  this.onCycleChange('yearly')
                })
              Text('自定义')
                .layoutWeight(1)
                .height(42)
                .fontSize(14)
                .textAlign(TextAlign.Center)
                .fontColor($r('app.color.color_text_primary'))
                .backgroundColor($r('app.color.color_bg'))
                .borderRadius(12)
                .onClick(() => {
                  this.onUnsupportedCustom()
                })
            }
            .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .margin({ bottom: 12 })

          Row() {
            Column() {
              Text('记账日期')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.color_text_primary'))
              Text('到账/扣款日')
                .fontSize(11)
                .fontColor($r('app.color.color_text_secondary'))
                .margin({ top: 4 })
            }
            .width(56)
            .alignItems(HorizontalAlign.Start)
            Row() {
              Image($rawfile('icon_calendar.svg'))
                .width(20)
                .height(20)
                .fillColor($r('app.color.color_primary'))
                .margin({ left: 14, right: 10 })
              Text(this.nextDayText())
                .layoutWeight(1)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.color_text_primary'))
              Text('›')
                .fontSize(26)
                .fontColor($r('app.color.color_text_secondary'))
                .margin({ right: 12 })
            }
            .layoutWeight(1)
            .height(48)
            .backgroundColor('#F5F8FC')
            .borderRadius(12)
            .onClick(() => {
              let day = parseInt(this.periodDay, 10)
              if (isNaN(day) || day >= 31) {
                this.onDayChange('1')
              } else {
                this.onDayChange((day + 1).toString())
              }
            })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .margin({ bottom: 12 })

          Row() {
            Text('备注')
              .width(56)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.color_text_primary'))
            TextInput({ placeholder: '添加备注（选填）', text: this.periodRemark })
              .layoutWeight(1)
              .height(48)
              .fontSize(15)
              .backgroundColor('#F5F8FC')
              .borderRadius(12)
              .padding({ left: 14, right: 14 })
              .onChange((value: string) => {
                this.onRemarkChange(value)
              })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .margin({ bottom: 18 })

          Row({ space: 16 }) {
            Button('取消')
              .layoutWeight(1)
              .height(48)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.color_text_primary'))
              .backgroundColor($r('app.color.color_bg'))
              .borderRadius(24)
              .onClick(() => {
                this.onCloseForm()
              })
            Button('保存')
              .layoutWeight(1)
              .height(48)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.color_white'))
              .backgroundColor($r('app.color.color_primary'))
              .borderRadius(24)
              .onClick(() => {
                this.onSaveRule()
              })
          }
          .width('100%')
          .margin({ bottom: 8 })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('70%')
    .padding({ left: 20, right: 20, bottom: 20 })
    .backgroundColor($r('app.color.color_surface'))
    .borderRadius({ topLeft: 26, topRight: 26 })
    .shadow({ radius: 18, color: $r('app.color.color_shadow_blue_08'), offsetY: -4 })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        this.Header()
        Scroll(this.periodScroller) {
          Column() {
            this.PeriodInfoCard()
            this.PeriodTabs()
            this.PeriodList()
          }
          .width('100%')
          .constraintSize({ minHeight: '100%' })
          .alignItems(HorizontalAlign.Center)
          .justifyContent(FlexAlign.Start)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .onAppear(() => {
          this.scrollToTop()
        })

        Button('新增周期账单')
          .width('calc(100% - 64vp)')
          .height(46)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_white'))
          .backgroundColor($r('app.color.color_primary'))
          .borderRadius(23)
          .margin({ left: 32, right: 32, top: 6, bottom: 18 })
          .onClick(() => {
            this.onBeginAdd()
          })
      }
      .width('100%')
      .height('100%')

      if (this.showPeriodForm) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#22000000')
          .onClick(() => {
            this.onCloseForm()
          })
        this.PeriodForm()
      }
    }
    .width('100%')
    .height('100%')
  }
}
