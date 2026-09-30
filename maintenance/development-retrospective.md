# 开发复盘

## 架构取舍

- `format_model` 定义 Ion 值、符号、数值、错误和资源限制；`decode` 与 `encode` 分别处理文本/二进制读取和写出，根包提供常用操作的简短入口。
- 值模型保留注解、symbol ID、struct 字段顺序和重复字段；解析与写出提供深度、值数量、容器大小和载荷等资源限制，避免调用方无意中接受不受限输入。
- 首版聚焦 Amazon Ion 1.0。Ion 1.1、shared symbol catalog、Ion Schema、Ion Hash、压缩和完整流式 API 明确留作后续工作，避免把未实现能力误报为当前支持范围。

## AI 工具使用

项目开发中使用 Codex / ChatGPT 辅助 MoonBit 代码编写和仓库结构规划。代码方面，AI 协助生成或补全 Ion 值模型、文本与二进制解析和写出，以及错误处理、资源限制等实现片段；结构方面，协助梳理 `format_model`、`decode`、`encode`、根包 API、示例和维护文档的职责与目录布局。生成内容由开发者审阅、修改并整合；实现以 Amazon Ion 1.0 规范为依据，并通过项目测试、构建和互操作检查进行验证。

## 规范与代码来源

核心实现依据公开的 [Amazon Ion 1.0 规范](https://amazon-ion.github.io/ion-docs/docs/spec.html) 独立完成，没有从其他 Ion 实现移植代码。Amazon 官方实现列表和各项规范链接见 [`upstream-map.md`](upstream-map.md)。仓库中的小型 fixture 为原创互操作样例；`roundtrip_lab` 使用 `amazon-ion/ion-js` 5.2.1 做开发时语义对照，不作为运行时依赖。

## 后续维护

维护时应保留声明范围与实际实现的一致性，扩充测试和互操作 fixture，并记录外部 fixture 的来源、版本和许可证。多目标构建、MoonBit 测试矩阵和 `ion-js` 对照检查通过后，再把对应提交和 CI 结果作为发布或验收证据。
