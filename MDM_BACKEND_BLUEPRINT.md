# MDM 后台管理系统 — 架构蓝图

## 一、系统总览

```
┌─────────────────────────────────────────────────────────────────┐
│                        运维管理后台 (Web)                        │
│  设备列表 │ 策略配置 │ 命令下发 │ 合规监控 │ 授权管理           │
└──────┬────────────────────────────────────────────────┬────────┘
       │ HTTP (JWT)                                     │ HTTP (JWT)
       ▼                                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    pos_service (Dart Frog)                       │
│  GET /devices    POST /devices/{id}/commands                    │
│  PUT /policies   GET /devices/compliance                        │
└──────┬────────────────────────────────────────────────┬────────┘
       │ PostgreSQL                                      │
       ▼                                                ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────────┐
│  devices      │  │  policies    │  │  command_queue    │
│  licenses     │  │  policy_bind │  │  heartbeat_log    │
└──────────────┘  └──────────────┘  └──────────────────┘
       ▲                                                ▲
       │ HTTP (设备上报)                                 │
       ▼                                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      POS 设备 (Flutter)                         │
│  MdmService → MethodChannel → BSP 系统 App                      │
└─────────────────────────────────────────────────────────────────┘
```

---

## 二、数据库设计 (扩展现有 PostgreSQL)

### 现有表（不动）

- `devices` — 设备白名单
- `licenses` — 授权码

### 新增表

#### 1. device_policies — 策略定义

```sql
CREATE TABLE device_policies (
    id            SERIAL PRIMARY KEY,
    merchant_id   INTEGER NOT NULL,

    policy_name   VARCHAR(100) NOT NULL,        -- 策略名称
    policy_data   JSONB NOT NULL,               -- 策略内容

    -- 策略内容示例:
    -- {
    --   "screen_lock": {"enabled": true, "lock_time": "22:00", "unlock_time": "07:00"},
    --   "kiosk_mode": {"enabled": true, "allowed_apps": ["pos_app"]},
    --   "camera": {"disabled": true},
    --   "wifi": {"disabled": false},
    --   "volume": {"fixed": true, "level": 80},
    --   "auto_update": {"enabled": true, "time": "03:00"}
    -- }

    version       INTEGER DEFAULT 1,
    is_active     BOOLEAN DEFAULT true,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (merchant_id) REFERENCES merchants(id)
);
```

#### 2. policy_bindings — 策略与设备绑定

```sql
CREATE TABLE policy_bindings (
    id          SERIAL PRIMARY KEY,
    policy_id   INTEGER NOT NULL,
    device_id   VARCHAR(100) NOT NULL,
    merchant_id INTEGER NOT NULL,

    -- 执行状态: pending / synced / failed
    status      VARCHAR(20) DEFAULT 'pending',
    synced_at   TIMESTAMP,

    FOREIGN KEY (policy_id) REFERENCES device_policies(id),
    FOREIGN KEY (device_id) REFERENCES devices(device_id)
);
```

#### 3. command_queue — 远程命令队列

```sql
CREATE TABLE command_queue (
    id          SERIAL PRIMARY KEY,
    merchant_id INTEGER NOT NULL,
    device_id   VARCHAR(100) NOT NULL,

    command     VARCHAR(50) NOT NULL,
    -- 命令类型: lock_screen / unlock_screen / reboot /
    --          enable_kiosk / disable_kiosk / disable_camera /
    --          enable_camera / wipe_data / sync_policy /
    --          install_app / uninstall_app

    params      JSONB DEFAULT '{}',
    -- 示例: {"package_name": "com.example.app"}
    --       {"message": "设备将在5分钟后重启"}

    status      VARCHAR(20) DEFAULT 'pending',
    -- pending → sent → acknowledged → completed
    -- pending → sent → failed

    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    sent_at     TIMESTAMP,
    done_at     TIMESTAMP,
    error_msg   TEXT
);
```

#### 4. heartbeat_log — 设备心跳日志

```sql
CREATE TABLE heartbeat_log (
    id              SERIAL PRIMARY KEY,
    device_id       VARCHAR(100) NOT NULL,
    merchant_id     INTEGER NOT NULL,

    battery_level   INTEGER,                    -- 电量 0-100
    battery_temp    DECIMAL(5,2),               -- 电池温度
    storage_usage   DECIMAL(5,2),               -- 存储使用率 %
    memory_usage    DECIMAL(5,2),               -- 内存使用率 %
    network_type    VARCHAR(20),                -- wifi / 4g / 5g
    signal_strength INTEGER,                    -- 信号强度 dBm
    location_lat    DECIMAL(10,7),
    location_lng    DECIMAL(10,7),
    app_version     VARCHAR(20),                -- 当前APK版本
    is_charging     BOOLEAN,
    reported_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

## 三、API 接口设计

### 3.1 设备管理

```
GET    /api/devices                       # 设备列表
  Query: ?merchant_id=&status=&keyword=&page=&page_size=
  Response: { devices: [...], total: N, page: N }

GET    /api/devices/{device_id}           # 设备详情
  Response: { device_id, status, last_active_at, policies: [...], pending_commands: [...] }

PUT    /api/devices/{device_id}           # 修改设备
  Body: { status: "suspended" }          # 停用/启用/标记丢失

