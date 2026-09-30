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

成功时脚本输出包含 `"oracle":"amazon-ion/ion-js"`、`"version":"5.2.1"` 和 `"result":"passed"` 的 JSON。脚本会双向执行：MoonBit 产生的文本和二进制由 `ion-js` 解析；`ion-js` 产生的文本和二进制由 MoonBit 解析。样例覆盖注解、重复 struct 字段、大整数、双精度浮点数和负零、decimal、timestamp、blob/clob、sexp/list，并检查截断 VarUInt 被 MoonBit 拒绝。

脚本比较 Ion 值语义，不要求两种实现生成完全相同的字节布局；规范允许不同的有效长度编码和符号表布局。

这些演示是有边界的 Ion 1.0 互操作 smoke check，不代表完整规范一致性套件。
