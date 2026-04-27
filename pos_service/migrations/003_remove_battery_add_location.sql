-- MDM 心跳表调整：移除电量字段，添加地理位置字段
-- 收银机是插电使用，电量无意义；需要位置信息用于设备追踪

DO $$
BEGIN
    -- 移除电池相关字段
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'heartbeat_log' AND column_name = 'battery_level'
    ) THEN
        ALTER TABLE heartbeat_log DROP COLUMN battery_level;
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'heartbeat_log' AND column_name = 'battery_temp'
    ) THEN
        ALTER TABLE heartbeat_log DROP COLUMN battery_temp;
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'heartbeat_log' AND column_name = 'is_charging'
    ) THEN
        ALTER TABLE heartbeat_log DROP COLUMN is_charging;
    END IF;

    -- 添加地理位置字段
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'heartbeat_log' AND column_name = 'latitude'
    ) THEN
        ALTER TABLE heartbeat_log ADD COLUMN latitude DECIMAL(9,6);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'heartbeat_log' AND column_name = 'longitude'
    ) THEN
        ALTER TABLE heartbeat_log ADD COLUMN longitude DECIMAL(9,6);
    END IF;
END;
$$;
