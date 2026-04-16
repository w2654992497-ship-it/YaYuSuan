export interface SearchFilterOptions {
  keyword: string
  type: 'all' | 'income' | 'expense'
  category: string
  startDate: string
  endDate: string
}

export function createDefaultSearchFilter(): SearchFilterOptions {
  return {
    keyword: '',
    type: 'all',
    category: '',
    startDate: '',
    endDate: ''
  }
}
