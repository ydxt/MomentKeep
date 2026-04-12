-- ============================================
-- Supabase 数据库表结构 - 拾光记 (Moment Keep)
-- ============================================
-- 此脚本创建所有必要的表结构、索引和行级安全策略
-- 在 Supabase Dashboard 的 SQL Editor 中执行

-- ============================================
-- 1. 待办事项表 (todos)
-- ============================================
CREATE TABLE IF NOT EXISTS todos (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  category_id TEXT,
  title TEXT NOT NULL,
  content JSONB,
  is_completed BOOLEAN DEFAULT false,
  completed_at TIMESTAMP WITH TIME ZONE,
  start_date TIMESTAMP WITH TIME ZONE,
  date TIMESTAMP WITH TIME ZONE,
  reminder_time TIMESTAMP WITH TIME ZONE,
  priority TEXT DEFAULT 'medium',
  tags JSONB DEFAULT '[]',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  repeat_type TEXT DEFAULT 'none',
  repeat_interval INTEGER DEFAULT 1,
  repeat_end_date TIMESTAMP WITH TIME ZONE,
  last_repeat_date TIMESTAMP WITH TIME ZONE,
  is_location_reminder_enabled BOOLEAN DEFAULT false,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  radius DOUBLE PRECISION,
  location_name TEXT,
  subtasks JSONB DEFAULT '[]',
  -- 同步相关字段
  synced_at TIMESTAMP WITH TIME ZONE,
  version INTEGER DEFAULT 1,
  is_deleted BOOLEAN DEFAULT false
);

-- 创建索引
CREATE INDEX idx_todos_user_id ON todos (user_id);
CREATE INDEX idx_todos_category_id ON todos (category_id);
CREATE INDEX idx_todos_is_completed ON todos (is_completed);
CREATE INDEX idx_todos_updated_at ON todos (updated_at);
CREATE INDEX idx_todos_priority ON todos (priority);

-- 启用行级安全
ALTER TABLE todos ENABLE ROW LEVEL SECURITY;

-- 创建策略：用户只能访问自己的数据
CREATE POLICY "Users can view their own todos"
  ON todos FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own todos"
  ON todos FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own todos"
  ON todos FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own todos"
  ON todos FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================
-- 2. 习惯表 (habits)
-- ============================================
CREATE TABLE IF NOT EXISTS habits (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  category_id TEXT,
  category TEXT,
  name TEXT NOT NULL,
  content JSONB,
  icon TEXT,
  color INTEGER,
  frequency TEXT DEFAULT 'daily',
  reminder_days JSONB DEFAULT '[]',
  reminder_time TIMESTAMP WITH TIME ZONE,
  current_streak INTEGER DEFAULT 0,
  best_streak INTEGER DEFAULT 0,
  total_completions INTEGER DEFAULT 0,
  history JSONB DEFAULT '[]',
  check_in_records JSONB DEFAULT '[]',
  tags JSONB DEFAULT '[]',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  full_stars INTEGER DEFAULT 5,
  notes TEXT DEFAULT '',
  type TEXT DEFAULT 'positive',
  -- 同步相关字段
  synced_at TIMESTAMP WITH TIME ZONE,
  version INTEGER DEFAULT 1,
  is_deleted BOOLEAN DEFAULT false
);

-- 创建索引
CREATE INDEX idx_habits_user_id ON habits (user_id);
CREATE INDEX idx_habits_category_id ON habits (category_id);
CREATE INDEX idx_habits_updated_at ON habits (updated_at);
CREATE INDEX idx_habits_type ON habits (type);

-- 启用行级安全
ALTER TABLE habits ENABLE ROW LEVEL SECURITY;

-- 创建策略
CREATE POLICY "Users can view their own habits"
  ON habits FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own habits"
  ON habits FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own habits"
  ON habits FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own habits"
  ON habits FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================
