# DSH 能力清单与 NcnsDSH 的扩容映射

来源：本机 DSH 运行时 `/opt/dsh/nodejs-project`（`plugins/ios-native/tools.mjs`、
`plugins/ios-host`、`plugins/sandbox-ios`、`plugins/subprocess-ios`）。
结论只依据读到的源码，不含猜测。

## 1. DSH 暴露给模型的工具（ios-native）

每个能力一个工具，能力不存在时工具根本不注册：

| 工具 | 能力 | NcnsDSH 状态 |
|---|---|---|
| `device_info` | 设备型号、系统、电量、存储 | ✅ 2.0.3 已实现 |
| `notify` | 本地通知 | ✅ 2.0.3 已实现 |
| `clipboard` | 读写剪贴板 | ✅ 2.0.3 已实现 |
| `open_url` | 系统浏览器打开链接 | ✅ 2.0.3 已实现 |
| `files` | 文件选择/导出 | ⏳ 工作区文件已有，系统文件 App 未接 |
| `speak` | 语音朗读 | ⏳ 待接 AVSpeechSynthesizer |
| `browser` | 内置浏览器抓取/截图 | ⏳ 工作台浏览器已有，抓取未接 |
| `text_analysis` | 语言/实体识别 | ⏳ 待接 NLTagger |
| `image_analysis` | 图片文字/分类 | ⏳ 待接 Vision |
| `transcribe_audio` | 音频转写 | ⏳ 待接 Speech |
| `calendar` / `reminders` | 日历、提醒事项 | ⏳ 需要权限流程 |
| `photos` | 相册读写 | ⏳ 需要权限流程 |
| `location` / `maps` / `weather` | 定位与天气 | ⏳ 需要权限流程 |
| `contacts` | 通讯录 | ⏳ 需要权限流程 |
| `health` | 健康数据 | ⏳ 需要权限流程 |
| `homekit` | 家庭 | ⏳ 需要权限流程 |
| `music` | 音乐库与控制 | ⏳ 可先做「现在播放」只读 |
| `alarm` | 系统闹钟 | ⏳ iOS 26 能力，需真机验证 |
| `compose` | 邮件/信息草稿 | ⏳ 需 Mail/Messages 账户 |

## 2. 运行时插件（ios-*）

| 插件 | 作用 | 对 NcnsDSH 的启示 |
|---|---|---|
| `ios-host` | 宿主生命周期、内置插件开关、重启请求 | 对应我们的构建/更新与重启按钮 |
| `ios-native` | 原生能力桥（上文） | 我们直接写 Swift 等价实现 |
| `ios-speech` | 语音合成/识别桥 | 后续做朗读与语音输入 |
| `sandbox-ios` | 沙盒路径约束 | 我们已有 `AppFiles` + 路径校验 |
| `subprocess-ios` | 子进程（受限） | 我们的迷你 shell 不执行子进程，保持一致 |

## 3. 设计上要遵守的 DSH 规则

1. **能力不可用时不要注册工具**——模型看不到它，就不会调用不存在的功能。
   NcnsDSH 的处理：工具列表按能力动态生成，未授权的能力不出现。
2. **写操作要确认**：DSH 把确认放在原生主线程；我们对写文件/删除也要保留确认。
3. **审计**：DSH 记录调用者名字；我们至少在活动时间线里显示工具名与结果。
4. **不承诺插件 API**：DSH 明确插件调用是未版本化路径；我们的插件模块也应保持「只读目录 + 明确标注」。

## 4. 本轮已落地（2.0.3）

- 新增四个本机工具：`device_info`、`open_url`、`clipboard`、`notify`，描述与参数风格对齐 DSH。
- 会话内真实执行阶段：思考 → 生成 → 工具调用 → 完成/失败，数据来自 `LocalEvent`，
  不是定时器伪造。
- 会话命令菜单：清空输入、压缩上下文、复制全文、导出会话。

## 5. 下一批候选（按价值排序）

1. `files` + `speak`：补全输入输出两端（选文件、朗读回复）。
2. `text_analysis` / `image_analysis`：Vision + NLTagger，纯本机、无需权限。
3. 通知中心：把「任务完成」做成可设置的本地通知（已有 `notify` 作为底座）。
4. 语音输入：Speech framework，权限流程走通后再注册工具。
