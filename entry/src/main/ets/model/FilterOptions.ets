export interface FilterOptions {
  month: string   // YYYY-MM, empty=all
  type: 'all' | 'income' | 'expense'
  category: string
}

export function createDefaultFilter(): FilterOptions {
  const now = new Date()
  const year = now.getFullYear()
  const month = (now.getMonth() + 1).toString().padStart(2, '0')
  return {
    month: `${year}-${month}`,
    type: 'all',
    category: ''
  }
}
