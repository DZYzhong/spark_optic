create table if not exists spark_application_fact (
  app_id varchar(255),
  task_key varchar(255),
  app_name varchar(512),
  queue varchar(128),
  start_time datetime,
  end_time datetime,
  duration_ms bigint,
  status varchar(32),
  executor_cores int,
  executor_memory_gb int,
  -- Use STRING for JSON-like payloads for maximum Doris compatibility across versions.
  -- Newer Doris supports JSON type; older versions may not. Storing as STRING (TEXT) keeps
  -- the initialization script portable and lets applications still store JSON text.
  resource_config_json string,
  warnings_json string
)
duplicate key(app_id, task_key)
distributed by hash(app_id) buckets 16
properties("replication_num" = "1");

create table if not exists spark_stage_metric_fact (
  app_id varchar(255),
  stage_id int,
  attempt_id int,
  task_count int,
  duration_ms bigint,
  input_bytes bigint,
  shuffle_read_bytes bigint,
  shuffle_write_bytes bigint,
  memory_spill_bytes bigint,
  disk_spill_bytes bigint,
  gc_time_ms bigint,
  executor_run_time_ms bigint,
  max_task_duration_ms bigint,
  p50_task_duration_ms bigint,
  p95_task_duration_ms bigint,
  executor_cpu_utilization double
)
duplicate key(app_id, stage_id, attempt_id)
distributed by hash(app_id) buckets 16
properties("replication_num" = "1");

create table if not exists diagnosis_finding_fact (
  app_id varchar(255),
  task_key varchar(255),
  rule_id varchar(128),
  severity varchar(32),
  score int,
  evidence_json json,
  recommendation_json json,
  estimated_saving_json json,
  confidence double,
  created_at datetime
)
duplicate key(app_id, task_key, rule_id)
distributed by hash(task_key) buckets 16
properties("replication_num" = "1");

create table if not exists resource_hourly_fact (
  event_date date,
  hour int,
  queue varchar(128),
  task_key varchar(255),
  cpu_core_hour double,
  memory_gb_hour double,
  executor_hour double,
  shuffle_read_bytes bigint,
  shuffle_write_bytes bigint
)
duplicate key(event_date, hour, queue, task_key)
distributed by hash(task_key) buckets 16
properties("replication_num" = "1");
