type FingerprintFn<T> = (item: T) => string
type KeyFn<T> = (item: T) => string | number
type InPlaceUpdateFn<T> = (target: T, source: T) => boolean

export class LazyForEachDataSource<T> implements IDataSource {
  private data: T[] = []
  private listeners: DataChangeListener[] = []
  private cachedFingerprints: string[] = []

  constructor(initialData: T[]) {
    this.data = [...initialData]
  }

  totalCount(): number {
    return this.data.length
  }

  getData(index: number): T {
    return this.data[index]
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener)
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index = this.listeners.indexOf(listener)
    if (index >= 0) {
      this.listeners.splice(index, 1)
    }
  }

  setData(newData: T[]): void {
    this.data = [...newData]
    this.cachedFingerprints = []
    this.notifyReload()
  }

  /**
   * 差量更新：对比新旧数据，只通知变化项，避免全量 reload 闪烁。
   * key 序列变化时自动 fallback 到 reload。
   */
  smartUpdate(newData: T[], keyFn: KeyFn<T>, fingerprintFn: FingerprintFn<T>,
    inPlaceUpdateFn?: InPlaceUpdateFn<T>): void {
    const oldFingerprints = this.cachedFingerprints
    const oldKeyCount = oldFingerprints.length

    const newFingerprints: string[] = newData.map(fingerprintFn)
    const newKeys = newData.map(keyFn)

    // 空 → 有数据，或数据变为空：直接 reload
    if (oldKeyCount === 0 || newData.length === 0) {
      this.data = [...newData]
      this.cachedFingerprints = newFingerprints
      this.notifyReload()
      return
    }

    const oldKeys = this.data.map(keyFn)

    // key 序列完全一致：逐项对比指纹，只更新变化项
    if (oldKeyCount === newData.length) {
      let keysMatch = true
      for (let i = 0; i < oldKeyCount; i++) {
        if (oldKeys[i] !== newKeys[i]) {
          keysMatch = false
          break
        }
      }
      if (keysMatch) {
        for (let i = 0; i < newData.length; i++) {
          if (oldFingerprints[i] !== newFingerprints[i]) {
            if (inPlaceUpdateFn) {
              const updated = inPlaceUpdateFn(this.data[i], newData[i])
              if (!updated) {
                this.data[i] = newData[i]
                this.notifyChange(i)
              }
            } else {
              this.data.splice(i, 1)
              this.notifyDelete(i)
              this.data.splice(i, 0, newData[i])
              this.notifyAdd(i)
            }
          }
        }
        this.cachedFingerprints = newFingerprints
        return
      }
    }

    // 末尾追加场景（旧数据是新数据的前缀）
    if (newData.length > oldKeyCount) {
      let isPrefixMatch = true
      for (let i = 0; i < oldKeyCount; i++) {
        if (oldKeys[i] !== newKeys[i]) {
          isPrefixMatch = false
          break
        }
      }
      if (isPrefixMatch) {
        for (let i = 0; i < oldKeyCount; i++) {
          if (oldFingerprints[i] !== newFingerprints[i]) {
            this.data.splice(i, 1)
            this.notifyDelete(i)
            this.data.splice(i, 0, newData[i])
            this.notifyAdd(i)
          }
        }
        for (let i = oldKeyCount; i < newData.length; i++) {
          this.data.push(newData[i])
          this.notifyAdd(i)
        }
        this.cachedFingerprints = newFingerprints
        return
      }
    }

    // key 序列变化（删除、顺序变动）：全量 reload
    this.data = [...newData]
    this.cachedFingerprints = newFingerprints
    this.notifyReload()
  }

  deleteItem(index: number): void {
    if (index >= 0 && index < this.data.length) {
      this.data.splice(index, 1)
      this.cachedFingerprints.splice(index, 1)
      this.notifyDelete(index)
    }
  }

  getAll(): T[] {
    return this.data
  }

  private notifyReload(): void {
    for (const l of this.listeners) l.onDataReloaded()
  }

  private notifyChange(index: number): void {
    for (const l of this.listeners) l.onDataChange(index)
  }

  private notifyDelete(index: number): void {
    for (const l of this.listeners) l.onDataDelete(index)
  }

  private notifyAdd(index: number): void {
    for (const l of this.listeners) l.onDataAdd(index)
  }
}
