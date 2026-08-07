# Spark Optic

Spark Optic 当前实现的是 Spark 任务画像与优化诊断的真实可用 MVP。

本版只聚焦三件事：

- 通过配置 Spark History Server 地址自动拉取 Spark application、stage、task metrics。
- 通过 HTTP Listener 接口接收 Spark 运行事件。
- 基于真实采集指标生成任务画像、资源小时聚合和优化诊断。

其他平台能力不在当前版本范围内。

## 启动真实模式

不要把真实密码写入仓库文件，启动时通过环境变量传入：

```bash
SPARK_OPTIC_MODE=real \
SPARK_OPTIC_MYSQL_HOST=172.29.30.61 \
SPARK_OPTIC_MYSQL_PORT=3306 \
SPARK_OPTIC_MYSQL_DATABASE=spark_optic \
SPARK_OPTIC_MYSQL_USER=root \
SPARK_OPTIC_MYSQL_PASSWORD='your-mysql-password' \
SPARK_OPTIC_DORIS_HOST=172.29.30.116 \
SPARK_OPTIC_DORIS_PORT=9030 \
SPARK_OPTIC_DORIS_DATABASE=spark_optic \
SPARK_OPTIC_DORIS_USER=root \
SPARK_OPTIC_DORIS_PASSWORD='' \
SPARK_OPTIC_PUBLIC_BASE_URL=http://127.0.0.1:8000 \
SPARK_OPTIC_HISTORY_SERVER_URL=http://spark-history-server:18080 \
SPARK_OPTIC_HISTORY_DAILY_PULL_TIME=02:00 \
python3 run.py
```

打开：

```text
http://127.0.0.1:8000
```

## 初始化库表

MySQL：

```bash
mysql -h "$SPARK_OPTIC_MYSQL_HOST" -P "$SPARK_OPTIC_MYSQL_PORT" \
  -u "$SPARK_OPTIC_MYSQL_USER" -p"$SPARK_OPTIC_MYSQL_PASSWORD" \
  "$SPARK_OPTIC_MYSQL_DATABASE" < db/mysql/001_init.sql
```

Doris：

```bash
mysql -h "$SPARK_OPTIC_DORIS_HOST" -P "$SPARK_OPTIC_DORIS_PORT" \
  -u "$SPARK_OPTIC_DORIS_USER" -p"$SPARK_OPTIC_DORIS_PASSWORD" \
  "$SPARK_OPTIC_DORIS_DATABASE" < db/doris/001_init.sql
```

## Spark History Server 自动拉取

页面入口：

```text
http://127.0.0.1:8000/#ingest
```

API：

```bash
curl -X POST "http://127.0.0.1:8000/api/history-server/pull" \
  -H "Content-Type: application/json" \
  -d '{"base_url":"http://spark-history-server:18080","business_date":"2026-08-04"}'
```

后台自动拉取由环境变量控制；不按条数截断，按业务日期窗口拉取：

```bash
SPARK_OPTIC_HISTORY_SERVER_URL=http://spark-history-server:18080
SPARK_OPTIC_HISTORY_DAILY_PULL_TIME=02:00
```

默认业务日期是“昨天”。例如 2026-08-05 02:00 运行定时任务时，拉取 2026-08-04 00:00:00 到 2026-08-05 00:00:00 的 application。

当前实现调用 Spark History Server REST API：

- `/api/v1/applications`
- `/api/v1/applications/{app_id}/environment`
- `/api/v1/applications/{app_id}/stages`
- `/api/v1/applications/{app_id}/stages/{stage_id}/{attempt_id}/taskSummary`

EventLog 文件解析器保留为底层备用能力，不作为主要产品入口。

## Listener 上报

接口：

```text
POST http://127.0.0.1:8000/api/listener/events
```

请求体可以是单个 Spark event JSON，也可以是：

```json
{
  "task_key": "your_task_key",
  "events": [
    { "Event": "SparkListenerApplicationStart" }
  ]
}
```

Spark 侧示例配置：

```properties
spark.extraListeners=com.yourcompany.sparkoptic.SparkOpticListener
spark.sparkoptic.reporter=http
spark.sparkoptic.endpoint=http://127.0.0.1:8000/api/listener/events
spark.sparkoptic.flushIntervalMs=5000
spark.sparkoptic.maxQueueSize=10000
```

## 当前诊断规则

- 数据倾斜：使用 Task Duration 的 P95/P50、Max/P50 识别长尾。
- Shuffle / Spill 过高：使用 Shuffle Read/Write 和 Memory/Disk Spill 判断。
- Executor CPU 利用率偏低：使用 executor run time 与 stage 容量估算。

## 测试

```bash
pytest -q
```

## 我还需要你提供

要验证真实生产任务，需要你提供以下任意一种：

- Spark History Server 访问地址，例如 `http://host:18080`。
- 如果 History Server 有认证或网关，需要提供认证方式。
- 已经能发 HTTP 的 Listener Hook 样例事件。

---

## 部署与迁移说明（新增）

- MySQL 初始化脚本：`db/mysql/001_init.sql` 已新增 `ingestion_warnings` 表，用于持久化解析警告（warnings JSON）。请在 MySQL 上执行初始化脚本以创建表格。

- Doris 初始化脚本：`db/doris/001_init.sql` 中的 JSON-like 字段（例如 `resource_config_json`、`warnings_json`）使用 `STRING` 类型以提高对不同 Doris 版本的兼容性。应用会把 JSON 文本写入这些列。

- 建议步骤（在生产环境）：
  1. 在目标 MySQL 上执行 `db/mysql/001_init.sql`。
  2. 在目标 Doris 上执行 `db/doris/001_init.sql`（或按你集群的 DDL 方式执行）。
  3. 配置最小权限的 DB 用户（不要长期使用 root），并在环境变量中设置连接信息。

## 观测与运维（新增）

- 日志：服务输出结构化 JSON 日志到 stdout（字段包括 timestamp、level、logger、message、可选 exc_info），便于集中式日志收集。

- 指标：暴露 Prometheus 文本导出接口 `/metrics`，包括计数器：
  - `spark_optic_accepted_events_total` — listener 接受的事件数
  - `spark_optic_parse_warnings_total` — 解析时生成的警告数
  - `spark_optic_save_failures_total` — 保存到后端失败的次数

- Listener 认证（可选）：通过环境变量 `SPARK_OPTIC_LISTENER_TOKEN` 启用。启用后，请在客户端请求头中添加 `X-API-Key: <token>`。

## 其他

- 我可以把本地修改推送并创建一个 Draft Pull Request（如果你把仓库推到远端），也可以生成迁移脚本（ALTER TABLE）来在现有表上添加 `warnings_json`。如需我执行其中一步，请告知。
