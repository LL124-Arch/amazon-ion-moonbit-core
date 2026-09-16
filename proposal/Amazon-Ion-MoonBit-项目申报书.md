# Amazon Ion for MoonBit 项目申报书

| 项目 | Amazon Ion for MoonBit——面向跨语言数据交换的双表示数据格式库 |
|---|---|
| 参赛者 | 梁钦胜 |
| 联系电话 | 15362196148 |
| 维护账号 / 仓库 | `LL124-Arch` / [amazon-ion-moonbit-core](https://github.com/LL124-Arch/amazon-ion-moonbit-core) |
| 许可证 | Apache-2.0 |

## 项目概述

Amazon Ion 是同时提供文本和二进制表示的数据格式，适合配置审查、跨语言消息交换和高保真测试 fixture。项目为 MoonBit 提供 Ion 1.0 的统一值模型、文本解析与写出、二进制解析与写出，保留 decimal、timestamp、symbol、blob、clob、注解、重复字段和 struct 字段顺序，解决 JSON 难以保留完整类型语义、两套 codec 容易产生差异的问题。

## 对初审问题的正面回答

**是否属于 MoonBit 生态建设？** 是。项目是可复用的底层数据格式库，不依赖特定应用；`format_model`、`decode`、`encode` 分层后，可用于配置交换、消息边界、数据迁移和跨语言测试，并面向 native、WebAssembly、JavaScript 目标验证。

**范围是否清晰、能否落地？** 是。首版覆盖 null、bool、整数、浮点、decimal、timestamp、string、symbol、blob、clob、list、sexp、struct、类型注解和 local symbol table，并提供稳定错误类别、字节偏移/文本行列位置及深度、数量、载荷和符号表资源限制。Ion 1.1、shared symbol table catalog、Ion Schema、Ion Hash、压缩、文件 I/O、零拷贝和完整流式 API 明确留作后续版本，避免首版承诺失控。

**是否与现有选题重复？** 已于 2026-09-16 按格式全称、`.ion` 扩展名、MIME、常见实现名、parser/decoder/encoder/serializer 和仓库名等关键词复核 Mooncakes.io，未发现直接维护良好的 Ion codec；已有 YAML、TOML、CSV、XML、CBOR、MessagePack、Parquet、Avro 等方向不纳入本项目。检索范围、判定口径和排除理由记录于 `maintenance/registry-audit.md`。

**是否有可验证成果？** 是。仓库包含文本/二进制 round-trip、空容器、嵌套容器、重复字段、注解、符号表、decimal、timestamp、截断输入和资源限制测试；`moon check --deny-warn`、native/wasm/wasm-gc/js 测试矩阵、native/wasm/js 构建和文档生成均已在本地验证。`roundtrip_lab` 使用官方 `amazon-ion/ion-js` 5.2.1 对标量、注解 struct、重复字段、二进制 round-trip 和截断二进制输入进行可重复差分检查。

## 技术贡献与持续维护

公共模型保留未知 annotation、symbol 和字段顺序，writer 采用保序确定性策略但不冒充外部 Canonical Ion 标准；解析器拒绝未支持扩展的静默恢复。项目已补齐 `moon.mod` 的仓库元数据，使模块名、GitHub 归属和计划中的 Mooncakes 包名统一为 `LL124-Arch/amazon-ion-moonbit-core`；CI 改用当前格式化器兼容的 `moon fmt --check`，并加入多目标构建、官方 Ion 差分任务。兼容性记录、变更记录、fixture 来源和示例均随仓库公开维护。

本申报阶段只完成发布准备和本地验证，不执行 `moon publish`，不将包发布到 Mooncakes.io；正式发布须由参赛者确认账号、版本和许可证元数据后另行决定。项目以 Apache-2.0 开源，优先持续完善兼容性矩阵、错误诊断、测试覆盖和文档，再评估 Schema、Hash 与流式扩展。

**申报结论：** 项目目标用户明确、首版边界可控、实现与验证证据完整，能够为 MoonBit 提供面向真实跨语言数据交换场景的可维护基础库。
