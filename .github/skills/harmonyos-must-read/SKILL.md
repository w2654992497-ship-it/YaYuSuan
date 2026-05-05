---
name: harmonyos-must-read
description: "HarmonyOS 开发必读（高优先级）规则集合，覆盖 ArkTS/ArkUI/HarmonyOS/DevEco 的语法边界、工程规范与命令行编译签名流程。"
---

# HarmonyOS 开发必读（高优先级）

以下规则为必读，默认遵循，优先级高于普通代码风格讨论。

## 一、全局要求

- 默认使用中文回复、中文注释、中文日志文案、中文调试说明。
- 对 HarmonyOS、ArkTS、ArkUI、DevEco 相关语法和 API 不确定时，不得猜测。
- 若发现现有实现与下述规则冲突，优先按本文件修正。

## 二、ArkTS/ets 语法约束（违规将影响编译）

- 不支持索引访问类型。请改用类型名称。
- 不支持环境模块声明，请从原始模块中导入所需内容。
- 不支持 `any` 和 `unknown` 类型。请显式指定类型。
- 不支持 `as const` 断言。请改用显式字面量类型标注。
- 不支持对象类型中的调用签名。请改用 `class` 实现。
- 不支持类字面量。请显式引入新的命名类类型。
- 不支持将类用作对象。类声明引入的是类型，不是可当作对象赋值的值。
- 仅在 `for` 循环中支持逗号运算符，其它场景请用显式执行顺序。
- 不支持条件类型别名和 `infer`。请改用约束类型或继承/重构。
- 不支持在构造函数中声明类字段。字段需在类体内声明。
- 不支持构造函数类型。请改用 lambda（匿名函数）。
- 不支持接口中的构造函数签名。请改用方法。
- 不支持对象类型中的构造函数签名。请改用类。
- 不支持声明合并（类/接口）。
- 不建议使用确定性赋值断言 `let v!: T`。如使用请确保先赋值且知晓运行时成本，优先用带初始化的声明。
- 对象布局在编译期固定，建议用可空字段置 `null` 表示缺失，而非删除属性。
- 不支持解构赋值和解构变量声明。请用中间变量手工赋值。
- 参数请不要解构参数列表，需手动赋予局部变量。
- 不支持枚举声明合并；枚举初始化器需同类型、编译时表达式。
- 不支持 `export =`、UMD、反向模块模式。请使用标准 `export/import`。
- 接口不可有不可区分同名签名。
- 不支持 `for ... in` 遍历对象。对象避免运行时遍历；数组使用普通 `for`。
- 不支持 `Function.apply`、`Function.call`、`Function.bind`。
- 不支持函数表达式，优先箭头函数。
- 不支持给函数声明新属性，也不支持动态改写对象方法。
- 不支持生成器函数。
- 不支持 `globalThis` 和全局作用域共享数据。
- 函数返回类型推断有局限，必要时显式标注返回值类型。
- 不支持导入断言。请改用普通 `import`。
- 不支持 `in` 运算符，需用 `instanceof` 与 `as` 做类型判断。
- 不允许索引签名。请改用数组。
- 仅可在泛型能由入参推断时省略泛型参数，否则显式指定。
- 不支持交叉类型。请用继承替代。
- 不支持 `is` 运算符。请改用 `instanceof`。
- 不支持 JSX。
- 不支持映射类型。请改用常规类或接口。
- 所有 `import` 必须放在文件最前。
- 不支持模块路径通配符导入。
- 不允许类存在多个静态代码块。
- 不支持嵌套函数。请改用 lambda。
- 不支持 `new.target`。
- 数组字面量中若有不可推断元素需显式类型。
- 不支持命名空间作为对象；命名空间中不得放普通语句。
- 不支持对象字面量直接作为类型声明，需显式类或接口。
- 一元运算符 `+`、`-`、`~` 仅用于数字。
- 不支持 `#` 私有字段，使用 `private`。
- 不支持动态字段声明和通用索引访问 `obj["field"]`。
- 不支持原型赋值。
- 不支持 `require` 和 import 赋值。
- 展开运算符仅用于数组到数组或 rest 参数。
- 独立函数和静态方法中不支持 `this`。
- 不支持结构化类型兼容比令人对。
- 不支持 `Symbol()`，除必要场景外避免使用。
- 不要让 TS codebase 依赖 ArkTS codebase。
- `typeof` 仅用于表达式上下文，不用于类型标注。
- `catch` 中不要给变量添加类型标注。
- 不支持 `this` 作为类型注解。
- 不支持使用 `var`，请用 `let`。
- 不支持 `with`。

## 三、HarmonyOS API 与工程规范（必读）

