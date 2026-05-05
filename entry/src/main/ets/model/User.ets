export interface User {
  id: number
  username: string
  displayName: string
  passwordHash: string
  salt: string
  createdAt: number
  lastLoginAt: number
}

export interface UserSession {
  id: number
  username: string
  displayName: string
}
