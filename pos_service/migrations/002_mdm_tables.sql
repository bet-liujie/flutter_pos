-- MDM 数据库扩展
-- 新增四张表：device_policies, policy_bindings, command_queue, heartbeat_log

-- 1. 策略定义表
CREATE TABLE IF NOT EXISTS device_policies (
    id            SERIAL PRIMARY KEY,
    merchant_id   INTEGER NOT NULL,

    policy_name   VARCHAR(100) NOT NULL,
    policy_data   JSONB NOT NULL DEFAULT '{}',

    version       INTEGER DEFAULT 1,
    is_active     BOOLEAN DEFAULT true,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. 策略与设备绑定表
CREATE TABLE IF NOT EXISTS policy_bindings (
    id          SERIAL PRIMARY KEY,
    policy_id   INTEGER NOT NULL,
    device_id   VARCHAR(100) NOT NULL,
    merchant_id INTEGER NOT NULL,

    status      VARCHAR(20) DEFAULT 'pending',
    synced_at   TIMESTAMP,

    FOREIGN KEY (policy_id) REFERENCES device_policies(id) ON DELETE CASCADE,
    FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE
);

-- 3. 命令队列表
CREATE TABLE IF NOT EXISTS command_queue (
    id          SERIAL PRIMARY KEY,
    merchant_id INTEGER NOT NULL,
    device_id   VARCHAR(100) NOT NULL,

    command     VARCHAR(50) NOT NULL,
    params      JSONB DEFAULT '{}',

    status      VARCHAR(20) DEFAULT 'pending',
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    sent_at     TIMESTAMP,
    done_at     TIMESTAMP,
    error_msg   TEXT
);

-- 4. 设备心跳日志表
CREATE TABLE IF NOT EXISTS heartbeat_log (
    id              SERIAL PRIMARY KEY,
    device_id       VARCHAR(100) NOT NULL,
    merchant_id     INTEGER NOT NULL,

    battery_level   INTEGER,
    battery_temp    DECIMAL(5,2),
    storage_usage   DECIMAL(5,2),
    memory_usage    DECIMAL(5,2),
    network_type    VARCHAR(20),
    signal_strength INTEGER,
    app_version     VARCHAR(20),
    is_charging     BOOLEAN,
    reported_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 索引：心跳查询按 device_id + 时间倒序
CREATE INDEX IF NOT EXISTS idx_heartbeat_device_time ON heartbeat_log (device_id, reported_at DESC);
CREATE INDEX IF NOT EXISTS idx_heartbeat_merchant_time ON heartbeat_log (merchant_id, reported_at DESC);

-- 索引：命令队列按设备查询待处理命令
CREATE INDEX IF NOT EXISTS idx_command_device_status ON command_queue (device_id, status);

-- 索引：策略绑定查询
CREATE INDEX IF NOT EXISTS idx_policy_bind_device ON policy_bindings (device_id);
