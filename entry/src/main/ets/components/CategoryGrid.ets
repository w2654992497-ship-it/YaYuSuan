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
            Column() {
              Image($rawfile(item.icon + '.svg'))
                .width(20)
                .height(20)
                .fillColor(this.selected === item.name ? '#1976D2' : '#757575')
            }
            .width(40)
            .height(40)
            .borderRadius(20)
            .backgroundColor(this.selected === item.name ? '#E3F2FD' : '#F5F5F5')
            .alignItems(HorizontalAlign.Center)
            .justifyContent(FlexAlign.Center)
            .border(this.selected === item.name
              ? { width: 1.5, color: '#1976D2' }
              : { width: 0 })

            Text(item.name)
              .fontSize(11)
              .fontColor(this.selected === item.name ? '#1976D2' : '#757575')
              .fontWeight(this.selected === item.name ? FontWeight.Medium : FontWeight.Normal)
              .margin({ top: 4 })
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })
          .alignItems(HorizontalAlign.Center)
          .onClick(() => {
            this.onSelect(item.name)
          })
        }
        .padding({ left: 4, right: 4 })
      })
    }
    .columnsTemplate('1fr 1fr 1fr 1fr')
    .width('100%')
    .padding({ left: 8, right: 8 })
  }
}
