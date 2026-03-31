import { CategoryInfo, EXPENSE_CATEGORIES, INCOME_CATEGORIES } from '../model/Category'

@Component
export struct CategoryGrid {
  @Prop billType: 'income' | 'expense' = 'expense'
  @Prop selected: string = ''
  onSelect: (category: string) => void = () => {}

  private getCategories(): CategoryInfo[] {
    if (this.billType === 'income') {
      return INCOME_CATEGORIES
    }
    return EXPENSE_CATEGORIES
  }

  build() {
    Grid() {
      ForEach(this.getCategories(), (item: CategoryInfo) => {
        GridItem() {
          Column() {
            Text(item.emoji)
              .fontSize(24)
              .margin({ bottom: 4 })
            Text(item.name)
              .fontSize(12)
              .fontColor('#212121') // color_text_primary
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })
          .alignItems(HorizontalAlign.Center)
          .backgroundColor(this.selected === item.name ? '#1A1976D2' : '#FFFFFF')
          .borderRadius(8)
          .border(this.selected === item.name
            ? { width: 2, color: '#1976D2' }
            : { width: 1, color: '#E0E0E0' })
          .onClick(() => {
            this.onSelect(item.name)
          })
        }
        .padding(4)
      })
    }
    .columnsTemplate('1fr 1fr 1fr 1fr')
    .width('100%')
    .padding({ left: 16, right: 16 })
  }
}
