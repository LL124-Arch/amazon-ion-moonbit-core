# 验收演示与互操作检查

本目录记录面向评审的最小可复现演示。示例只调用公开包 API；互操作脚本使用 Amazon 官方 `amazon-ion/ion-js` 作为开发期对照，不会成为 MoonBit 模块的运行时依赖。

## 环境要求

- MoonBit CLI；本次本地验证环境为 `moon 0.1.20260920`，可先运行 `moon version --all` 查看版本。
- Node.js 和 npm；`package-lock.json` 固定互操作检查所用的 `ion-js` 5.2.1。

## MoonBit 示例

在仓库根目录运行：

```text
moon fmt --check
moon check
moon test
moon run examples/tiny_read
moon run examples/tiny_write
```

预期示例输出：

```text
{service: "ion", enabled: true}
{message: "hello from MoonBit", answer: 42}
```

## 官方 Ion 实现互操作检查

在仓库根目录运行：

```text
cd roundtrip_lab
npm ci
node ion-js-diff.mjs
```

成功时脚本输出包含 `"oracle":"amazon-ion/ion-js"`、`"version":"5.2.1"` 和 `"result":"passed"` 的 JSON。检查覆盖二进制标量 fixture、带注解且含重复字段的 struct 文本解析、二进制往返，以及截断二进制输入拒绝。

脚本检查 Ion 值语义，不比较编码后的字节是否完全相同；规范允许多个有效的符号表和长度编码。fixture 以可审阅的文本和十六进制形式保存在 `fixtures/`。

这些演示是有边界的 Ion 1.0 互操作 smoke check，不代表完整规范一致性套件。
