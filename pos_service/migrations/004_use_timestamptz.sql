-- 时间戳列改为 timestamptz，确保时区信息不丢失
-- PostgreSQL 会话时区为 UTC，CURRENT_TIMESTAMP 返回 UTC 时间
-- timestamp without time zone 存储会丢失时区信息，导致 Dart 驱动读取时误用本地时区

DO $$
BEGIN
    -- heartbeat_log.reported_at
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'heartbeat_log' AND column_name = 'reported_at'
          AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE heartbeat_log ALTER COLUMN reported_at TYPE timestamptz
            USING reported_at AT TIME ZONE 'UTC';
        ALTER TABLE heartbeat_log ALTER COLUMN reported_at SET DEFAULT CURRENT_TIMESTAMP;
    END IF;

    -- devices.last_active_at
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'devices' AND column_name = 'last_active_at'
          AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE devices ALTER COLUMN last_active_at TYPE timestamptz
            USING last_active_at AT TIME ZONE 'UTC';
        ALTER TABLE devices ALTER COLUMN last_active_at SET DEFAULT CURRENT_TIMESTAMP;
    END IF;

    -- devices.created_at
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'devices' AND column_name = 'created_at'
          AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE devices ALTER COLUMN created_at TYPE timestamptz
            USING created_at AT TIME ZONE 'UTC';
        ALTER TABLE devices ALTER COLUMN created_at SET DEFAULT CURRENT_TIMESTAMP;
    END IF;
END;
$$;
