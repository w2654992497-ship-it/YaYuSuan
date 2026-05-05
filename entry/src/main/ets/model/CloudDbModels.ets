import { cloudDatabase } from '@kit.CloudFoundationKit'

export class UserInfo extends cloudDatabase.DatabaseObject {
  cloudId: string = ''
  localId: number = 0
  username: string = ''
  displayName: string = ''
  createdAt: number = 0
  lastLoginAt: number = 0
  updatedAt: number = 0

  naturalbase_ClassName(): string {
    return 'UserInfo'
  }
}

export class CloudBill extends cloudDatabase.DatabaseObject {
  cloudId: string = ''
  userId: string = ''
  localId: number = 0
  amount: number = 0
  type: string = ''
  category: string = ''
  remark: string = ''
  date: string = ''
  createdAt: number = 0
  updatedAt: number = 0
  deleted: number = 0

  naturalbase_ClassName(): string {
    return 'CloudBill'
  }
}

export class CloudCategory extends cloudDatabase.DatabaseObject {
  cloudId: string = ''
  userId: string = ''
  localId: number = 0
  name: string = ''
  icon: string = ''
  color: string = ''
  type: string = ''
  sortOrder: number = 0
  isDefault: number = 0
  updatedAt: number = 0
  deleted: number = 0

  naturalbase_ClassName(): string {
    return 'CloudCategory'
  }
}

export class CloudPeriodRule extends cloudDatabase.DatabaseObject {
  cloudId: string = ''
  userId: string = ''
  localId: number = 0
  title: string = ''
  amount: number = 0
  type: string = ''
  category: string = ''
  remark: string = ''
  cycle: string = ''
  day: number = 0
  month: number = 0
  nextDate: string = ''
  enabled: number = 0
  createdAt: number = 0
  updatedAt: number = 0
  deleted: number = 0

  naturalbase_ClassName(): string {
    return 'CloudPeriodRule'
  }
}