-- 3. 习惯打卡记录表 (habit_records)
-- ============================================
CREATE TABLE IF NOT EXISTS habit_records (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  habit_id UUID REFERENCES habits(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  score INTEGER DEFAULT 5,
  comment JSONB,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_negative BOOLEAN DEFAULT false,
  -- 同步相关字段
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  synced_at TIMESTAMP WITH TIME ZONE,
  version INTEGER DEFAULT 1
);

-- 创建索引
CREATE INDEX idx_habit_records_habit_id ON habit_records (habit_id);
CREATE INDEX idx_habit_records_user_id ON habit_records (user_id);
CREATE INDEX idx_habit_records_timestamp ON habit_records (timestamp);

-- 启用行级安全
ALTER TABLE habit_records ENABLE ROW LEVEL SECURITY;

-- 创建策略
CREATE POLICY "Users can view their own habit records"
  ON habit_records FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own habit records"
  ON habit_records FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own habit records"
  ON habit_records FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own habit records"
  ON habit_records FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================
-- 4. 日记表 (journals)
-- ============================================
CREATE TABLE IF NOT EXISTS journals (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  category_id TEXT,
  title TEXT,
  content TEXT,  -- 加密后的内容
  tags JSONB DEFAULT '[]',
  date DATE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  subject TEXT,
  remarks TEXT,
  mood INTEGER,
  -- 同步相关字段
  synced_at TIMESTAMP WITH TIME ZONE,
  version INTEGER DEFAULT 1,
  is_deleted BOOLEAN DEFAULT false
);

-- 创建索引
CREATE INDEX idx_journals_user_id ON journals (user_id);
CREATE INDEX idx_journals_category_id ON journals (category_id);
CREATE INDEX idx_journals_date ON journals (date);
CREATE INDEX idx_journals_updated_at ON journals (updated_at);

-- 启用行级安全
ALTER TABLE journals ENABLE ROW LEVEL SECURITY;

-- 创建策略
CREATE POLICY "Users can view their own journals"
  ON journals FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own journals"
  ON journals FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own journals"
  ON journals FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own journals"
  ON journals FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================
-- 5. 分类表 (categories)
-- ============================================
CREATE TABLE IF NOT EXISTS categories (
  id TEXT PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  icon TEXT,
  color INTEGER,
  is_expanded BOOLEAN DEFAULT false,
  is_question_bank BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  -- 同步相关字段
  synced_at TIMESTAMP WITH TIME ZONE,
  version INTEGER DEFAULT 1,
  is_deleted BOOLEAN DEFAULT false
);

-- 创建索引
CREATE INDEX idx_categories_user_id ON categories (user_id);
CREATE INDEX idx_categories_type ON categories (type);

-- 启用行级安全
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;

-- 创建策略
CREATE POLICY "Users can view their own categories"
  ON categories FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own categories"
  ON categories FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own categories"
  ON categories FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own categories"
  ON categories FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================
-- 6. 番茄钟记录表 (pomodoro_records)
-- ============================================
CREATE TABLE IF NOT EXISTS pomodoro_records (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  duration INTEGER NOT NULL,
  start_time TIMESTAMP WITH TIME ZONE NOT NULL,
  end_time TIMESTAMP WITH TIME ZONE,
  tag TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  -- 同步相关字段
  synced_at TIMESTAMP WITH TIME ZONE,
  version INTEGER DEFAULT 1,
  is_deleted BOOLEAN DEFAULT false
);

-- 创建索引
CREATE INDEX idx_pomodoro_user_id ON pomodoro_records (user_id);
CREATE INDEX idx_pomodoro_start_time ON pomodoro_records (start_time);

-- 启用行级安全
ALTER TABLE pomodoro_records ENABLE ROW LEVEL SECURITY;

-- 创建策略
CREATE POLICY "Users can view their own pomodoro records"
  ON pomodoro_records FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own pomodoro records"
  ON pomodoro_records FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own pomodoro records"
  ON pomodoro_records FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own pomodoro records"
  ON pomodoro_records FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================
-- 7. 计划表 (plans)
-- ============================================
CREATE TABLE IF NOT EXISTS plans (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  start_date TIMESTAMP WITH TIME ZONE NOT NULL,
  end_date TIMESTAMP WITH TIME ZONE NOT NULL,
  is_completed BOOLEAN DEFAULT false,
  habit_ids JSONB DEFAULT '[]',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  -- 同步相关字段
  synced_at TIMESTAMP WITH TIME ZONE,
  version INTEGER DEFAULT 1,
  is_deleted BOOLEAN DEFAULT false
);

-- 创建索引
CREATE INDEX idx_plans_user_id ON plans (user_id);
CREATE INDEX idx_plans_start_date ON plans (start_date);
CREATE INDEX idx_plans_end_date ON plans (end_date);

-- 启用行级安全
ALTER TABLE plans ENABLE ROW LEVEL SECURITY;

-- 创建策略
CREATE POLICY "Users can view their own plans"
  ON plans FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own plans"
  ON plans FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own plans"
  ON plans FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own plans"
  ON plans FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================
-- 8. 成就表 (achievements)
-- ============================================
CREATE TABLE IF NOT EXISTS achievements (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  type TEXT NOT NULL,
  is_unlocked BOOLEAN DEFAULT false,
  unlocked_at TIMESTAMP WITH TIME ZONE,
  required_progress INTEGER DEFAULT 0,
  current_progress INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  -- 同步相关字段
  synced_at TIMESTAMP WITH TIME ZONE,
  version INTEGER DEFAULT 1
);

-- 创建索引
CREATE INDEX idx_achievements_user_id ON achievements (user_id);
CREATE INDEX idx_achievements_type ON achievements (type);
CREATE INDEX idx_achievements_is_unlocked ON achievements (is_unlocked);

-- 启用行级安全
ALTER TABLE achievements ENABLE ROW LEVEL SECURITY;

-- 创建策略
CREATE POLICY "Users can view their own achievements"
  ON achievements FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own achievements"
  ON achievements FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own achievements"
  ON achievements FOR UPDATE
  USING (auth.uid() = user_id);

-- ============================================
-- 9. 自动更新时间戳触发器
-- ============================================
-- 为所有表创建触发器，自动更新 updated_at 字段

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 为所有表添加触发器
CREATE TRIGGER update_todos_updated_at BEFORE UPDATE ON todos
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_habits_updated_at BEFORE UPDATE ON habits
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_habit_records_updated_at BEFORE UPDATE ON habit_records
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_journals_updated_at BEFORE UPDATE ON journals
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_categories_updated_at BEFORE UPDATE ON categories
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_pomodoro_records_updated_at BEFORE UPDATE ON pomodoro_records
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_plans_updated_at BEFORE UPDATE ON plans
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_achievements_updated_at BEFORE UPDATE ON achievements
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 10. 实时订阅配置
-- ============================================
-- 启用 Realtime 扩展（如果尚未启用）
ALTER PUBLICATION supabase_realtime ADD TABLE todos;
ALTER PUBLICATION supabase_realtime ADD TABLE habits;
ALTER PUBLICATION supabase_realtime ADD TABLE habit_records;
ALTER PUBLICATION supabase_realtime ADD TABLE journals;
ALTER PUBLICATION supabase_realtime ADD TABLE categories;
ALTER PUBLICATION supabase_realtime ADD TABLE pomodoro_records;
ALTER PUBLICATION supabase_realtime ADD TABLE plans;
ALTER PUBLICATION supabase_realtime ADD TABLE achievements;

-- ============================================
-- 完成
-- ============================================
-- 所有表结构和策略已创建
-- 现在可以在 Supabase Dashboard 中启用 Realtime 功能
-- 并在应用中使用 Supabase Flutter SDK 进行实时同步
