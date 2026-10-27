CREATE TABLE IF NOT EXISTS products (
  sku TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'General',
  scan_code TEXT NOT NULL UNIQUE,
  on_hand INTEGER NOT NULL CHECK (on_hand >= 0),
  bin_x INTEGER NOT NULL CHECK (bin_x >= 0),
  bin_y INTEGER NOT NULL CHECK (bin_y >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS robots (
  id TEXT PRIMARY KEY,
  adapter_type TEXT NOT NULL DEFAULT 'generic',
  status TEXT NOT NULL DEFAULT 'idle'
    CHECK (status IN ('idle', 'assigned', 'moving', 'picking', 'delivering', 'charging', 'unavailable')),
  battery INTEGER NOT NULL DEFAULT 100 CHECK (battery BETWEEN 0 AND 100),
  position_x INTEGER NOT NULL DEFAULT 0 CHECK (position_x >= 0),
  position_y INTEGER NOT NULL DEFAULT 0 CHECK (position_y >= 0),
  current_task_id UUID,
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS orders (
  id TEXT PRIMARY KEY,
  customer_ref TEXT,
  priority TEXT NOT NULL DEFAULT 'normal' CHECK (priority IN ('normal', 'rush')),
  status TEXT NOT NULL DEFAULT 'received'
    CHECK (status IN ('received', 'queued', 'assigned', 'picking', 'delivering', 'completed', 'cancelled')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS order_items (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  order_id TEXT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  sku TEXT NOT NULL REFERENCES products(sku),
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  picked_quantity INTEGER NOT NULL DEFAULT 0 CHECK (picked_quantity >= 0),
  delivered_quantity INTEGER NOT NULL DEFAULT 0 CHECK (delivered_quantity >= 0),
  UNIQUE (order_id, sku),
  CHECK (picked_quantity <= quantity),
  CHECK (delivered_quantity <= picked_quantity)
);

CREATE TABLE IF NOT EXISTS robot_tasks (
  id UUID PRIMARY KEY,
  robot_id TEXT NOT NULL REFERENCES robots(id),
  order_id TEXT NOT NULL REFERENCES orders(id),
  status TEXT NOT NULL DEFAULT 'assigned'
    CHECK (status IN ('assigned', 'picking', 'delivering', 'completed', 'cancelled')),
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX IF NOT EXISTS one_active_task_per_robot
  ON robot_tasks(robot_id)
  WHERE status IN ('assigned', 'picking', 'delivering');

CREATE UNIQUE INDEX IF NOT EXISTS one_active_task_per_order
  ON robot_tasks(order_id)
  WHERE status IN ('assigned', 'picking', 'delivering');

ALTER TABLE robots
  DROP CONSTRAINT IF EXISTS robots_current_task_id_fkey;
ALTER TABLE robots
  ADD CONSTRAINT robots_current_task_id_fkey
  FOREIGN KEY (current_task_id) REFERENCES robot_tasks(id);

CREATE TABLE IF NOT EXISTS scan_events (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  event_id UUID NOT NULL UNIQUE,
  robot_id TEXT NOT NULL REFERENCES robots(id),
  task_id UUID NOT NULL REFERENCES robot_tasks(id),
  order_id TEXT NOT NULL REFERENCES orders(id),
  product_sku TEXT NOT NULL REFERENCES products(sku),
  scan_code TEXT NOT NULL,
  scan_type TEXT NOT NULL CHECK (scan_type IN ('pick', 'deliver')),
  quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity = 1),
  scanned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  metadata JSONB NOT NULL DEFAULT '{}'::JSONB
);

CREATE TABLE IF NOT EXISTS decision_log (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  order_id TEXT REFERENCES orders(id),
  robot_id TEXT REFERENCES robots(id),
  task_id UUID REFERENCES robot_tasks(id),
  event_type TEXT NOT NULL,
  message TEXT NOT NULL,
  details JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS orders_status_created_idx
  ON orders(status, created_at);
CREATE INDEX IF NOT EXISTS scan_events_order_time_idx
  ON scan_events(order_id, scanned_at);
CREATE INDEX IF NOT EXISTS decision_log_created_idx
  ON decision_log(created_at DESC);
