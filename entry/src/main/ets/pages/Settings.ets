import { preferences } from '@kit.ArkData'
import { fileIo } from '@kit.CoreFileKit'
import picker from '@ohos.file.picker'
import { CategoryRecord } from '../model/Category'
import { CategoryDao } from '../database/CategoryDao'
import { BillDao } from '../database/BillDao'
import { FilterOptions } from '../model/FilterOptions'
import { Bill } from '../model/Bill'
import { AmountUtil } from '../utils/AmountUtil'
import { LogUtils } from '../utils/LogUtils'
import { CategoryManagePage } from './CategoryManage'

const PREF_NAME = 'yayusuan_budget'

@Component
export struct SettingsPage {
  @State expenseCategories: CategoryRecord[] = []
  @State budgetValues: string[] = []
  @State showCategoryManage: boolean = false

  aboutToAppear(): void {
    this.loadBudgets()
  }

  private async loadBudgets(): Promise<void> {
    try {
      this.expenseCategories = await CategoryDao.getInstance().queryByType('expense')
      const pref = await preferences.getPreferences(this.getUIContext().getHostContext()!, { name: PREF_NAME })
      const vals: string[] = []
      for (const cat of this.expenseCategories) {
        const fen = await pref.get(`budget_id_${cat.id}`, 0) as number
        vals.push(fen > 0 ? AmountUtil.fen2Display(fen) : '')
      }
      this.budgetValues = vals
    } catch (err) {
      LogUtils.error('Settings', 'loadBudgets: %{public}s', JSON.stringify(err))
    }
  }

  private async saveBudgets(): Promise<void> {
    try {
      const pref = await preferences.getPreferences(this.getUIContext().getHostContext()!, { name: PREF_NAME })
      for (let i = 0; i < this.expenseCategories.length; i++) {
        const cat = this.expenseCategories[i]
        const fen = this.budgetValues[i] && this.budgetValues[i].length > 0
          ? AmountUtil.yuan2Fen(this.budgetValues[i])
          : 0
        await pref.put(`budget_id_${cat.id}`, fen)
      }
      await pref.flush()
      this.getUIContext().getPromptAction().showToast({ message: '预算设置已保存' })
    } catch (err) {
      try { this.getUIContext().getPromptAction().showToast({ message: '保存失败，请重试' }) } catch (_e) {}
      LogUtils.error('Settings', 'saveBudgets: %{public}s', JSON.stringify(err))
    }
  }

  private async exportCSV(): Promise<void> {
    try {
      const filter: FilterOptions = { month: '', type: 'all', category: '' }
      const bills: Bill[] = await BillDao.getInstance().queryByFilter(filter)
      if (bills.length === 0) {
        this.getUIContext().getPromptAction().showToast({ message: '暂无账单数据可导出' })
        return
      }

      const bom = '\uFEFF'
      const header = '日期,类型,分类,金额(元),备注\n'
      const rows = bills.map((b: Bill): string => {
        const typeLabel = b.type === 'income' ? '收入' : '支出'
        const amount = AmountUtil.fen2Display(b.amount)
        const remark = b.remark.replace(/,/g, '，')
        return `${b.date},${typeLabel},${b.category},${amount},${remark}`
      }).join('\n')
      const csvContent = bom + header + rows

      const saveOptions = new picker.DocumentSaveOptions()
      saveOptions.newFileNames = ['鸭鱼算账单.csv']
      const docPicker = new picker.DocumentViewPicker(this.getUIContext().getHostContext()!)
      const uriArr = await docPicker.save(saveOptions)
      if (!uriArr || uriArr.length === 0) return

      const file = await fileIo.open(uriArr[0], fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC)
      await fileIo.write(file.fd, csvContent)
      await fileIo.close(file.fd)

      this.getUIContext().getPromptAction().showToast({ message: `已导出 ${bills.length} 条账单` })
    } catch (err) {
      const errStr = JSON.stringify(err)
      if (errStr.includes('cancel') || errStr.includes('Cancel')) return
      try { this.getUIContext().getPromptAction().showToast({ message: '导出失败，请重试' }) } catch (_e) {}
      LogUtils.error('Settings', 'exportCSV: %{public}s', errStr)
    }
  }

  private updateBudget(index: number, value: string): void {
    const newVals: string[] = []
    for (let i = 0; i < this.budgetValues.length; i++) {
      newVals.push(i === index ? value : this.budgetValues[i])
    }
    this.budgetValues = newVals
  }

