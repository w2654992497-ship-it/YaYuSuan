import { preferences } from '@kit.ArkData'
import { fileIo } from '@kit.CoreFileKit'
import picker from '@ohos.file.picker'
import { EXPENSE_CATEGORIES, CategoryInfo } from '../model/Category'
import { BillDao } from '../database/BillDao'
import { FilterOptions } from '../model/FilterOptions'
import { Bill } from '../model/Bill'
import { AmountUtil } from '../utils/AmountUtil'
import { NavBar } from '../components/NavBar'
import { ToastUtils } from '../utils/ToastUtils'
import { LogUtils } from '../utils/LogUtils'

const PREF_NAME = 'yayusuan_budget'

@Component
export struct SettingsPage {
  // 8 expense categories — one string per category (yuan display value, '' = no limit)
  @State budgetValues: string[] = ['', '', '', '', '', '', '', '']

  aboutToAppear(): void {
    this.loadBudgets()
  }

  private async loadBudgets(): Promise<void> {
    try {
      const pref = await preferences.getPreferences(this.getUIContext().getHostContext()!, { name: PREF_NAME })
      const vals: string[] = []
      for (const cat of EXPENSE_CATEGORIES) {
        const fen = await pref.get(`budget_${cat.name}`, 0) as number
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
      for (let i = 0; i < EXPENSE_CATEGORIES.length; i++) {
        const cat = EXPENSE_CATEGORIES[i]
        const fen = this.budgetValues[i] && this.budgetValues[i].length > 0
          ? AmountUtil.yuan2Fen(this.budgetValues[i])
          : 0
        await pref.put(`budget_${cat.name}`, fen)
      }
      await pref.flush()
      ToastUtils.success('预算设置已保存')
    } catch (err) {
      ToastUtils.error('保存失败，请重试')
      LogUtils.error('Settings', 'saveBudgets: %{public}s', JSON.stringify(err))
    }
  }

  // ── CSV 导出 ──────────────────────────────────────────
  private async exportCSV(): Promise<void> {
    try {
      // 查询全部账单（不限月份/类型）
      const filter: FilterOptions = { month: '', type: 'all', category: '' }
      const bills: Bill[] = await BillDao.getInstance().queryByFilter(filter)
      if (bills.length === 0) {
        ToastUtils.warning('暂无账单数据可导出')
        return
      }

      // 生成 CSV 内容（UTF-8 with BOM，Excel 可直接识别中文）
      const bom = '\uFEFF'
      const header = '日期,类型,分类,金额(元),备注\n'
      const rows = bills.map((b: Bill): string => {
        const typeLabel = b.type === 'income' ? '收入' : '支出'
        const amount = AmountUtil.fen2Display(b.amount)
        const remark = b.remark.replace(/,/g, '，')  // 防止逗号破坏 CSV 结构
        return `${b.date},${typeLabel},${b.category},${amount},${remark}`
      }).join('\n')
      const csvContent = bom + header + rows

      // 调用文件选择器让用户选择保存路径
      const saveOptions = new picker.DocumentSaveOptions()
      saveOptions.newFileNames = ['鸭鱼算账单.csv']
      const docPicker = new picker.DocumentViewPicker(this.getUIContext().getHostContext()!)
      const uriArr = await docPicker.save(saveOptions)
      if (!uriArr || uriArr.length === 0) { return }

      // 写入文件
      const file = await fileIo.open(uriArr[0], fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC)
      await fileIo.write(file.fd, csvContent)
      await fileIo.close(file.fd)

      ToastUtils.success(`已导出 ${bills.length} 条账单`)
    } catch (err) {
      const errStr = JSON.stringify(err)
      if (errStr.includes('cancel') || errStr.includes('Cancel')) { return }  // 用户取消
      ToastUtils.error('导出失败，请重试')
      LogUtils.error('Settings', 'exportCSV error: %{public}s', errStr)
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
      NavBar({
        title: '月度预算',
        showLeft: false,
        showDivider: true
      })

      Scroll() {
        Column() {
          // 提示文字
          Text('为各支出分类设置每月预算上限，超额时提醒')
            .fontSize(12)
            .fontColor('#757575')
            .width('100%')
            .padding({ left: 16, right: 16, top: 14, bottom: 10 })

          // 预算列表卡片
          Column() {
            ForEach(EXPENSE_CATEGORIES, (cat: CategoryInfo, index: number) => {
              Column() {
                Row() {
                  // 分类图标
                  Column() {
                    Image($rawfile(cat.icon + '.svg'))
                      .width(20)
                      .height(20)
                      .fillColor('#FFFFFF')
                  }
                  .width(40)
                  .height(40)
                  .borderRadius(20)
                  .backgroundColor(cat.color)
                  .alignItems(HorizontalAlign.Center)
                  .justifyContent(FlexAlign.Center)
                  .margin({ right: 14 })

                  // 分类名
                  Text(cat.name)
                    .fontSize(15)
                    .fontColor('#212121')
                    .layoutWeight(1)

                  // 预算输入
                  Row() {
                    Text('¥')
                      .fontSize(14)
                      .fontColor('#757575')
                      .margin({ right: 2 })
                    TextInput({ placeholder: '不限', text: this.budgetValues[index] ?? '' })
                      .fontSize(14)
                      .fontColor('#212121')
                      .placeholderColor('#757575')
                      .backgroundColor(Color.Transparent)
                      .border({ width: 0 })
                      .borderRadius(0)
                      .padding({ top: 0, bottom: 0, left: 0, right: 0 })
                      .type(InputType.NUMBER_DECIMAL)
                      .width(80)
                      .textAlign(TextAlign.End)
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
                .width('100%')
                .height(64)
                .padding({ left: 16, right: 16 })
                .alignItems(VerticalAlign.Center)

                if (index < EXPENSE_CATEGORIES.length - 1) {
                  Divider()
                    .color('#E0E0E0')
                    .margin({ left: 70, right: 16 })
                }
              }
              .width('100%')
            }, (cat: CategoryInfo) => cat.name)
          }
          .width('100%')
          .backgroundColor('#FFFFFF')
          .borderRadius(14)
          .margin({ left: 16, right: 16 })
          .shadow({ radius: 6, color: '#0D000000', offsetX: 0, offsetY: 2 })
          .clip(true)

          // 保存按钮 + 导出按钮
          Column({ space: 12 }) {
            Button('保存预算设置')
              .width('100%')
              .height(48)
              .fontSize(16)
              .fontColor('#FFFFFF')
              .backgroundColor('#1976D2')
              .borderRadius(24)
              .onClick(() => { this.saveBudgets() })

            Button('导出全部账单（CSV）')
              .width('100%')
              .height(48)
              .fontSize(16)
              .fontColor('#1976D2')
              .backgroundColor('#E3F2FD')
              .borderRadius(24)
              .onClick(() => { this.exportCSV() })
          }
          .padding({ left: 16, right: 16, top: 24, bottom: 20 })
        }
        .width('100%')
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}
