export interface CategoryInfo {
  name: string
  icon: string
  color: string
}

export interface CategoryRecord {
  id: number
  name: string
  icon: string
  color: string
  type: 'income' | 'expense'
  sort_order: number
  is_default: number
}

export const EXPENSE_CATEGORIES: CategoryInfo[] = [
  { name: '餐饮', icon: 'icon_food', color: '#FF9F1C' },
  { name: '交通', icon: 'icon_transport', color: '#2563EB' },
  { name: '购物', icon: 'icon_shopping', color: '#3B82F6' },
  { name: '娱乐', icon: 'icon_entertainment', color: '#7C3AED' },
  { name: '住房', icon: 'icon_housing', color: '#475569' },
  { name: '医疗', icon: 'icon_medical', color: '#F97316' },
  { name: '教育', icon: 'icon_education', color: '#4F46E5' },
  { name: '其他', icon: 'icon_other', color: '#94A3B8' }
]

export const INCOME_CATEGORIES: CategoryInfo[] = [
  { name: '工资', icon: 'icon_salary', color: '#2563EB' },
  { name: '兼职', icon: 'icon_parttime', color: '#FF9F1C' },
  { name: '理财', icon: 'icon_investment', color: '#4F46E5' },
  { name: '红包', icon: 'icon_gift', color: '#F97316' },
  { name: '其他', icon: 'icon_other', color: '#64748B' }
]

export const PRESET_ICONS: string[] = [
  'icon_food', 'icon_transport', 'icon_shopping', 'icon_entertainment',
  'icon_housing', 'icon_medical', 'icon_education', 'icon_other',
  'icon_salary', 'icon_parttime', 'icon_investment', 'icon_gift',
  'icon_pet', 'icon_fitness', 'icon_travel', 'icon_phone',
  'icon_utilities', 'icon_insurance', 'icon_clothing', 'icon_beauty',
  'icon_digital', 'icon_snack', 'icon_drink', 'icon_baby', 'icon_elderly'
]

export const PRESET_COLORS: string[] = [
  '#2563EB', '#3B82F6', '#4F46E5', '#7C3AED',
  '#FF9F1C', '#F97316', '#475569', '#94A3B8'
]

export function getUnifiedCategoryColor(name: string): string {
  if (name === '餐饮' || name === '医疗' || name === '兼职') {
    return '#FF9F1C'
  }
  if (name === '购物' || name === '教育' || name === '理财') {
    return '#3B82F6'
  }
  if (name === '娱乐' || name === '红包') {
    return '#7C3AED'
  }
  if (name === '其他') {
    return '#94A3B8'
  }
  return '#2563EB'
}

const categoryCache: Map<string, CategoryInfo> = new Map()

export function refreshCategoryCache(records: CategoryRecord[]): void {
  categoryCache.clear()
  for (let i = 0; i < records.length; i++) {
    const record = records[i]
    categoryCache.set(record.name, { name: record.name, icon: record.icon, color: record.color })
  }
}

export function getCategoryInfo(name: string): CategoryInfo {
  const cached = categoryCache.get(name)
  if (cached) {
    return cached
  }
  for (let i = 0; i < EXPENSE_CATEGORIES.length; i++) {
    if (EXPENSE_CATEGORIES[i].name === name) {
      return EXPENSE_CATEGORIES[i]
    }
  }
  for (let i = 0; i < INCOME_CATEGORIES.length; i++) {
    if (INCOME_CATEGORIES[i].name === name) {
      return INCOME_CATEGORIES[i]
    }
  }
  return { name: name, icon: 'icon_other', color: '#64748B' }
}

export function getCategoryColor(name: string): string {
  return getUnifiedCategoryColor(name)
}
