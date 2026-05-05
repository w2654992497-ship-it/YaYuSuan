import { CategoryRecord } from '../../model/Category'
import {
  BudgetOverview,
  createEmptyBudgetOverview,
} from '../../model/BudgetRule'
import { SettingsBudgetListPage } from './SettingsBudgetListPage'
import { SettingsBudgetEditPage } from './SettingsBudgetEditPage'

@Component
export struct SettingsBudgetPage {
  @Prop sbHeight: number
  @Prop mode: string = 'list'
  @Prop dayOverview: BudgetOverview = createEmptyBudgetOverview()
  @Prop monthOverview: BudgetOverview = createEmptyBudgetOverview()
  @Prop yearOverview: BudgetOverview = createEmptyBudgetOverview()
  @Prop refreshVersion: number = 0
  @Prop expenseCategories: CategoryRecord[] = []
  @Prop editingPeriodType: string = 'month'
  @Prop periodTotalAmount: string = ''
  @Prop categoryAllocationEnabled: boolean = false
  @Prop categoryAllocationValues: string[] = []
  @Prop selectedAllocationCategoryIds: number[] = []
  @Prop overflowOverview: BudgetOverview = createEmptyBudgetOverview()
  onBack: () => void = (): void => {}
  onBeginEditPeriod: (periodType: string) => void = (periodType: string): void => {}
  onCloseEditor: () => void = (): void => {}
  onPeriodTotalAmountChange: (value: string) => void = (value: string): void => {}
  onToggleCategoryAllocation: () => void = (): void => {}
  onCategoryAllocationAmountChange: (index: number, value: string) => void = (index: number, value: string): void => {}
  onToggleAllocationCategory: (cat: CategoryRecord) => void = (cat: CategoryRecord): void => {}
  onSavePeriodBudget: () => void = (): void => {}

  build() {
    Stack() {
      SettingsBudgetListPage({
        sbHeight: this.sbHeight,
        dayOverview: this.dayOverview,
        monthOverview: this.monthOverview,
        yearOverview: this.yearOverview,
        refreshVersion: this.refreshVersion,
        onBack: this.onBack,
        onBeginEditPeriod: this.onBeginEditPeriod
      })

      if (this.mode === 'edit') {
        Stack({ alignContent: Alignment.Bottom }) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor(Color.Black)
            .opacity(0.36)
            .onClick(this.onCloseEditor)

          Column() {
            SettingsBudgetEditPage({
              periodType: this.editingPeriodType,
              totalAmount: this.periodTotalAmount,
              allocationEnabled: this.categoryAllocationEnabled,
              allocationValues: this.categoryAllocationValues,
              selectedAllocationCategoryIds: this.selectedAllocationCategoryIds,
              expenseCategories: this.expenseCategories,
              overflowOverview: this.overflowOverview,
              onCloseEditor: this.onCloseEditor,
              onTotalAmountChange: this.onPeriodTotalAmountChange,
              onToggleAllocation: this.onToggleCategoryAllocation,
              onAllocationAmountChange: this.onCategoryAllocationAmountChange,
              onToggleAllocationCategory: this.onToggleAllocationCategory,
              onSave: this.onSavePeriodBudget
            })
              .layoutWeight(1)
          }
          .width('100%')
          .height('64%')
          .backgroundColor($r('app.color.start_window_background'))
          .borderRadius({ topLeft: 24, topRight: 24 })
          .shadow({ radius: 18, color: $r('app.color.color_shadow_blue_08'), offsetY: -4 })
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }
}
