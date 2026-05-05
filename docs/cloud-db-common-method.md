# HarmonyOS 云数据库通用写入方法

通用工具文件：

```text
entry/src/main/ets/services/CloudDbCommon.ets
```

## 使用方式

以 `UserInfo` 为例：

```ts
import { cloudDatabase } from '@kit.CloudFoundationKit'
import { CloudDbCommon } from '../services/CloudDbCommon'
import { UserInfo } from '../UserInfo'

const db = new CloudDbCommon('XiaoJinYu')

const user = new UserInfo()
user.cloudId = 'user_1'
user.localId = 1
user.username = 'test'
user.displayName = '测试用户'
user.passwordHash = ''
user.salt = ''
user.createdAt = Date.now()
user.lastLoginAt = Date.now()
user.updatedAt = Date.now()

await db.upsertOne<UserInfo>('UserInfo', user)
```

批量写入：

```ts
const users: UserInfo[] = [user]
await db.upsertMany<UserInfo>('UserInfo', users)
```

查询：

```ts
const query = new cloudDatabase.DatabaseQuery<UserInfo>(UserInfo)
  .equalTo('username', 'test')
  .limit(1)

const users = await db.query<UserInfo>('UserInfo', query)
```

删除：

```ts
const deletedUser = new UserInfo()
deletedUser.cloudId = 'user_1'

await db.deleteOne<UserInfo>('UserInfo', deletedUser)
```

## 后续项目复制时需要改哪里

1. 修改存储区名称，例如：

```ts
const db = new CloudDbCommon('你的存储区名称')
```

2. 修改对象类型模型，例如 `UserInfo`、`CloudBill`、`CloudCategory`。

3. `objectName` 要和 AGC 对象类型名称一致：

```ts
await db.upsertOne<UserInfo>('UserInfo', user)
```

4. 写入失败时先看 Hilog：

```text
A1a1
[CloudDbCommon]
```

常见错误：

- `2001015:permission denied`：对象类型权限没有给当前角色 `Upsert`。
- `1008231001`：服务端错误或认证失败，先检查存储区名、对象类型、包名、AGC 配置。
- 查询成功但写入失败：通常是权限只给了 `Read`，没有给 `Upsert`。

## 推荐数据结构

后续项目不要把所有数据只挂在用户下面，建议使用：

```text
UserInfo
  -> AccountBook / Project / Workspace
    -> 业务数据表
```

也就是每条业务数据至少带：

```text
userId
bookId / projectId / workspaceId
cloudId
localId
createdAt
updatedAt
deleted
```

这样以后做多用户、多项目、本地缓存、云端同步会清楚很多。
