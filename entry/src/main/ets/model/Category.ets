// ── 基础接口（用于同步查找和UI展示） ──
export interface CategoryInfo {
  name: string
  icon: string   // rawfile 文件名，不含 .svg 后缀
  color: string  // 16进制颜色
}

// ── 数据库记录接口 ──
export interface CategoryRecord {
  id: number
  name: string
  icon: string
  color: string
  type: 'income' | 'expense'
  sort_order: number
  is_default: number  // 0 用户自定义, 1 系统默认
}

// ── 默认分类（种子数据） ──
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

// ── 预设图标库（供用户创建自定义分类时选择） ──
export const PRESET_ICONS: string[] = [
  'icon_food', 'icon_transport', 'icon_shopping', 'icon_entertainment',
  'icon_housing', 'icon_medical', 'icon_education', 'icon_other',
  'icon_salary', 'icon_parttime', 'icon_investment', 'icon_gift',
  'icon_pet', 'icon_fitness', 'icon_travel', 'icon_phone',
  'icon_utilities', 'icon_insurance', 'icon_clothing', 'icon_beauty',
  'icon_digital', 'icon_snack', 'icon_drink', 'icon_baby', 'icon_elderly'
]

// ── 预设颜色库 ──
export const PRESET_COLORS: string[] = [
  '#FF7043', '#42A5F5', '#EC407A', '#AB47BC',
  '#26A69A', '#EF5350', '#5C6BC0', '#78909C',
  '#66BB6A', '#FFA726', '#26C6DA', '#8D6E63',
  '#7E57C2', '#FF8A65', '#4DB6AC', '#9CCC65'
]

// ── 模块级缓存（供同步函数使用） ──
const categoryCache: Map<string, CategoryInfo> = new Map()

export function refreshCategoryCache(records: CategoryRecord[]): void {
  categoryCache.clear()
  for (const r of records) {
    categoryCache.set(r.name, { name: r.name, icon: r.icon, color: r.color })
  }
}

export function getCategoryInfo(name: string): CategoryInfo {
  const cached = categoryCache.get(name)
  if (cached) return cached
  // 回退到硬编码默认
  const all: CategoryInfo[] = [...EXPENSE_CATEGORIES, ...INCOME_CATEGORIES]
  const found = all.find(c => c.name === name)
  return found ?? { name, icon: 'icon_other', color: '#78909C' }
}

export function getCategoryColor(name: string): string {
  return getCategoryInfo(name).color
}
