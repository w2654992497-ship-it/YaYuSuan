import { CategoryRecord, getUnifiedCategoryColor } from '../model/Category'

@Component
export struct CategoryGrid {
  @Prop billType: 'income' | 'expense' = 'expense'
  @Prop selected: string = ''
  @Prop categories: CategoryRecord[] = []
  onSelect: (category: string) => void = () => {}

  private renderKey(item: CategoryRecord): string {
    return `${item.id}_${item.name}_${item.icon}_${item.color}_${item.sort_order}`
  }

  build() {
    Grid() {
      ForEach(this.categories, (item: CategoryRecord) => {
        GridItem() {
          Column() {
            Column() {
              Image($rawfile(item.icon + '.svg'))
                .width(22).height(22)
                .fillColor(this.selected === item.name ? $r('app.color.color_surface') : getUnifiedCategoryColor(item.name))
            }
            .width(44).height(44).borderRadius(22)
            .backgroundColor(this.selected === item.name ? getUnifiedCategoryColor(item.name) : '#F6F9FF')
            .border({ width: 1, color: this.selected === item.name ? getUnifiedCategoryColor(item.name) : '#E2E8F0' })
            .alignItems(HorizontalAlign.Center)
            .justifyContent(FlexAlign.Center)
            .animation({ duration: 200, curve: Curve.EaseOut })

            Text(item.name)
              .fontSize(11)
              .fontColor(this.selected === item.name ? $r('app.color.color_text_primary') : $r('app.color.color_text_secondary'))
              .fontWeight(this.selected === item.name ? FontWeight.Medium : FontWeight.Normal)
              .margin({ top: 4 })
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })
          .alignItems(HorizontalAlign.Center)
          .onClick(() => { this.onSelect(item.name) })
        }
        .padding({ left: 4, right: 4 })
      }, (item: CategoryRecord) => this.renderKey(item))
    }
    .columnsTemplate('1fr 1fr 1fr 1fr')
    .width('100%')
    .padding({ left: 8, right: 8 })
  }
}

