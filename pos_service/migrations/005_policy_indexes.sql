-- 策略绑定表添加唯一约束，防止重复绑定
CREATE UNIQUE INDEX IF NOT EXISTS idx_policy_bind_unique ON policy_bindings (policy_id, device_id);

-- 策略名称按商户唯一（可选约束）
CREATE UNIQUE INDEX IF NOT EXISTS idx_policy_name_merchant ON device_policies (merchant_id, policy_name);
