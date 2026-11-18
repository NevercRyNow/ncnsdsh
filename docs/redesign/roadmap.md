# NcnsDSH 2.0 · 路线图

每阶段独立可编译、可回滚；完成一阶段才进下一阶段。

## 阶段与验收

| # | 阶段 | 交付 | 验收 |
|---|---|---|---|
| 0 | 研究 | `docs/redesign/{research,design-system,architecture,roadmap}.md` | 文档落地、有源码依据 |
| 1 | 设计系统 | `Core/Haptics`、`DSH` token 补全、`GlassGroup`、空状态组件 | 编译通过；旧 API 不破 |
| 2 | 首页 | Command Center：品牌栏、当前状态、Quick Actions、Recent Projects、Activity | 小屏不溢出；数据接真实 Store |
| 3 | 导航 | Home / Projects / Sessions / Workbench / More + iPad 侧栏 | 深链与 Intent 仍可用 |
| 4 | 项目 | Projects 列表/详情（Overview/Files/Sessions/Tasks/Git/Activity） | 数据来自工作区，无假数据 |
| 5 | 会话 | 搜索/收藏/重命名/导出/关联项目；Agent Activity Timeline | 状态由真实执行驱动 |
| 6 | 工作台 | 终端多标签、文件树/编辑、浏览器多标签、改动 Diff、上下文策略 | 不越权、不伪造命令 |
| 7 | 自动化 | 轻量流程（定时/手动/事件），执行记录 | 未支持的触发明确标注 |
| 8 | 设备 | 配对、状态、延迟、重连、诊断 | 基于真实 gateway 协议 |
| 9 | 构建 | 队列、日志、历史、版本比较、发布记录 | 仍用 run id + latest-build |
| 10 | 设置 | 声明式分组 + 搜索 + 状态详情 | 搜索能命中任意设置 |
| 11 | 交互 | 手势、动画、触觉、空状态统一 | Reduce Motion 全通过 |
| 12 | 架构 | 目录迁移到 Features/*，统一错误/加载/Toast | 无重复 Router，无主线程阻塞 |
| 13 | 测试 | 单元 + 布局 + 关键交互 | CI 绿，含测试目标 |

## 顺序与依赖

```
0 ─► 1 ─► 3 ─► 2 ─► 5 ─► 6 ─► 4 ─► 10 ─► 11 ─► 7 ─► 8 ─► 9 ─► 12 ─► 13
```

- 3 先于 2：导航骨架定了，首页才好挂。
- 5 先于 4：会话是项目的下游数据，先稳定。
- 8 依赖 5：设备负责连接，会话负责呈现。

## 本周批次（可执行）

1. **批次 A**：Haptics 集中化 + token 补全 + `GlassGroup` + Tab 选择触觉。
2. **批次 B**：导航收口（Route 枚举 + More Tab）+ iPad 侧栏复用。
3. **批次 C**：首页 Command Center（真实数据：运行中会话、最近构建、工作区）。
4. **批次 D**：会话 Agent Activity Timeline（真实状态机）+ 命令菜单。

## 风险

| 风险 | 处理 |
|---|---|
| mobile-gateway 协议未接 | 先做适配层与「未连接」状态，不用假数据 |
| macOS runner 不稳定 | 保留 `cron */30` 与 `latest-build` |
| 一次性大改导致回归 | 每阶段一个 PR 规模，CI 必须绿 |
| 设计系统与旧代码并存 | 旧 API 保留别名，迁移完成后删 |
