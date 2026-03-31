export interface CategoryInfo {
  name: string
  emoji: string
  color: string
}

export const EXPENSE_CATEGORIES: CategoryInfo[] = [
  { name: '餐饮', emoji: '🍜', color: '#FF7043' },
  { name: '交通', emoji: '🚇', color: '#42A5F5' },
  { name: '购物', emoji: '🛍️', color: '#EC407A' },
  { name: '娱乐', emoji: '🎮', color: '#AB47BC' },
  { name: '住房', emoji: '🏠', color: '#26A69A' },
  { name: '医疗', emoji: '💊', color: '#EF5350' },
  { name: '教育', emoji: '📚', color: '#5C6BC0' },
  { name: '其他', emoji: '📦', color: '#78909C' }
]

export const INCOME_CATEGORIES: CategoryInfo[] = [
  { name: '工资', emoji: '💰', color: '#66BB6A' },
  { name: '兼职', emoji: '💼', color: '#FFA726' },
  { name: '理财', emoji: '📈', color: '#26C6DA' },
  { name: '红包', emoji: '🧧', color: '#EF5350' },
  { name: '其他', emoji: '✨', color: '#78909C' }
]

export function getCategoryInfo(name: string): CategoryInfo {
  const allCategories: CategoryInfo[] = [...EXPENSE_CATEGORIES, ...INCOME_CATEGORIES]
  const found = allCategories.find(c => c.name === name)
  if (found) {
    return found
  }
  return { name: name, emoji: '📦', color: '#78909C' }
}

export function getCategoryColor(name: string): string {
  return getCategoryInfo(name).color
}
