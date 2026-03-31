import { CategoryInfo, EXPENSE_CATEGORIES, INCOME_CATEGORIES } from '../model/Category'

@Component
export struct CategoryGrid {
  @Prop billType: 'income' | 'expense' = 'expense'
  @Prop selected: string = ''
  onSelect: (category: string) => void = () => {}

  private getCategories(): CategoryInfo[] {
    return this.billType === 'income' ? INCOME_CATEGORIES : EXPENSE_CATEGORIES
  }

  build() {
    Grid() {
      ForEach(this.getCategories(), (item: CategoryInfo) => {
        GridItem() {
          Column() {
            // 图标圆圈
            Column() {
              Image($rawfile(item.icon + '.svg'))
                .width(24)
                .height(24)
                .fillColor(this.selected === item.name ? '#FFFFFF' : item.color)
            }
            .width(50)
            .height(50)
            .borderRadius(25)
            .backgroundColor(
              this.selected === item.name
                ? item.color
                : item.color + '22'   // 13% 透明度背景
            )
            .alignItems(HorizontalAlign.Center)
            .justifyContent(FlexAlign.Center)
            .margin({ bottom: 6 })
            .shadow(this.selected === item.name
              ? { radius: 8, color: item.color + '55', offsetX: 0, offsetY: 3 }
              : { radius: 0, color: '#00000000', offsetX: 0, offsetY: 0 })

            // 分类名
            Text(item.name)
              .fontSize(11)
              .fontColor(this.selected === item.name ? item.color : '#666666')
              .fontWeight(this.selected === item.name ? FontWeight.Medium : FontWeight.Normal)
          }
          .width('100%')
          .padding({ top: 10, bottom: 10 })
          .alignItems(HorizontalAlign.Center)
          .borderRadius(10)
          .backgroundColor(this.selected === item.name ? item.color + '10' : Color.Transparent)
          .border(this.selected === item.name
            ? { width: 1.5, color: item.color + '80' }
            : { width: 0 })
          .onClick(() => {
            this.onSelect(item.name)
          })
        }
        .padding(4)
      })
    }
    .columnsTemplate('1fr 1fr 1fr 1fr')
    .width('100%')
    .padding({ left: 12, right: 12 })
  }
}