DELETE /api/devices/{device_id}           # 解绑设备
```

### 3.2 策略管理

```
GET    /api/policies                      # 策略列表
POST   /api/policies                      # 创建策略
  Body: { policy_name, policy_data: {...} }

PUT    /api/policies/{id}                 # 更新策略
DELETE /api/policies/{id}                 # 删除策略

POST   /api/policies/{id}/bind            # 绑定设备
  Body: { device_ids: ["id1", "id2"] }

POST   /api/policies/{id}/unbind          # 解绑设备
  Body: { device_ids: ["id1"] }
```

### 3.3 远程命令

```
POST   /api/devices/{id}/commands         # 下发命令
  Body: { command: "lock_screen", params: {} }

GET    /api/devices/{id}/commands         # 查询命令执行状态
  Response: { commands: [{ command, status, created_at }] }

POST   /api/devices/batch-commands        # 批量下发
  Body: { device_ids: [...], command: "reboot", params: {} }
```

### 3.4 设备端通信 （低于 HTTP/1.0）

```
# 设备定时轮询
GET    /api/devices/{id}/poll             # 获取待执行命令
  Response: { commands: [...], policy: {...}, sync_at: "..." }

# 心跳上报
POST   /api/devices/{id}/heartbeat
  Body: { battery_level, storage_usage, location, ... }

# 命令确认
POST   /api/devices/{id}/commands/{cmd_id}/ack
  Body: { status: "completed" | "failed", error_msg: "..." }

# 策略同步确认
POST   /api/devices/{id}/policy-sync
  Body: { policy_id, version, status: "synced" }
```

---

## 四、管理后台界面概念

### 4.1 页面结构

```
┌─────────────────────────────────────────────────────────────────┐
│  [logo]  MDM 管理平台                     管理员: admin     [退出]│
├──────────┬──────────────────────────────────────────────────────┤
│          │                                                      │
│  📊 仪表盘 │  设备概览                                          │
│  📱 设备列表 │  总设备: 128  │ 在线: 96  │ 离线: 28  │ 异常: 4  │
│  📋 策略管理 │                                                      │
│  📨 命令日志 │  ┌──────────────────────────────────────┐          │
│  🔑 授权管理 │  │ 设备ID       状态  电量  最后上线     │          │
│  ⚙️ 系统设置 │  │ POS-001      🟢 在线  87%  10:32:15  │          │
│              │  │ POS-002      🔴 离线  23%  昨天 22:00 │          │
│              │  │ POS-003      🟡 异常  91%  10:15:00  │          │
│              │  │ ...                                  │          │
│              │  └──────────────────────────────────────┘          │
│              │                                                      │
│              │  [批量锁屏] [批量重启] [下发策略]                    │
│              │                                                      │
├──────────────┴──────────────────────────────────────────────────────┤
│  © 2026 MDM Console                                               │
└────────────────────────────────────────────────────────────────────-┘
```

### 4.2 关键功能模块

| 模块 | 功能 |
|------|------|
| **仪表盘** | 在线率、电量分布、版本分布、异常告警 |
| **设备列表** | 搜索/筛选、详情查看、远程操作、批量操作 |
| **策略管理** | 可视化策略编辑（JSON/YAML）、版本管理、批量绑定 |
| **命令日志** | 命令下发历史、执行状态追踪、失败重试 |
| **授权管理** | License 生成/分发、绑定记录、激活统计 |
| **告警规则** | 离线告警、低电量告警、合规异常告警 |

### 4.3 技术选型建议

- **前端**: Flutter Web（复用现有代码习惯）或 Vue/React（后台管理体验更好）
- **实时推送**: Server-Sent Events 或 WebSocket，替代轮询
- **认证**: 在现有 JWT 基础上扩展管理员角色，和 POS 设备角色分离

---

## 五、设备生命周期

```
┌─────────┐     ┌──────────┐     ┌──────────┐     ┌─────────┐
│  未激活  │────▶│  已激活   │────▶│  运行中   │────▶│  已解绑  │
│ (unused) │     │ (active) │     │ (online) │     │ (retired)│
└─────────┘     └──────────┘     └──────────┘     └─────────┘
                    │                 │                  │
                    │                 ├── 离线 ──▶ 告警   │
                    │                 ├── 异常 ──▶ 远程诊断│
                    │                 └── 丢失 ──▶ 擦除数据│
                    │                                      │
                    └── 停用 (suspended) ──────────────────┘
```

---

## 六、实现优先级建议

| 优先级 | 模块 | 工作量 | 说明 |
|--------|------|--------|------|
| **P0** | 数据库扩展 + 设备列表 API | 2 天 | 基础，其他模块依赖 |
| **P0** | 心跳上报 + 在线状态 | 1 天 | 实时掌握设备状态 |
| **P1** | 命令队列 + 下发 API | 2 天 | 远程管控核心能力 |
| **P1** | 设备端命令轮询 | 1 天 | Flutter 侧实现 |
| **P2** | 策略管理 | 2 天 | 批量配置 |
| **P2** | 管理后台 UI | 3-5 天 | Web 界面 |
| **P3** | 授权管理 | 1 天 | License 批量生成 |
| **P3** | 告警规则 | 1 天 | 离线/低电量通知 |

---

> **当前进度**: 设备激活部分 ✅ 已上线
> **下一步建议**: 先建数据库表 + 心跳上报，拿到设备在线状态后，管理后台就有真实数据可用了。
