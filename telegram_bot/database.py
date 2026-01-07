# -*- coding: utf-8 -*-
"""
مدیریت دیتابیس SQLite
Database Management for Telegram Bot
"""

import sqlite3
import json
from datetime import datetime, date
from typing import Optional, List, Dict, Any
import uuid

from config import DATABASE_PATH, DEFAULT_DAILY_LIMIT


class Database:
    def __init__(self, db_path: str = DATABASE_PATH):
        self.db_path = db_path
        self.init_db()
    
    def get_connection(self):
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn
    
    def init_db(self):
        """ایجاد جداول دیتابیس"""
        conn = self.get_connection()
        cursor = conn.cursor()
        
        # جدول کاربران
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS users (
                user_id INTEGER PRIMARY KEY,
                username TEXT,
                first_name TEXT,
                is_blocked INTEGER DEFAULT 0,
                daily_limit INTEGER DEFAULT -1,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # جدول گفتگوها
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS chats (
                chat_id TEXT PRIMARY KEY,
                user_id INTEGER,
                chat_name TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                is_active INTEGER DEFAULT 1,
                FOREIGN KEY (user_id) REFERENCES users(user_id)
            )
        ''')
        
        # جدول پیام‌ها
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS messages (
                message_id TEXT PRIMARY KEY,
                chat_id TEXT,
                role TEXT,
                content TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (chat_id) REFERENCES chats(chat_id)
            )
        ''')
        
        # جدول آمار روزانه
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS daily_usage (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER,
                usage_date TEXT,
                message_count INTEGER DEFAULT 0,
                UNIQUE(user_id, usage_date),
                FOREIGN KEY (user_id) REFERENCES users(user_id)
            )
        ''')
        
        conn.commit()
        conn.close()
    
    # ==================== مدیریت کاربران ====================
    
    def get_or_create_user(self, user_id: int, username: str = None, first_name: str = None) -> Dict:
        """دریافت یا ایجاد کاربر"""
        conn = self.get_connection()
        cursor = conn.cursor()
        
        cursor.execute('SELECT * FROM users WHERE user_id = ?', (user_id,))
        user = cursor.fetchone()
        
        if not user:
            cursor.execute(
                'INSERT INTO users (user_id, username, first_name, daily_limit) VALUES (?, ?, ?, ?)',
                (user_id, username, first_name, DEFAULT_DAILY_LIMIT)
            )
            conn.commit()
            cursor.execute('SELECT * FROM users WHERE user_id = ?', (user_id,))
            user = cursor.fetchone()
        
        conn.close()
        return dict(user)
    
    def is_user_blocked(self, user_id: int) -> bool:
        """بررسی بلاک بودن کاربر"""
        conn = self.get_connection()
        cursor = conn.cursor()
        cursor.execute('SELECT is_blocked FROM users WHERE user_id = ?', (user_id,))
        result = cursor.fetchone()
        conn.close()
        return result and result['is_blocked'] == 1
    
    def block_user(self, user_id: int) -> bool:
        """بلاک کردن کاربر"""
        conn = self.get_connection()
        cursor = conn.cursor()
        cursor.execute('UPDATE users SET is_blocked = 1 WHERE user_id = ?', (user_id,))
        affected = cursor.rowcount
        conn.commit()
        conn.close()
        return affected > 0
    
    def unblock_user(self, user_id: int) -> bool:
        """آن‌بلاک کردن کاربر"""
        conn = self.get_connection()
        cursor = conn.cursor()
        cursor.execute('UPDATE users SET is_blocked = 0 WHERE user_id = ?', (user_id,))
        affected = cursor.rowcount
        conn.commit()
        conn.close()
        return affected > 0
    
    def set_user_limit(self, user_id: int, limit: int) -> bool:
        """تنظیم محدودیت کاربر (-1 = نامحدود)"""
        conn = self.get_connection()
        cursor = conn.cursor()
        cursor.execute('UPDATE users SET daily_limit = ? WHERE user_id = ?', (limit, user_id))
        affected = cursor.rowcount
        conn.commit()
        conn.close()
        return affected > 0
    
    def get_user_limit(self, user_id: int) -> int:
        """دریافت محدودیت کاربر"""
        conn = self.get_connection()
        cursor = conn.cursor()
        cursor.execute('SELECT daily_limit FROM users WHERE user_id = ?', (user_id,))
        result = cursor.fetchone()
        conn.close()
        if result:
            return result['daily_limit']
        return DEFAULT_DAILY_LIMIT
    
    def get_all_users(self) -> List[Dict]:
        """دریافت لیست همه کاربران"""
        conn = self.get_connection()
        cursor = conn.cursor()
        cursor.execute('SELECT * FROM users ORDER BY created_at DESC')
        users = [dict(row) for row in cursor.fetchall()]
        conn.close()
        return users
    
    # ==================== مدیریت گفتگوها ====================
    
    def create_chat(self, user_id: int, chat_name: str = None) -> str:
        """ایجاد گفتگوی جدید"""
        chat_id = str(uuid.uuid4())
        if not chat_name:
            chat_name = f"گفتگو {datetime.now().strftime('%Y/%m/%d %H:%M')}"
        
        conn = self.get_connection()
        cursor = conn.cursor()
        
        # غیرفعال کردن گفتگوهای قبلی
        cursor.execute('UPDATE chats SET is_active = 0 WHERE user_id = ?', (user_id,))
        
        # ایجاد گفتگوی جدید
        cursor.execute(
            'INSERT INTO chats (chat_id, user_id, chat_name, is_active) VALUES (?, ?, ?, 1)',
            (chat_id, user_id, chat_name)
        )
        
        conn.commit()
        conn.close()
        return chat_id
    
    def get_active_chat(self, user_id: int) -> Optional[Dict]:
        """دریافت گفتگوی فعال کاربر"""
        conn = self.get_connection()
        cursor = conn.cursor()
        cursor.execute(
            'SELECT * FROM chats WHERE user_id = ? AND is_active = 1',
            (user_id,)
        )
        chat = cursor.fetchone()
        conn.close()
        return dict(chat) if chat else None
    
    def get_user_chats(self, user_id: int) -> List[Dict]:
        """دریافت همه گفتگوهای کاربر"""
        conn = self.get_connection()
        cursor = conn.cursor()
        cursor.execute(
            'SELECT * FROM chats WHERE user_id = ? ORDER BY created_at DESC',
            (user_id,)
        )
        chats = [dict(row) for row in cursor.fetchall()]
        conn.close()
        return chats
    
    def switch_chat(self, user_id: int, chat_id: str) -> bool:
        """تغییر گفتگوی فعال"""
        conn = self.get_connection()
        cursor = conn.cursor()
        
        # غیرفعال کردن همه گفتگوها
        cursor.execute('UPDATE chats SET is_active = 0 WHERE user_id = ?', (user_id,))
        
        # فعال کردن گفتگوی انتخاب شده
        cursor.execute(
            'UPDATE chats SET is_active = 1 WHERE chat_id = ? AND user_id = ?',
            (chat_id, user_id)
        )
        
        affected = cursor.rowcount
        conn.commit()
        conn.close()
        return affected > 0
    
    def delete_chat(self, chat_id: str) -> bool:
        """حذف گفتگو و پیام‌های آن"""
        conn = self.get_connection()
        cursor = conn.cursor()
        
        cursor.execute('DELETE FROM messages WHERE chat_id = ?', (chat_id,))
        cursor.execute('DELETE FROM chats WHERE chat_id = ?', (chat_id,))
        
        affected = cursor.rowcount
        conn.commit()
        conn.close()
        return affected > 0
    
    def clear_chat_history(self, chat_id: str) -> bool:
        """پاک کردن تاریخچه گفتگو"""
        conn = self.get_connection()
        cursor = conn.cursor()
        cursor.execute('DELETE FROM messages WHERE chat_id = ?', (chat_id,))
        conn.commit()
        conn.close()
        return True
    
    # ==================== مدیریت پیام‌ها ====================
    
    def add_message(self, chat_id: str, role: str, content: str) -> str:
        """افزودن پیام به گفتگو"""
        message_id = str(uuid.uuid4())
        conn = self.get_connection()
        cursor = conn.cursor()
        cursor.execute(
            'INSERT INTO messages (message_id, chat_id, role, content) VALUES (?, ?, ?, ?)',
            (message_id, chat_id, role, content)
        )
        conn.commit()
        conn.close()
        return message_id
    
    def get_chat_messages(self, chat_id: str) -> List[Dict]:
        """دریافت پیام‌های یک گفتگو"""
        conn = self.get_connection()
        cursor = conn.cursor()
        cursor.execute(
            'SELECT role, content FROM messages WHERE chat_id = ? ORDER BY created_at ASC',
            (chat_id,)
        )
        messages = [dict(row) for row in cursor.fetchall()]
        conn.close()
        return messages
    
    # ==================== مدیریت آمار ====================
    
    def increment_daily_usage(self, user_id: int) -> int:
        """افزایش شمارنده استفاده روزانه"""
        today = date.today().isoformat()
        conn = self.get_connection()
        cursor = conn.cursor()
        
        cursor.execute(
            'INSERT OR IGNORE INTO daily_usage (user_id, usage_date, message_count) VALUES (?, ?, 0)',
            (user_id, today)
        )
        cursor.execute(
            'UPDATE daily_usage SET message_count = message_count + 1 WHERE user_id = ? AND usage_date = ?',
            (user_id, today)
        )
        
        cursor.execute(
            'SELECT message_count FROM daily_usage WHERE user_id = ? AND usage_date = ?',
            (user_id, today)
        )
        result = cursor.fetchone()
        
        conn.commit()
        conn.close()
        return result['message_count'] if result else 0
    
    def get_daily_usage(self, user_id: int) -> int:
        """دریافت استفاده روزانه کاربر"""
        today = date.today().isoformat()
        conn = self.get_connection()
        cursor = conn.cursor()
        cursor.execute(
            'SELECT message_count FROM daily_usage WHERE user_id = ? AND usage_date = ?',
            (user_id, today)
        )
        result = cursor.fetchone()
        conn.close()
        return result['message_count'] if result else 0
    
    def can_send_message(self, user_id: int) -> tuple:
        """بررسی امکان ارسال پیام"""
        limit = self.get_user_limit(user_id)
        usage = self.get_daily_usage(user_id)
        
        # -1 = نامحدود
        if limit == -1:
            return True, limit, usage
        
        return usage < limit, limit, usage
    
    def get_user_stats(self, user_id: int) -> Dict:
        """دریافت آمار کاربر"""
        usage = self.get_daily_usage(user_id)
        limit = self.get_user_limit(user_id)
        chats = len(self.get_user_chats(user_id))
        
        return {
            'today': usage,
            'limit': 'نامحدود' if limit == -1 else limit,
            'chats': chats
        }


# نمونه singleton
db = Database()
