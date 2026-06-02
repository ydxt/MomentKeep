from flask import Flask, jsonify, request, render_template, redirect, url_for, send_from_directory
from flask_cors import CORS
import sqlite3
import json
import datetime
import uuid
import os
import re
from werkzeug.utils import secure_filename

app = Flask(__name__)
CORS(app)  # 允许跨域请求

# 数据库配置
# DATABASE = 'server/moment_keep.db'
DATABASE = 'moment_keep.db'

# 文件上传配置
UPLOAD_FOLDER = './uploads'  # 使用相对路径，相对于server目录
ALLOWED_EXTENSIONS = {'txt', 'pdf', 'png', 'jpg', 'jpeg', 'gif', 'mp4', 'mp3', 'wav'}
MAX_CONTENT_LENGTH = 16 * 1024 * 1024  # 16 MB

# 确保上传文件夹存在
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['MAX_CONTENT_LENGTH'] = MAX_CONTENT_LENGTH

# 检查文件扩展名是否允许
def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

# 初始化数据库

def init_db():
    """
    初始化应用数据库，创建所有必要的表结构
    
    创建以下表：
    - users: 存储用户账户信息
    - journals: 存储日记内容
    - categories: 存储日记分类
    - habits: 存储习惯追踪数据
    - todos: 存储待办事项
    
    表结构包含必要的字段和外键约束，确保数据完整性
    """
    conn = sqlite3.connect(DATABASE)
    cursor = conn.cursor()
    
    # 创建用户表
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id TEXT PRIMARY KEY,
            username TEXT UNIQUE NOT NULL,
            email TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            last_login_at TEXT
        )
    ''')
    
    # 创建日记表
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS journals (
            id TEXT PRIMARY KEY,
            category_id TEXT NOT NULL,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            tags TEXT NOT NULL,
            date TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            user_id TEXT NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users (id)
        )
    ''')
    
    # 创建分类表
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS categories (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            user_id TEXT NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users (id)
        )
    ''')
    
    # 创建习惯表
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS habits (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT,
            frequency TEXT NOT NULL,
            target TEXT NOT NULL,
            start_date TEXT NOT NULL,
            end_date TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            user_id TEXT NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users (id)
        )
    ''')
    
    # 创建待办事项表
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS todos (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            description TEXT,
            is_completed INTEGER NOT NULL DEFAULT 0,
            due_date TEXT,
            priority TEXT NOT NULL DEFAULT 'medium',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            user_id TEXT NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users (id)
        )
    ''')
    
    conn.commit()
    conn.close()

# 获取当前时间的ISO格式字符串
def get_current_time():
    return datetime.datetime.now().isoformat()

# 数据库连接辅助函数
def get_db_connection():
    conn = sqlite3.connect(DATABASE)
    conn.row_factory = sqlite3.Row
    return conn

# 认证相关路由

@app.route('/api/auth/register', methods=['POST'])
def register():
    data = request.get_json()
    
    # 验证请求数据
    if not data or not 'username' in data or not 'email' in data or not 'password' in data:
        return jsonify({'error': 'Missing required fields'}), 400
    
    # 检查用户是否已存在
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM users WHERE username = ? OR email = ?', (data['username'], data['email']))
    existing_user = cursor.fetchone()
    
    if existing_user:
        conn.close()
        return jsonify({'error': 'Username or email already exists'}), 400
    
    # 创建新用户
    user_id = str(uuid.uuid4())
    now = get_current_time()
    
    cursor.execute('''
        INSERT INTO users (id, username, email, password, created_at, updated_at, last_login_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ''', (user_id, data['username'], data['email'], data['password'], now, now, now))
    
    conn.commit()
    conn.close()
    
    return jsonify({'message': 'User registered successfully'}), 201

@app.route('/api/auth/login', methods=['POST'])
def login():
    data = request.get_json()
    
    # 验证请求数据
    if not data or not 'email' in data or not 'password' in data:
        return jsonify({'error': 'Missing required fields'}), 400
    
    # 检查用户是否存在
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM users WHERE email = ? AND password = ?', (data['email'], data['password']))
    user = cursor.fetchone()
    
    if not user:
        conn.close()
        return jsonify({'error': 'Invalid email or password'}), 401
    
    # 更新最后登录时间
    now = get_current_time()
    cursor.execute('''
        UPDATE users SET last_login_at = ?, updated_at = ?
        WHERE id = ?
    ''', (now, now, user['id']))
    conn.commit()
    conn.close()
    
    # 返回用户信息（实际应用中应返回JWT token）
    return jsonify({
        'id': user['id'],
        'username': user['username'],
        'email': user['email'],
        'last_login_at': now,
        'created_at': user['created_at'],
        'updated_at': now
    }), 200

# 日记相关路由

@app.route('/api/journals', methods=['GET'])
def get_journals():
    user_id = request.args.get('user_id')
    
    if not user_id:
        return jsonify({'error': 'Missing user_id parameter'}), 400
    
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM journals WHERE user_id = ? ORDER BY date DESC', (user_id,))
    journals = cursor.fetchall()
    conn.close()
    
    result = []
    for journal in journals:
        result.append({
            'id': journal['id'],
            'category_id': journal['category_id'],
            'title': journal['title'],
            'content': journal['content'],  # 直接返回加密后的内容，不要进行JSON解析
            'tags': json.loads(journal['tags']),
            'date': journal['date'],
            'created_at': journal['created_at'],
            'updated_at': journal['updated_at'],
            'user_id': journal['user_id']
        })
    
    return jsonify(result), 200

@app.route('/api/journals', methods=['POST'])
def create_journal():
    data = request.get_json()
    
    # 添加日志，查看请求内容
    print(f"[DEBUG] Received journal creation request: {data}")
    
    # 转换驼峰命名为下划线命名，兼容客户端请求
    formatted_data = {}
    for key, value in data.items():
        # 将驼峰命名转换为下划线命名
        formatted_key = re.sub(r'([a-z0-9])([A-Z])', r'\1_\2', key).lower()
        formatted_data[formatted_key] = value
    
    # 如果客户端没有提供user_id，检查是否有userId字段
    if 'user_id' not in formatted_data and 'userid' in formatted_data:
        formatted_data['user_id'] = formatted_data['userid']
    
    print(f"[DEBUG] Formatted request data: {formatted_data}")
    print(f"[DEBUG] Required fields check: category_id={ 'category_id' in formatted_data }, title={ 'title' in formatted_data }, content={ 'content' in formatted_data }, user_id={ 'user_id' in formatted_data }")
    
    # 允许category_id为空字符串
    if not data or not 'title' in formatted_data or not 'content' in formatted_data or not 'user_id' in formatted_data:
        return jsonify({'error': 'Missing required fields', 'received': data, 'formatted': formatted_data}), 400
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    journal_id = str(uuid.uuid4())
    now = get_current_time()
    
    cursor.execute('''
        INSERT INTO journals (id, category_id, title, content, tags, date, created_at, updated_at, user_id)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', (
        journal_id,
        formatted_data.get('category_id', ''),
        formatted_data['title'],
        formatted_data['content'],  # 已经是字符串格式，不需要再次json.dumps
        json.dumps(formatted_data.get('tags', [])),
        formatted_data.get('date', now),
        formatted_data.get('created_at', now),
        formatted_data.get('updated_at', now),
        formatted_data['user_id']
    ))
    
    conn.commit()
    conn.close()
    
    return jsonify({'id': journal_id, 'message': 'Journal created successfully'}), 201

