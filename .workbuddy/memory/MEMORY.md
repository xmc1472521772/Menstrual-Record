# Menstrual-Record 项目长期记忆

## 基本信息
- 当前版本：**1.33.1+104**（2026-09-08，fix 小组件同步 + 对象库恢复快照）
- 架构、命令、主题系统等见 AGENTS.md；版本规范：每次更新必须递增版本号

## 关键约定（新增/更新）
- **Provider 获取规则**：`app.dart` 的 `_MyAppState` 在 `initState` 中直接创建 `PeriodProvider`/`SettingsProvider` 实例（late final 字段），以 `ChangeNotifierProvider<T>.value` 注入 `MultiProvider`；生命周期回调直接引用字段。**禁止**在该 State 的回调里用 `context.read`（context 在 MultiProvider 上方，必然抛 ProviderNotFoundException）
- **小组件同步机制**（三代演进后的现状）：原生 `WidgetActionReceiver` 直接写 SQLite → `WidgetDataStore.setDataDirty(true)` → MethodChannel `dataChanged` 通知（前台即时）；App 恢复前台时 `checkDataDirty()` 兜底（后台时 MethodChannel 可能丢失）；`loadRecords(forceRefresh: true)` 会刷新数据库连接
- **Git 铁律**：① 绝不使用 `git stash`（2026-09-08 曾因 stash 被中断导致对象库损坏）；② **定期推 origin 备份**（本次靠用户昨晚的推送才救回 104 个提交，当天未推送的 11 个提交对象丢失）；③ 多组独立改动拆分本地 commit
- **Git 现状（事故后已恢复）**：main = `97133cb`（今日11个未推送提交的内容合并 + 小组件同步修复）→ `e3cbbda`（昨晚推送点，含完整 104 个提交历史，对象已从 GitHub fetch 回本地）。仅今日 11 个提交失去独立粒度（消息记录在 `.git/logs/HEAD` reflog）。损坏前 .git 备份在 `../Menstrual-Record-git-backup-20260908/`
- **诊断教训**：判断远程状态必须用 `git ls-remote` 直查，不能依赖本地 refs/remotes（refs 损坏/陈旧时会误判）；事发时 origin/main 曾短暂显示为陈旧的 21b3aaf，导致误报"历史全丢"
- **测试沙箱绕过**：`env 'PROGRAMFILES(X86)=C:/Program Files (x86)'`（export 不接受括号名）+ 清代理 + PATH 前置 `C:/Users/xmc/.workbuddy/binaries/python/versions/3.13.12/DLLs`
- 测试 mock 类 `implements DatabaseProvider` 时必须实现全部成员（含 `refreshConnection`），新增接口成员要同步改 mock

## 存量问题（未修，非阻塞）
- `lib/database/database_helper.dart:153` 缺 `@override` 注解（info）
- `lib/screens/home_screen.dart:637` use_build_context_synchronously（info）
