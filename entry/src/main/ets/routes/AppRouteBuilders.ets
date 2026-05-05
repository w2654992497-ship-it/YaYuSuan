import { BillSearchPage } from '../pages/BillSearchPage'
import { CategoryManagePage } from '../pages/CategoryManage'
import { ExpenseRankingAllPage } from '../pages/Statistics'
import { SettingsPage } from '../pages/Settings'
import { AccountFormPage } from '../pages/settings/AccountFormPage'

@Builder
export function BillSearchRouteBuilder() {
  AppRouteDestination({ routeName: 'billSearch' })
}

@Builder
export function CategoryManageRouteBuilder() {
  AppRouteDestination({ routeName: 'categoryManage' })
}

@Builder
export function ExpenseRankingAllRouteBuilder() {
  AppRouteDestination({ routeName: 'expenseRankingAll' })
}

@Builder
export function BudgetSettingsRouteBuilder() {
  AppRouteDestination({ routeName: 'budgetSettings' })
}

@Builder
export function PeriodBillRouteBuilder() {
  AppRouteDestination({ routeName: 'periodBill' })
}

@Builder
export function AccountSettingsRouteBuilder() {
  AppRouteDestination({ routeName: 'accountSettings' })
}

@Builder
export function AccountCreateRouteBuilder() {
  AppRouteDestination({ routeName: 'accountCreate' })
}

@Builder
export function AccountEditRouteBuilder() {
  AppRouteDestination({ routeName: 'accountEdit' })
}

@Builder
export function ThemeModeRouteBuilder() {
  AppRouteDestination({ routeName: 'themeMode' })
}

@Builder
export function GeneralSettingsRouteBuilder() {
  AppRouteDestination({ routeName: 'generalSettings' })
}

@Builder
export function UserDataSettingsRouteBuilder() {
  AppRouteDestination({ routeName: 'userDataSettings' })
}

@Builder
export function DataToolsRouteBuilder() {
  AppRouteDestination({ routeName: 'dataTools' })
}

@Builder
export function PrivacySettingsRouteBuilder() {
  AppRouteDestination({ routeName: 'privacySettings' })
}

@Builder
export function SyncSettingsRouteBuilder() {
  AppRouteDestination({ routeName: 'syncSettings' })
}

@Builder
export function SecuritySettingsRouteBuilder() {
  AppRouteDestination({ routeName: 'securitySettings' })
}

@Builder
export function FeedbackRouteBuilder() {
  AppRouteDestination({ routeName: 'feedbackPage' })
}

@Builder
export function AboutRouteBuilder() {
  AppRouteDestination({ routeName: 'aboutPage' })
}

@Component
struct AppRouteDestination {
  routeName: string = ''
  @Consume('appNavStack') navStack: NavPathStack

  private accountEditId(): number {
    try {
      const params = this.navStack.getParamByName('accountEdit') as number[]
      if (params.length > 0) {
        return params[params.length - 1]
      }
    } catch (_err) {
    }
    return 0
  }

  private settingsInitialPage(): string {
    if (this.routeName === 'budgetSettings') {
      return 'budget'
    }
    if (this.routeName === 'periodBill') {
      return 'period'
    }
    if (this.routeName === 'accountSettings') {
      return 'account'
    }
    if (this.routeName === 'themeMode') {
      return 'theme'
    }
    if (this.routeName === 'generalSettings') {
      return 'general'
    }
    if (this.routeName === 'userDataSettings') {
      return 'userData'
    }
    if (this.routeName === 'dataTools') {
      return 'data'
    }
    if (this.routeName === 'privacySettings') {
      return 'privacy'
    }
    if (this.routeName === 'syncSettings') {
      return 'sync'
    }
    if (this.routeName === 'securitySettings') {
      return 'security'
    }
    if (this.routeName === 'feedbackPage') {
      return 'feedback'
    }
    if (this.routeName === 'aboutPage') {
      return 'about'
    }
    return 'main'
  }

  build() {
    NavDestination() {
      if (this.routeName === 'billSearch') {
        BillSearchPage({
          onClose: () => {
            this.navStack.pop()
          }
        })
      } else if (this.routeName === 'categoryManage') {
        CategoryManagePage({
          onBack: () => {
            this.navStack.pop()
          }
        })
      } else if (this.routeName === 'expenseRankingAll') {
        ExpenseRankingAllPage()
      } else if (this.routeName === 'accountCreate') {
        AccountFormPage({
          mode: 'create',
          onBack: () => {
            this.navStack.pop()
          },
          onSaved: () => {
            this.navStack.pop()
          }
        })
      } else if (this.routeName === 'accountEdit') {
        AccountFormPage({
          mode: 'edit',
          accountEditId: this.accountEditId(),
          onBack: () => {
            this.navStack.pop()
          },
          onSaved: () => {
            this.navStack.pop()
          }
        })
      } else {
        SettingsPage({ initialPage: this.settingsInitialPage() })
      }
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.start_window_background'))
  }
}