  build() {
    Column() {
      if (this.showCategoryManage) {
        // 分类管理子页
        CategoryManagePage({
          onBack: () => {
            this.showCategoryManage = false
            this.loadBudgets()
          }
        })
      } else {
        // 设置主页
        Column() {
          Row() {
            Text('设置')
              .fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.color_text_primary'))
          }
          .width('100%').justifyContent(FlexAlign.Start).padding(24)

          Scroll() {
            Column() {
              // ── 分类管理入口 ──
              Row() {
                Image($rawfile('icon_list.svg'))
                  .width(22).height(22)
                  .fillColor($r('app.color.color_primary'))
                  .margin({ right: 14 })
                Text('分类管理')
                  .fontSize(16).fontColor($r('app.color.color_text_primary')).layoutWeight(1)
                Text('自定义分类、排序')
                  .fontSize(12).fontColor($r('app.color.color_text_secondary')).margin({ right: 8 })
                Image($rawfile('icon_chevron_right.svg'))
                  .width(16).height(16)
                  .fillColor($r('app.color.color_text_secondary'))
              }
              .width('calc(100% - 32vp)')
              .padding(16)
              .backgroundColor($r('app.color.color_surface'))
              .borderRadius(16)
              .margin({ left: 16, right: 16, bottom: 16 })
              .shadow({ radius: 8, color: 'rgba(0,0,0,0.03)', offsetY: 2 })
              .onClick(() => { this.showCategoryManage = true })

              // ── 预算设置 ──
              if (this.expenseCategories.length > 0) {
                Text('月度预算')
                  .fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.color_text_primary'))
                  .width('100%').padding({ left: 20, bottom: 8 })

                Column() {
                  ForEach(this.expenseCategories, (cat: CategoryRecord, index: number) => {
                    Column() {
                      Row() {
                        Column() {
                          Image($rawfile(cat.icon + '.svg'))
                            .width(20).height(20).fillColor($r('app.color.color_surface'))
                        }
                        .width(40).height(40).borderRadius(20)
                        .backgroundColor(cat.color)
                        .alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center)
                        .margin({ right: 14 })

                        Text(cat.name)
                          .fontSize(15).fontColor($r('app.color.color_text_primary')).layoutWeight(1)

                        Row() {
                          Text('¥').fontSize(14).fontColor($r('app.color.color_text_secondary')).margin({ right: 2 })
                          TextInput({ placeholder: '不限', text: this.budgetValues[index] ?? '' })
                            .fontSize(14).fontColor($r('app.color.color_text_primary'))
                            .placeholderColor($r('app.color.color_text_secondary'))
                            .backgroundColor(Color.Transparent)
                            .border({ width: 0 }).borderRadius(0)
                            .padding({ top: 0, bottom: 0, left: 0, right: 0 })
                            .type(InputType.NUMBER_DECIMAL)
                            .width(80).textAlign(TextAlign.End)
                            .onChange((val: string) => {
                              let filtered = val.replace(/[^0-9.]/g, '')
                              const dotIdx = filtered.indexOf('.')
                              if (dotIdx !== -1) {
                                const after = filtered.substring(dotIdx + 1).replace(/\./g, '')
                                filtered = filtered.substring(0, dotIdx + 1) + after.substring(0, 2)
                              }
                              if (filtered.length > 1 && filtered[0] === '0' && filtered[1] !== '.') {
                                filtered = filtered.substring(1)
                              }
                              this.updateBudget(index, filtered)
                            })
                        }
                        .alignItems(VerticalAlign.Center)
                      }
                      .width('100%').height(60)
                      .padding({ left: 16, right: 16 })
                      .alignItems(VerticalAlign.Center)

                      if (index < this.expenseCategories.length - 1) {
                        Divider().color($r('app.color.color_divider')).margin({ left: 70, right: 16 })
                      }
                    }
                  }, (cat: CategoryRecord) => cat.id.toString())
                }
                .width('calc(100% - 32vp)')
                .backgroundColor($r('app.color.color_surface'))
                .borderRadius(20)
                .margin({ left: 16, right: 16 })
                .shadow({ radius: 8, color: 'rgba(0,0,0,0.03)', offsetY: 2 })
                .clip(true)
              }

              // ── 按钮区 ──
              Column({ space: 12 }) {
                Button('保存预算设置')
                  .width('100%').height(48)
                  .fontSize(16).fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.color_surface'))
                  .backgroundColor($r('app.color.color_primary'))
                  .borderRadius(24)
                  .shadow({ radius: 8, color: 'rgba(44,122,123,0.3)', offsetY: 4 })
                  .onClick(() => { this.saveBudgets() })

                Button('导出全部账单（CSV）')
                  .width('100%').height(48)
                  .fontSize(16)
                  .fontColor($r('app.color.color_primary'))
                  .backgroundColor($r('app.color.color_surface'))
                  .borderRadius(24)
                  .border({ width: 1, color: $r('app.color.color_primary') })
                  .onClick(() => { this.exportCSV() })
              }
              .padding({ left: 16, right: 16, top: 24, bottom: 16 })

              // 关于
              Row() {
                Image($rawfile('icon_chevron_right.svg')).width(24).height(24)
                  .fillColor($r('app.color.color_primary')).margin({ right: 16 })
                Text('关于鸭鱼算').fontSize(16).fontColor($r('app.color.color_text_primary')).layoutWeight(1)
                Text('v1.0.0').fontSize(14).fontColor($r('app.color.color_text_secondary'))
              }
              .width('calc(100% - 32vp)')
              .padding(16)
              .backgroundColor($r('app.color.color_surface'))
              .borderRadius(16)
              .margin({ left: 16, right: 16, bottom: 24 })
            }
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.color_bg'))
  }
}
