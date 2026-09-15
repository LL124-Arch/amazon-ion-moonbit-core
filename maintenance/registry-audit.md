# Mooncakes overlap record

记录日期：2026-09-15  
记录对象：Mooncakes.io 的公开搜索结果  
数据来源：[mooncakes.io 源码](https://github.com/moonbitlang/mooncakes.io) 中公开的 `GET /api/v0/search?kw=...&limit=20` 接口。

这是一份面向本数据格式库的重合度记录，不是竞赛申报、参赛评审或提交前检查模板。它只回答两个问题：候选格式是否已有同题 codec，以及命中项目覆盖到哪一层。

## 判定口径

- 直接重合：同一格式并提供 parser/decoder 或 encoder/writer。
- 高度重合：同一格式的验证、转换、查询或完整工具链。
- 邻近项目：处理上层业务或相关格式，但不直接替代本库。

查询词族包含格式全称、扩展名、MIME、常见实现名、parser、decoder、encoder、serializer 和 GitHub 仓库名。搜索摘要没有稳定提供版本、更新时间或下载量；缺失字段统一记为“搜索接口未提供”，不作推测。

## 本次快照

| 格式 | 查询范围 | 结果 | 与本库关系 |
| --- | --- | --- | --- |
| Amazon Ion | `ion`, `amazon ion`, `.ion`, `application/ion`, parser/decoder/encoder/serializer | 未发现直接维护良好的 Ion codec | 目标格式 |
| UBJSON | `ubjson`, `.ubj`, `application/ubjson`, parser/decoder/encoder | 未发现直接维护良好的 UBJSON codec | 备选格式 |
| HDF5 | `hdf5`, `hdf`, reader/writer/parser | 未发现直接维护良好的 HDF5 包；对象模型复杂 | 高风险备选 |
| YAML / TOML / CSV / XML | 全称、扩展名、MIME、parser/decoder/encoder | 有明显包覆盖 | 排除的格式方向 |
| CBOR / MessagePack / Parquet / Avro | 全称、扩展名、MIME、parser/decoder/encoder | 有明显包覆盖 | 排除的格式方向 |
| JSON Patch / OpenAPI / glTF / iCalendar | 全称、扩展名、MIME、工具链词 | 有明显包覆盖 | 邻近工具方向 |

## 代表性命中

| 方向 | 代表包或仓库 | 覆盖范围 | 版本 / 更新时间 / 下载量 |
| --- | --- | --- | --- |
| YAML | `moonbit-community/yaml` | YAML parser/encoder | 搜索接口未提供 |
| TOML | `bobzhang/toml` | TOML parser | 搜索接口未提供 |
| CSV | `maria/csv_parser` | CSV parser | 搜索接口未提供 |
| XML | `Milky2018/xml` | XML parser/encoder | 搜索接口未提供 |
| CBOR | `mizchi/cbor` | CBOR codec | 搜索接口未提供 |
| MessagePack | `hackwaly/msgpack` | MessagePack codec | 搜索接口未提供 |
| Parquet | `mizchi/parquet` | Parquet 数据格式 | 搜索接口未提供 |
| Avro | `yugonlian/moon-avro` | Avro 数据格式 | 搜索接口未提供 |
| JSON Patch | `Xu107-hhh/moonbit-jsonpatch` | JSON Patch 工具 | 搜索接口未提供 |

## 解释

Ion 仍具有清晰的规范、多个跨语言实现、文本/二进制双表示以及 annotation、SID 和 local symbol table 等扩展机制。本次结果没有显示 Mooncakes 上存在直接维护良好的 Ion codec；UBJSON 和 HDF5 仅作为对照候选记录，不是本库依赖。

这是一个有日期的 registry snapshot。若依赖范围、包名或目标版本发生变化，应重新执行同一组查询，并重新阅读命中项目的 README、源码和许可证；这不是自动化的发布结论。
