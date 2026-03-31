export interface CategoryInfo {
  name: string
  icon: string   // rawfile 文件名，不含 .svg 后缀
  color: string  // 主题色，16进制
}

export const EXPENSE_CATEGORIES: CategoryInfo[] = [
  { name: '餐饮', icon: 'icon_food',          color: '#FF7043' },
  { name: '交通', icon: 'icon_transport',     color: '#42A5F5' },
  { name: '购物', icon: 'icon_shopping',      color: '#EC407A' },
  { name: '娱乐', icon: 'icon_entertainment', color: '#AB47BC' },
  { name: '住房', icon: 'icon_housing',       color: '#26A69A' },
  { name: '医疗', icon: 'icon_medical',       color: '#EF5350' },
  { name: '教育', icon: 'icon_education',     color: '#5C6BC0' },
  { name: '其他', icon: 'icon_other',         color: '#78909C' }
]

export const INCOME_CATEGORIES: CategoryInfo[] = [
  { name: '工资', icon: 'icon_salary',     color: '#66BB6A' },
  { name: '兼职', icon: 'icon_parttime',   color: '#FFA726' },
  { name: '理财', icon: 'icon_investment', color: '#26C6DA' },
  { name: '红包', icon: 'icon_gift',       color: '#EF5350' },
  { name: '其他', icon: 'icon_other',      color: '#78909C' }
]

export function getCategoryInfo(name: string): CategoryInfo {
  const all: CategoryInfo[] = [...EXPENSE_CATEGORIES, ...INCOME_CATEGORIES]
  const found = all.find(c => c.name === name)
  return found ?? { name, icon: 'icon_other', color: '#78909C' }
}

export function getCategoryColor(name: string): string {
  return getCategoryInfo(name).color
}