- 优先使用 HarmonyOS 官方 API、组件、模板和动画方案。
- 调用 API 前确认官方文档、入参、返回值、API Level、设备能力。
- 不确定语法或 API 时不要猜测。
- 使用 API 前确认是否需要 import。
- 调用 API 前确认是否需要对应权限，并检查 `module.json5`。
- 使用依赖库前先核验版本存在且已在对应模块 `oh-package.json5` 声明。
- `@Component` 与 `@ComponentV2` 需结合工程既有代码保持兼容。
- UI 常量优先使用资源文件并通过 `$r` 引用，避免大量写死字面值。
- 国际化新增文案必须补齐所有语言资源。
- 颜色和资源新增需考虑深色模式适配。

## 四、ArkUI 动画与布局规范

- 优先使用官方声明式动画和高级模板。
- 以状态驱动动画为主，避免直接操作大量布局属性。
- 复杂子组件动画使用 `renderGroup(true)` 减少重组开销。
- 避免在动画过程中频繁改变 `width`、`height`、`padding`、`margin` 等布局属性。

## 五、命令行编译与签名（通用流程）

### 5.1 基本原则

- 不要假设 DevEco Studio 安装在 `D:\Program Files\DevEco Studio`，先确认机器上的真实安装路径。
- 不要假设模块名是 `default`，先读取工程根目录 `build-profile.json5`，以实际 `modules[].name`、`targets[].name` 和 `products[].name` 为准。
- 命令行场景优先把证书材料放到工程内 ASCII 路径，例如 `<project>/signing/`，避免中文路径在部分工具链或日志场景中引入歧义。
- 如果 `hvigor assembleHap` 已经产出 unsigned HAP，即可认为“编译和打包成功”；签名失败应单独定位，不要把它和 ArkTS 编译错误混为一谈。

### 5.2 一次性准备

- 安装 DevEco Studio，并确认以下目录真实存在：
- DevEco 根目录，例如 `D:\AAAA\DevEco Studio`
- SDK 目录，例如 `D:\AAAA\DevEco Studio\sdk`
- hvigor 包装脚本，例如 `D:\AAAA\DevEco Studio\tools\hvigor\bin\hvigorw.bat`
- ohpm 包装脚本，例如 `D:\AAAA\DevEco Studio\tools\ohpm\bin\ohpm.bat`
- JBR 目录，例如 `D:\AAAA\DevEco Studio\jbr`

### 5.3 每次编译前推荐流程

- 进入项目根目录。
- 设置 `DEVECO_SDK_HOME` 为实际 SDK 目录。
- 设置 `JAVA_HOME` 为 DevEco 自带 `jbr`，并将 `jbr\\bin` 前置到 `Path`，保证签名和 Java 工具链使用同一套运行时。
- 首次或依赖变更时执行 `ohpm install`。
- 根据 `build-profile.json5` 的真实模块名和产品名执行 `hvigorw.bat --mode module -p module=<module>@<target> -p product=<product> assembleHap`。

### 5.4 PowerShell 模板

```powershell
$env:DEVECO_SDK_HOME = 'D:\AAAA\DevEco Studio\sdk'
$env:JAVA_HOME = 'D:\AAAA\DevEco Studio\jbr'
$env:Path = 'D:\AAAA\DevEco Studio\jbr\bin;' + $env:Path

& 'D:\AAAA\DevEco Studio\tools\ohpm\bin\ohpm.bat' install

& 'D:\AAAA\DevEco Studio\tools\hvigor\bin\hvigorw.bat' `
  --mode module `
  -p module=entry@default `
  -p product=default `
  assembleHap
```

### 5.5 命令行签名稳定方案

- 若 `assembleHap` 卡在 `:SignHap`，先确认 `entry/build/<target>/outputs/<product>/` 下是否已经产出 `*-unsigned.hap`。
- 若已产出 unsigned HAP，优先使用 SDK 自带 `hap-sign-tool.jar` 做后签名，这比依赖 `build-profile.json5` 中的 IDE 加密口令更稳定。
- 如果工程原有 `build-profile.json5` 中的 `storePassword` / `keyPassword` 是 IDE 生成的密文，命令行下可能出现：
- `Init keystore failed`
- `parseAlgParameters failed`
- `storePassword or keyPassword field ... is less than 32`
- 遇到上述问题时，不要继续猜测 hvigor 参数，直接走 unsigned + 后签名链路。

### 5.6 后签名命令模板

