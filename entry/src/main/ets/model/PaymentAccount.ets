export type PaymentAccountType = 'bank' | 'alipay' | 'wechat' | 'cash' | 'other'

export interface PaymentAccount {
  id: number
  userId: number
  bookId: number
  name: string
  type: PaymentAccountType
  bankName: string
  tailNumber: string
  iconMark: string
  color: string
  manualBalance: number
  balanceUpdatedAt: number
  sortOrder: number
  isDefault: number
  enabled: number
  createdAt: number
  updatedAt: number
  deleted: number
}

export function createEmptyPaymentAccount(): PaymentAccount {
  const now = Date.now()
  return {
    id: 0,
    userId: 1,
    bookId: 1,
    name: '',
    type: 'cash',
    bankName: '',
    tailNumber: '',
    iconMark: '现',
    color: '#FF9500',
    manualBalance: 0,
    balanceUpdatedAt: now,
    sortOrder: 0,
    isDefault: 0,
    enabled: 1,
    createdAt: now,
    updatedAt: now,
    deleted: 0
  }
}

export function paymentAccountDesc(account: PaymentAccount): string {
  if (account.tailNumber.length > 0) {
    return '尾号' + account.tailNumber
  }
  if (account.type === 'cash') {
    return '余额账户'
  }
  return ''
}

export function paymentAccountDisplayName(account: PaymentAccount): string {
  const desc = paymentAccountDesc(account)
  if (desc.length > 0) {
    return account.name + ' · ' + desc
  }
  return account.name
}
