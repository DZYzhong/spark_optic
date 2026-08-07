create table if not exists data_source_config (
  id bigint primary key auto_increment,
  name varchar(128) not null,
  status varchar(32) not null,
  coverage varchar(64) not null,
  purpose varchar(255) not null,
  created_at timestamp default current_timestamp
);

create table if not exists task_definition (
  task_key varchar(255) primary key,
  task_name varchar(255) not null,
  queue varchar(128) not null,
  priority int not null default 0,
  sla_deadline varchar(16),
  runnable_window_start varchar(16) not null default '00:00',
  runnable_window_end varchar(16) not null default '23:59',
  expected_duration_minutes int not null default 30,
  cpu_cores int not null default 10,
  source_type varchar(32) not null default 'UNKNOWN',
  source_ref varchar(1024),
  enabled boolean not null default true
);

create table if not exists table_profile (
  table_fqn varchar(512) primary key,
  database_name varchar(255),
  table_name varchar(255) not null,
  storage_format varchar(64),
  observed_read_count bigint not null default 0,
  observed_write_count bigint not null default 0,
  last_read_at timestamp null,
  last_write_at timestamp null,
  last_observed_partition varchar(255),
  profile_source varchar(32) not null,
  confidence decimal(5, 4) not null default 0.5000,
  updated_at timestamp default current_timestamp
);

create table if not exists lineage_edge (
  id bigint primary key auto_increment,
  edge_key char(64) not null,
  from_type varchar(16) not null,
  from_id varchar(512) not null,
  to_type varchar(16) not null,
  to_id varchar(512) not null,
  edge_type varchar(32) not null,
  confidence decimal(5, 4) not null,
  source varchar(32) not null,
  observed_at timestamp default current_timestamp,
  unique key uk_lineage_edge (edge_key),
  key idx_lineage_from (from_type, from_id),
  key idx_lineage_to (to_type, to_id)
);

create table if not exists schedule_simulation (
  id bigint primary key auto_increment,
  name varchar(255) not null,
  business_date date not null,
  objective varchar(64) not null,
  constraints_json json,
  current_metrics_json json,
  recommended_metrics_json json,
  recommendations_json json,
  created_at timestamp default current_timestamp
);

create table if not exists worker_run (
  id bigint primary key auto_increment,
  worker_name varchar(128) not null,
  status varchar(32) not null,
  started_at timestamp default current_timestamp,
  finished_at timestamp null,
  message text
);

create table if not exists failed_record_quarantine (
  id bigint primary key auto_increment,
  source_name varchar(128) not null,
  record_key varchar(512) not null,
  reason text not null,
  payload_json json,
  created_at timestamp default current_timestamp
);

-- store ingestion warnings per application for easier debugging and auditing
create table if not exists ingestion_warnings (
  id bigint primary key auto_increment,
  app_id varchar(255) not null,
  task_key varchar(255),
  warnings_json json,
  created_at timestamp default current_timestamp,
  key idx_ingestion_app (app_id),
  key idx_ingestion_task (task_key)
);
