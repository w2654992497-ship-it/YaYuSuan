export interface Bill {
  id: number
  amount: number           // stored in fen (分)
  type: 'income' | 'expense'
  category: string
  remark: string
  date: string             // YYYY-MM-DD
  createdAt: number        // timestamp ms
}