@app.route('/api/journals/<journal_id>', methods=['GET'])
def get_journal(journal_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM journals WHERE id = ?', (journal_id,))
    journal = cursor.fetchone()
    conn.close()
    
    if not journal:
        return jsonify({'error': 'Journal not found'}), 404
    
    return jsonify({
        'id': journal['id'],
        'category_id': journal['category_id'],
        'title': journal['title'],
        'content': journal['content'],  # 直接返回加密后的内容，不要进行JSON解析
        'tags': json.loads(journal['tags']),
        'date': journal['date'],
        'created_at': journal['created_at'],
        'updated_at': journal['updated_at'],
        'user_id': journal['user_id']
    }), 200

@app.route('/api/journals/<journal_id>', methods=['PUT'])
def update_journal(journal_id):
    data = request.get_json()
    
    if not data:
        return jsonify({'error': 'No data provided'}), 400
    
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM journals WHERE id = ?', (journal_id,))
    journal = cursor.fetchone()
    
    if not journal:
        conn.close()
        return jsonify({'error': 'Journal not found'}), 404
    
    # 更新日记
    now = get_current_time()
    updates = []
    update_values = []
    
    if 'category_id' in data:
        updates.append('category_id = ?')
        update_values.append(data['category_id'])
    if 'title' in data:
        updates.append('title = ?')
        update_values.append(data['title'])
    if 'content' in data:
        updates.append('content = ?')
        update_values.append(data['content'])  # 直接保存加密后的内容，不要进行JSON序列化
    if 'tags' in data:
        updates.append('tags = ?')
        update_values.append(json.dumps(data['tags']))
    if 'date' in data:
        updates.append('date = ?')
        update_values.append(data['date'])
    
    # 添加更新时间和ID
    updates.append('updated_at = ?')
    update_values.append(now)
    update_values.append(journal_id)
    
    update_query = f"UPDATE journals SET {', '.join(updates)} WHERE id = ?"
    cursor.execute(update_query, tuple(update_values))
    
    conn.commit()
    conn.close()
    
    return jsonify({'message': 'Journal updated successfully'}), 200

@app.route('/api/journals/<journal_id>', methods=['DELETE'])
def delete_journal(journal_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM journals WHERE id = ?', (journal_id,))
    journal = cursor.fetchone()
    
    if not journal:
        conn.close()
        return jsonify({'error': 'Journal not found'}), 404
    
    cursor.execute('DELETE FROM journals WHERE id = ?', (journal_id,))
    conn.commit()
    conn.close()
    
    return jsonify({'message': 'Journal deleted successfully'}), 200

# 分类相关路由

@app.route('/api/categories', methods=['GET'])
def get_categories():
    user_id = request.args.get('user_id')
    type_filter = request.args.get('type')
    
    if not user_id:
        return jsonify({'error': 'Missing user_id parameter'}), 400
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    query = 'SELECT * FROM categories WHERE user_id = ?'
    params = [user_id]
    
    if type_filter:
        query += ' AND type = ?'
        params.append(type_filter)
    
    cursor.execute(query, params)
    categories = cursor.fetchall()
    conn.close()
    
    result = []
    for category in categories:
        result.append({
            'id': category['id'],
            'name': category['name'],
            'type': category['type'],
            'created_at': category['created_at'],
            'updated_at': category['updated_at'],
            'user_id': category['user_id']
        })
    
    return jsonify(result), 200

@app.route('/api/categories', methods=['POST'])
def create_category():
    data = request.get_json()
    
    if not data or not 'name' in data or not 'type' in data or not 'user_id' in data:
        return jsonify({'error': 'Missing required fields'}), 400
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    category_id = str(uuid.uuid4())
    now = get_current_time()
    
    cursor.execute('''
        INSERT INTO categories (id, name, type, created_at, updated_at, user_id)
        VALUES (?, ?, ?, ?, ?, ?)
    ''', (category_id, data['name'], data['type'], now, now, data['user_id']))
    
    conn.commit()
    conn.close()
    
    return jsonify({'id': category_id, 'message': 'Category created successfully'}), 201

# 习惯相关路由

@app.route('/api/habits', methods=['GET'])
def get_habits():
    user_id = request.args.get('user_id')
    
    if not user_id:
        return jsonify({'error': 'Missing user_id parameter'}), 400
    
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM habits WHERE user_id = ? ORDER BY name', (user_id,))
    habits = cursor.fetchall()
    conn.close()
    
    result = []
    for habit in habits:
        result.append({
            'id': habit['id'],
            'name': habit['name'],
            'description': habit['description'],
            'frequency': habit['frequency'],
            'target': habit['target'],
            'start_date': habit['start_date'],
            'end_date': habit['end_date'],
            'created_at': habit['created_at'],
            'updated_at': habit['updated_at'],
            'user_id': habit['user_id']
        })
    
    return jsonify(result), 200

@app.route('/api/habits', methods=['POST'])
def create_habit():
    data = request.get_json()
    
    if not data or not 'name' in data or not 'frequency' in data or not 'target' in data or not 'start_date' in data or not 'user_id' in data:
        return jsonify({'error': 'Missing required fields'}), 400
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    habit_id = str(uuid.uuid4())
    now = get_current_time()
    
    cursor.execute('''
        INSERT INTO habits (id, name, description, frequency, target, start_date, end_date, created_at, updated_at, user_id)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', (
        habit_id,
        data['name'],
        data.get('description', ''),
        data['frequency'],
        data['target'],
        data['start_date'],
        data.get('end_date'),
        now,
        now,
        data['user_id']
    ))
    
    conn.commit()
    conn.close()
    
    return jsonify({'id': habit_id, 'message': 'Habit created successfully'}), 201

@app.route('/api/habits/<habit_id>', methods=['GET'])
def get_habit(habit_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM habits WHERE id = ?', (habit_id,))
    habit = cursor.fetchone()
    conn.close()
    
    if not habit:
        return jsonify({'error': 'Habit not found'}), 404
    
    return jsonify({
        'id': habit['id'],
        'name': habit['name'],
        'description': habit['description'],
        'frequency': habit['frequency'],
        'target': habit['target'],
        'start_date': habit['start_date'],
        'end_date': habit['end_date'],
        'created_at': habit['created_at'],
        'updated_at': habit['updated_at'],
        'user_id': habit['user_id']
    }), 200

@app.route('/api/habits/<habit_id>', methods=['PUT'])
def update_habit(habit_id):
    data = request.get_json()
    
    if not data:
        return jsonify({'error': 'No data provided'}), 400
    
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM habits WHERE id = ?', (habit_id,))
    habit = cursor.fetchone()
    
    if not habit:
        conn.close()
        return jsonify({'error': 'Habit not found'}), 404
    
    # 更新习惯
    now = get_current_time()
    updates = []
    update_values = []
    
    if 'name' in data:
        updates.append('name = ?')
        update_values.append(data['name'])
    if 'description' in data:
        updates.append('description = ?')
        update_values.append(data['description'])
    if 'frequency' in data:
        updates.append('frequency = ?')
        update_values.append(data['frequency'])
    if 'target' in data:
        updates.append('target = ?')
        update_values.append(data['target'])
    if 'start_date' in data:
        updates.append('start_date = ?')
        update_values.append(data['start_date'])
    if 'end_date' in data:
        updates.append('end_date = ?')
        update_values.append(data['end_date'])
    
    # 添加更新时间和ID
    updates.append('updated_at = ?')
    update_values.append(now)
    update_values.append(habit_id)
    
    update_query = f"UPDATE habits SET {', '.join(updates)} WHERE id = ?"
    cursor.execute(update_query, tuple(update_values))
    
    conn.commit()
    conn.close()
    
    return jsonify({'message': 'Habit updated successfully'}), 200

@app.route('/api/habits/<habit_id>', methods=['DELETE'])
def delete_habit(habit_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM habits WHERE id = ?', (habit_id,))
    habit = cursor.fetchone()
    
    if not habit:
        conn.close()
        return jsonify({'error': 'Habit not found'}), 404
    
    cursor.execute('DELETE FROM habits WHERE id = ?', (habit_id,))
    conn.commit()
    conn.close()
    
    return jsonify({'message': 'Habit deleted successfully'}), 200

# 待办事项相关路由

@app.route('/api/todos', methods=['GET'])
def get_todos():
    user_id = request.args.get('user_id')
    
    if not user_id:
        return jsonify({'error': 'Missing user_id parameter'}), 400
    
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM todos WHERE user_id = ? ORDER BY is_completed, due_date', (user_id,))
    todos = cursor.fetchall()
    conn.close()
    
    result = []
    for todo in todos:
        result.append({
            'id': todo['id'],
            'title': todo['title'],
            'description': todo['description'],
            'is_completed': bool(todo['is_completed']),
            'due_date': todo['due_date'],
            'priority': todo['priority'],
            'created_at': todo['created_at'],
            'updated_at': todo['updated_at'],
            'user_id': todo['user_id']
        })
    
    return jsonify(result), 200

@app.route('/api/todos', methods=['POST'])
def create_todo():
    data = request.get_json()
    
    if not data or not 'title' in data or not 'user_id' in data:
        return jsonify({'error': 'Missing required fields'}), 400
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    todo_id = str(uuid.uuid4())
    now = get_current_time()
    
    cursor.execute('''
        INSERT INTO todos (id, title, description, is_completed, due_date, priority, created_at, updated_at, user_id)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', (
        todo_id,
        data['title'],
        data.get('description', ''),
        1 if data.get('is_completed', False) else 0,
        data.get('due_date'),
        data.get('priority', 'medium'),
        now,
        now,
        data['user_id']
    ))
    
    conn.commit()
    conn.close()
    
    return jsonify({'id': todo_id, 'message': 'Todo created successfully'}), 201

@app.route('/api/todos/<todo_id>', methods=['GET'])
def get_todo(todo_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM todos WHERE id = ?', (todo_id,))
    todo = cursor.fetchone()
    conn.close()
    
    if not todo:
        return jsonify({'error': 'Todo not found'}), 404
    
    return jsonify({
        'id': todo['id'],
        'title': todo['title'],
        'description': todo['description'],
        'is_completed': bool(todo['is_completed']),
        'due_date': todo['due_date'],
        'priority': todo['priority'],
        'created_at': todo['created_at'],
        'updated_at': todo['updated_at'],
        'user_id': todo['user_id']
    }), 200

@app.route('/api/todos/<todo_id>', methods=['PUT'])
def update_todo(todo_id):
    data = request.get_json()
    
    if not data:
        return jsonify({'error': 'No data provided'}), 400
    
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM todos WHERE id = ?', (todo_id,))
    todo = cursor.fetchone()
    
    if not todo:
        conn.close()
        return jsonify({'error': 'Todo not found'}), 404
    
    # 更新待办事项
    now = get_current_time()
    updates = []
    update_values = []
    
    if 'title' in data:
        updates.append('title = ?')
        update_values.append(data['title'])
    if 'description' in data:
        updates.append('description = ?')
        update_values.append(data['description'])
    if 'is_completed' in data:
        updates.append('is_completed = ?')
        update_values.append(1 if data['is_completed'] else 0)
    if 'due_date' in data:
        updates.append('due_date = ?')
        update_values.append(data['due_date'])
    if 'priority' in data:
        updates.append('priority = ?')
        update_values.append(data['priority'])
    
    # 添加更新时间和ID
    updates.append('updated_at = ?')
    update_values.append(now)
    update_values.append(todo_id)
    
    update_query = f"UPDATE todos SET {', '.join(updates)} WHERE id = ?"
    cursor.execute(update_query, tuple(update_values))
    
    conn.commit()
    conn.close()
    
    return jsonify({'message': 'Todo updated successfully'}), 200

@app.route('/api/todos/<todo_id>', methods=['DELETE'])
def delete_todo(todo_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM todos WHERE id = ?', (todo_id,))
    todo = cursor.fetchone()
    
    if not todo:
        conn.close()
        return jsonify({'error': 'Todo not found'}), 404
    
    cursor.execute('DELETE FROM todos WHERE id = ?', (todo_id,))
    conn.commit()
    conn.close()
    
    return jsonify({'message': 'Todo deleted successfully'}), 200

# 管理界面路由

@app.route('/admin', strict_slashes=False)
def admin_index():
    # 重定向到用户管理页面
    return redirect(url_for('admin_users'))

@app.route('/admin/users', strict_slashes=False)
def admin_users():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM users ORDER BY created_at DESC')
    users = cursor.fetchall()
    conn.close()
    
    return render_template('admin_users.html', users=users)

@app.route('/admin/users/<user_id>', strict_slashes=False)
def admin_user_details(user_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # 获取用户信息
    cursor.execute('SELECT * FROM users WHERE id = ?', (user_id,))
    user = cursor.fetchone()
    
    if not user:
        conn.close()
        return 'User not found', 404
    
    # 获取用户数据统计
    cursor.execute('SELECT COUNT(*) as journal_count FROM journals WHERE user_id = ?', (user_id,))
    journal_count = cursor.fetchone()['journal_count']
    
    cursor.execute('SELECT COUNT(*) as category_count FROM categories WHERE user_id = ?', (user_id,))
    category_count = cursor.fetchone()['category_count']
    
    cursor.execute('SELECT COUNT(*) as habit_count FROM habits WHERE user_id = ?', (user_id,))
    habit_count = cursor.fetchone()['habit_count']
    
    cursor.execute('SELECT COUNT(*) as todo_count FROM todos WHERE user_id = ?', (user_id,))
    todo_count = cursor.fetchone()['todo_count']
    
    conn.close()
    
    return render_template('admin_user_details.html', 
                         user=user, 
                         journal_count=journal_count,
                         category_count=category_count,
                         habit_count=habit_count,
                         todo_count=todo_count)

@app.route('/admin/users/<user_id>/journals', strict_slashes=False)
def admin_user_journals(user_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # 获取用户信息
    cursor.execute('SELECT * FROM users WHERE id = ?', (user_id,))
    user = cursor.fetchone()
    
    if not user:
        conn.close()
        return 'User not found', 404
    
    # 获取用户日记列表
    cursor.execute('SELECT * FROM journals WHERE user_id = ? ORDER BY date DESC', (user_id,))
    journals = cursor.fetchall()
    
    conn.close()
    
    return render_template('admin_user_journals.html', user=user, journals=journals)

@app.route('/admin/users/<user_id>/categories', strict_slashes=False)
def admin_user_categories(user_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # 获取用户信息
    cursor.execute('SELECT * FROM users WHERE id = ?', (user_id,))
    user = cursor.fetchone()
    
    if not user:
        conn.close()
        return 'User not found', 404
    
    # 获取用户分类列表
    cursor.execute('SELECT * FROM categories WHERE user_id = ? ORDER BY name', (user_id,))
    categories = cursor.fetchall()
    
    conn.close()
    
    return render_template('admin_user_categories.html', user=user, categories=categories)

@app.route('/admin/users/<user_id>/habits', strict_slashes=False)
def admin_user_habits(user_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # 获取用户信息
    cursor.execute('SELECT * FROM users WHERE id = ?', (user_id,))
    user = cursor.fetchone()
    
    if not user:
        conn.close()
        return 'User not found', 404
    
    # 获取用户习惯列表
    cursor.execute('SELECT * FROM habits WHERE user_id = ? ORDER BY name', (user_id,))
    habits = cursor.fetchall()
    
    conn.close()
    
    return render_template('admin_user_habits.html', user=user, habits=habits)

@app.route('/admin/users/<user_id>/todos', strict_slashes=False)
def admin_user_todos(user_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # 获取用户信息
    cursor.execute('SELECT * FROM users WHERE id = ?', (user_id,))
    user = cursor.fetchone()
    
    if not user:
        conn.close()
        return 'User not found', 404
    
    # 获取用户待办事项列表
    cursor.execute('SELECT * FROM todos WHERE user_id = ? ORDER BY is_completed, due_date', (user_id,))
    todos = cursor.fetchall()
    
    conn.close()
    
    return render_template('admin_user_todos.html', user=user, todos=todos)

# 文件上传API端点
@app.route('/api/upload', methods=['POST'])
def upload_file():
    # 检查请求中是否包含文件
    if 'file' not in request.files:
        return jsonify({'error': 'No file part'}), 400
    
    # 获取用户ID参数
    user_id = request.form.get('user_id')
    if not user_id:
        return jsonify({'error': 'Missing user_id parameter'}), 400
    
    file = request.files['file']
    
    # 检查是否选择了文件
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400
    
    # 检查文件扩展名是否允许
    if file and allowed_file(file.filename):
        # 生成唯一的文件名
        filename = secure_filename(file.filename)
        unique_filename = f"{uuid.uuid4()}_{filename}"
        
        # 为当前用户创建独立的上传目录
        user_upload_folder = os.path.join(app.config['UPLOAD_FOLDER'], user_id)
        os.makedirs(user_upload_folder, exist_ok=True)
        
        # 保存文件到用户的上传文件夹
        file_path = os.path.join(user_upload_folder, unique_filename)
        file.save(file_path)
        
        # 返回文件的访问URL，包含用户目录
        file_url = f"http://localhost:5000/uploads/{user_id}/{unique_filename}"
        # 返回包含用户ID的完整文件名，以便客户端正确构建URL
        full_filename = f"{user_id}/{unique_filename}"
        return jsonify({'filename': full_filename, 'url': file_url, 'user_id': user_id}), 201
    else:
        return jsonify({'error': 'File type not allowed'}), 400

# 文件删除API端点
@app.route('/api/delete_file', methods=['DELETE'])
def delete_file():
    # 获取请求体数据
    data = request.get_json()
    
    # 检查请求中是否包含文件路径
    if not data or 'file_path' not in data:
        return jsonify({'error': 'Missing file_path parameter'}), 400
    
    file_path = data['file_path']
    
    # 安全检查：确保文件路径不包含..，防止路径遍历攻击
    if '..' in file_path:
        return jsonify({'error': 'Invalid file path'}), 400
    
    # 构建完整的文件路径
    full_file_path = os.path.join(app.config['UPLOAD_FOLDER'], file_path)
    
    # 检查文件是否存在
    if os.path.exists(full_file_path):
        try:
            # 删除文件
            os.remove(full_file_path)
            return jsonify({'message': 'File deleted successfully'}), 200
        except Exception as e:
            return jsonify({'error': f'Failed to delete file: {str(e)}'}), 500
    else:
        # 文件不存在，返回成功响应（幂等操作）
        return jsonify({'message': 'File not found, but operation considered successful'}), 200

# 静态文件服务端点 - 支持用户特定目录
@app.route('/uploads/<user_id>/<filename>')
def uploaded_file(user_id, filename):
    # 使用绝对路径确保正确性
    user_upload_folder = os.path.abspath(os.path.join(app.config['UPLOAD_FOLDER'], user_id))
    return send_from_directory(user_upload_folder, filename)

# 静态文件服务端点 - 支持直接访问根目录（用于兼容旧的文件路径）
@app.route('/uploads/<filename>')
def uploaded_file_root(filename):
    # 使用绝对路径确保正确性
    upload_folder_abs = os.path.abspath(app.config['UPLOAD_FOLDER'])
    return send_from_directory(upload_folder_abs, filename)

# 确保在应用启动时调用init_db()
init_db()

# 主函数
if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