```powershell
New-Item -ItemType Directory -Force '.\build\outputs\default' | Out-Null

& 'D:\AAAA\DevEco Studio\jbr\bin\java.exe' `
  -jar 'D:\AAAA\DevEco Studio\sdk\default\openharmony\toolchains\lib\hap-sign-tool.jar' `
  sign-app `
  -mode localSign `
  -keyAlias 'your_alias' `
  -keyPwd 'your_plaintext_key_password' `
  -appCertFile 'D:\path\to\signing\debug.cer' `
  -profileFile 'D:\path\to\signing\debug.p7b' `
  -inFile 'D:\path\to\entry-default-unsigned.hap' `
  -signAlg SHA256withECDSA `
  -keystoreFile 'D:\path\to\signing\your.p12' `
  -keystorePwd 'your_plaintext_store_password' `
  -outFile 'D:\path\to\build\outputs\default\entry-default-signed.hap' `
  -compatibleVersion 21 `
  -signCode 1
```

### 5.7 签名校验模板

```powershell
& 'D:\AAAA\DevEco Studio\jbr\bin\java.exe' `
  -jar 'D:\AAAA\DevEco Studio\sdk\default\openharmony\toolchains\lib\hap-sign-tool.jar' `
  verify-app `
  -inFile 'D:\path\to\build\outputs\default\entry-default-signed.hap' `
  -outCertChain 'D:\path\to\build\outputs\default\verify-cert-chain.cer' `
  -outProfile 'D:\path\to\build\outputs\default\verify-profile.p7b'
```

### 5.8 常见问题快速排查

- 提示 `hvigorw.bat` 不存在：
- 不要用想当然路径，先确认 DevEco 实际安装目录，再使用完整路径。

- 提示 `Unknown module 'xxx'`：
- 模块名写错了。去根目录 `build-profile.json5` 看 `modules[].name` 和 `targets[].name`，重新组合 `module=<name>@<target>`。

- 提示 `Cannot find module 'xxx'`：
- 先执行 `ohpm install`，确认 `oh_modules` 已安装完整。

- 提示 `Init keystore failed` 或 `parseAlgParameters failed`：
- 先用 `keytool -list -storetype PKCS12 -keystore <p12>` 验证 `p12` 是否能用明文密码打开。
- 再确认别名是否真实存在。
- 若 `p12` 可读但 hvigor 签不过，优先走 `hap-sign-tool.jar` 的后签名方案。

- 提示 `storePassword or keyPassword field ... is less than 32`：
- 说明 `build-profile.json5` 当前要求的是 IDE 密文，不接受明文。
- 此时不要再尝试把明文直接塞回 `build-profile.json5`，改走后签名方案。

### 5.9 当前工程实测结论

- 当前工程实测可用的编译主命令是：

```powershell
$env:DEVECO_SDK_HOME = 'D:\AAAA\DevEco Studio\sdk'
$env:JAVA_HOME = 'D:\AAAA\DevEco Studio\jbr'
$env:Path = 'D:\AAAA\DevEco Studio\jbr\bin;' + $env:Path

& 'D:\AAAA\DevEco Studio\tools\ohpm\bin\ohpm.bat' install
& 'D:\AAAA\DevEco Studio\tools\hvigor\bin\hvigorw.bat' --mode module -p module=entry@default -p product=default assembleHap
```

- 当前工程实测 `PackageHap` 成功，可生成：
- `entry/build/default/outputs/default/entry-default-unsigned.hap`

- 当前工程实测可用的后签名命令是：

```powershell
New-Item -ItemType Directory -Force '.\build\outputs\default' | Out-Null

& 'D:\AAAA\DevEco Studio\jbr\bin\java.exe' `
  -jar 'D:\AAAA\DevEco Studio\sdk\default\openharmony\toolchains\lib\hap-sign-tool.jar' `
  sign-app `
  -mode localSign `
  -keyAlias 'kuaitutu' `
  -keyPwd 'KuaiTuTu' `
  -appCertFile 'D:\AKaitutu\ktt-hongmeng\signing\debug.cer' `
  -profileFile 'D:\AKaitutu\ktt-hongmeng\signing\debug.p7b' `
  -inFile 'D:\AKaitutu\ktt-hongmeng\entry\build\default\outputs\default\entry-default-unsigned.hap' `
  -signAlg SHA256withECDSA `
  -keystoreFile 'D:\AKaitutu\ktt-hongmeng\signing\KuaiTuTu.p12' `
  -keystorePwd 'KuaiTuTu' `
  -outFile 'D:\AKaitutu\ktt-hongmeng\build\outputs\default\entry-default-signed.hap' `
  -compatibleVersion 21 `
  -signCode 1
```

- 当前工程实测可验证：
- `build/outputs/default/entry-default-signed.hap`
- `verify-app` 返回 `Verify success`