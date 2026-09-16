# Amazon Ion for MoonBit

这是一个面向 MoonBit 的 Amazon Ion 1.0 数据格式库。它把同一组值映射到 Ion 文本和 Ion 二进制两种表示，适合配置交换、跨语言 fixture、消息边界和需要长期保留类型信息的应用。

库的核心取舍是：公共值模型保持数据的结构与顺序，解码过程默认有资源上限，写出过程保持输入顺序并产生稳定结果。这样可以在不引入文件系统、网络或 C 依赖的情况下，将 codec 嵌入 native、WebAssembly 和 JavaScript 程序。

## 包布局

| 包 | 作用 |
| --- | --- |
| `format_model` | Ion 值、symbol、decimal、timestamp、限制和错误模型 |
| `decode` | 文本扫描解析与二进制读取 |
| `encode` | 文本写出与二进制写出 |
| 根包 | 对常用 parse/encode 操作的简短转发 API |
| `fixtures` | 小型有效样例与覆盖说明 |
| `maintenance` | 规范、互操作性和 Mooncakes 检索记录 |

## 支持范围

当前实现覆盖 Ion 1.0 的 null、bool、整数、Float、decimal、timestamp、string、symbol、blob、clob、list、sexp、struct、类型注解和局部符号表。文本端也支持长字符串、长 clob、数值分隔符和常用 Ion 转义。

`IonValue` 会保留未知 symbol SID、annotation 顺序、struct 字段顺序和重复字段。文本与二进制写出采用保序确定性策略，但不宣称实现外部 Canonical Ion 标准。

解析器和写出器都支持深度、值数量、容器元素数量、文本字节数、blob/clob 字节数、总输入字节数和 symbol 数量限制。格式错误包含稳定错误类别；二进制错误带字节偏移，文本错误带行列位置。

以下能力明确留给后续版本：Ion 1.1、shared symbol table catalog、Ion Schema、Ion Hash、压缩、文件系统 I/O、零拷贝和完整流式 API。遇到未实现的扩展时会返回错误，不静默降级。

## 最小用法

```moonbit
import { "liangqinsheng/ion" @ion }

let values = @ion.parse_text("{answer: 42, enabled: true}")
let binary = @ion.encode_binary(values[:])
let decoded = @ion.parse_binary(binary)
let text = @ion.encode_text(decoded[:])
```

需要更细的包边界时，可以直接使用 `decode`、`encode` 和 `format_model`。`examples/tiny_read` 展示文本读取后再写出，`examples/tiny_write` 展示从模型构造 struct 并生成文本。

## 文档序列处理

根包还提供面向完整、有界文档的序列操作：`slice_values` 选择零基范围，`filter_values_by_kind` 按 Ion 类型筛选，`merge_documents` 按输入顺序合并多个文档并检查配置的值、深度、符号、载荷和容器限制。`reencode_text_range` 与 `reencode_binary_range` 则复用解析器和写出器来选择一段文档值并生成新的完整文档；二进制输出的版本标记由输出选项控制。它们不是流式 API。

## 互操作诊断

`encode_hex` 和 `decode_hex` 提供稳定的小写十六进制转换；解码器允许 ASCII 空白与 `#` 行注释，因而可以直接读取仓库中的可审查二进制 fixture。`decode_hex` 会拒绝非十六进制字符和不完整字节对。`IonError::location()` 将错误的偏移、行和列封装为 `IonLocation`，`IonError::summary()` 则提供适合日志的稳定摘要。需要核对同一文档的两种表示时，`diagnose_text_binary` 返回两端的顶层值数量和精确匹配结果；比较不会重排字段、丢弃重复字段、注解或未解析 symbol SID。

## 验证与样例

仓库中的 `fixtures/valid` 保存文本样例和最小二进制样例；`ion_test.mbt` 覆盖空容器、嵌套值、注解、重复字段、符号表、decimal、timestamp、blob/clob、截断输入和资源限制。

```text
moon fmt
moon check --deny-warn
moon test
moon test --target native
moon test --target wasm
moon test --target wasm-gc
moon test --target js
moon build --target native
moon build --target wasm
moon build --target js
moon doc --quiet
```

## 规范参考

实现边界以 [Amazon Ion 1.0 规范](https://amazon-ion.github.io/ion-docs/docs/spec.html)、[Ion 文本文法](https://amazon-ion.github.io/ion-docs/docs/text.html) 和 [Ion 二进制规范](https://amazon-ion.github.io/ion-docs/docs/binary.html) 为准。跨语言实现可从 [Amazon Ion 官方实现列表](https://amazon-ion.github.io/ion-docs/libs.html) 继续核对。

## 许可证

Apache-2.0，见 [`LICENSE`](LICENSE)。
