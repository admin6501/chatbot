#!/bin/bash
# -*- coding: utf-8 -*-
#
# اسکریپت نصب خودکار ربات تلگرام با API سایت chat01.ai
# Auto-install script for Telegram Bot with chat01.ai API
#

set -e

# رنگ‌ها برای خروجی
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# تابع نمایش پیام
print_msg() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

print_header() {
    echo -e "\n${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}\n"
}

# بنر شروع
clear
echo -e "${CYAN}"
cat << "EOF"
  ╔═══════════════════════════════════════════════════════════╗
  ║                                                           ║
  ║    🤖 نصب خودکار ربات تلگرام با API سایت chat01.ai 🤖    ║
  ║                                                           ║
  ║    Telegram Bot Auto-Installer with chat01.ai API         ║
  ║                                                           ║
  ╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

# ==================== بررسی و نصب پیش‌نیازها ====================

print_header "بررسی پیش‌نیازها / Checking Prerequisites"

# بررسی سیستم‌عامل
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    if [ -f /etc/debian_version ]; then
        PKG_MANAGER="apt-get"
        PKG_UPDATE="sudo apt-get update"
        PKG_INSTALL="sudo apt-get install -y"
    elif [ -f /etc/redhat-release ]; then
        PKG_MANAGER="yum"
        PKG_UPDATE="sudo yum update -y"
        PKG_INSTALL="sudo yum install -y"
    else
        PKG_MANAGER="unknown"
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    PKG_MANAGER="brew"
    PKG_UPDATE="brew update"
    PKG_INSTALL="brew install"
else
    print_error "سیستم‌عامل پشتیبانی نمی‌شود / Unsupported OS"
    exit 1
fi

print_info "سیستم‌عامل: $OS"

# بررسی و نصب Python
print_info "بررسی Python..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
    print_msg "Python نصب است: $PYTHON_VERSION"
else
    print_warn "Python یافت نشد. در حال نصب..."
    if [ "$PKG_MANAGER" != "unknown" ]; then
        $PKG_UPDATE
        $PKG_INSTALL python3 python3-pip python3-venv
    else
        print_error "لطفاً Python را به صورت دستی نصب کنید."
        exit 1
    fi
fi

# بررسی pip
print_info "بررسی pip..."
if command -v pip3 &> /dev/null; then
    print_msg "pip نصب است"
else
    print_warn "pip یافت نشد. در حال نصب..."
    if [ "$PKG_MANAGER" == "apt-get" ]; then
        $PKG_INSTALL python3-pip
    elif [ "$PKG_MANAGER" == "yum" ]; then
        $PKG_INSTALL python3-pip
    elif [ "$PKG_MANAGER" == "brew" ]; then
        # pip معمولاً با python3 نصب می‌شود
        python3 -m ensurepip --upgrade
    fi
fi

# نصب python3-venv (بدون بررسی - همیشه نصب می‌کنیم)
print_info "نصب python3-venv..."
if [ "$PKG_MANAGER" == "apt-get" ]; then
    # پیدا کردن نسخه پایتون
    PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    print_info "نسخه پایتون: $PYTHON_VERSION"
    
    sudo apt-get update
    sudo apt-get install -y python${PYTHON_VERSION}-venv || \
    sudo apt-get install -y python3-venv || \
    sudo apt-get install -y python3.10-venv || \
    sudo apt-get install -y python3.11-venv || \
    sudo apt-get install -y python3.12-venv
    print_msg "python3-venv نصب شد"
elif [ "$PKG_MANAGER" == "yum" ]; then
    sudo yum install -y python3-virtualenv
    print_msg "python3-virtualenv نصب شد"
fi

# ==================== دریافت اطلاعات ====================

print_header "دریافت اطلاعات / Getting Information"

# دریافت توکن ربات تلگرام
echo -e "${YELLOW}"
echo "لطفاً توکن ربات تلگرام را از @BotFather وارد کنید:"
echo "Please enter your Telegram Bot Token from @BotFather:"
echo -e "${NC}"
read -p "Bot Token: " BOT_TOKEN

if [ -z "$BOT_TOKEN" ]; then
    print_error "توکن ربات نمی‌تواند خالی باشد!"
    exit 1
fi

# دریافت API Key سایت chat01.ai
echo -e "\n${YELLOW}"
echo "لطفاً API Key سایت chat01.ai را وارد کنید:"
echo "Please enter your chat01.ai API Key:"
echo -e "${NC}"
read -p "API Key: " CHAT01_API_KEY

if [ -z "$CHAT01_API_KEY" ]; then
    print_error "API Key نمی‌تواند خالی باشد!"
    exit 1
fi

# دریافت آیدی ادمین
echo -e "\n${YELLOW}"
echo "لطفاً آیدی عددی تلگرام ادمین را وارد کنید:"
echo "Please enter the Admin's numeric Telegram ID:"
echo "(می‌توانید از @userinfobot آیدی خود را دریافت کنید)"
echo -e "${NC}"
read -p "Admin ID: " ADMIN_ID

if [ -z "$ADMIN_ID" ]; then
    print_error "آیدی ادمین نمی‌تواند خالی باشد!"
    exit 1
fi

# دریافت مدل پیش‌فرض
echo -e "\n${YELLOW}"
echo "لطفاً مدل پیش‌فرض AI را انتخاب کنید:"
echo "Please select the default AI model:"
echo ""
echo "  1) gpt-4o"
echo "  2) gpt-5-2"
echo "  3) gpt-5-2-thinking"
echo "  4) gpt-5-2-instant"
echo "  5) gpt-5-1-thinking"
echo "  6) gpt-5-1-instant"
echo "  7) o3"
echo "  8) مدل سفارشی / Custom model"
echo -e "${NC}"
read -p "انتخاب (1-8): " MODEL_CHOICE

case $MODEL_CHOICE in
    1) DEFAULT_MODEL="gpt-4o" ;;
    2) DEFAULT_MODEL="gpt-5-2" ;;
    3) DEFAULT_MODEL="gpt-5-2-thinking" ;;
    4) DEFAULT_MODEL="gpt-5-2-instant" ;;
    5) DEFAULT_MODEL="gpt-5-1-thinking" ;;
    6) DEFAULT_MODEL="gpt-5-1-instant" ;;
    7) DEFAULT_MODEL="o3" ;;
    8)
        echo -e "${YELLOW}نام مدل سفارشی را وارد کنید:${NC}"
        read -p "Model name: " DEFAULT_MODEL
        ;;
    *)
        DEFAULT_MODEL="gpt-4o"
        print_warn "انتخاب نامعتبر. مدل پیش‌فرض: gpt-4o"
        ;;
esac

print_msg "مدل انتخاب شده: $DEFAULT_MODEL"

# ==================== ایجاد دایرکتوری و فایل‌ها ====================

print_header "ایجاد فایل‌ها / Creating Files"

# تعیین مسیر نصب
INSTALL_DIR="$HOME/chat01_telegram_bot"
print_info "مسیر نصب: $INSTALL_DIR"

# ایجاد دایرکتوری
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# ایجاد فایل config.py
print_info "ایجاد فایل config.py..."
cat > config.py << CONFIGEOF
# -*- coding: utf-8 -*-
"""
تنظیمات ربات تلگرام
Configuration for Telegram Bot
"""

import os

# توکن ربات تلگرام
BOT_TOKEN = os.environ.get('BOT_TOKEN', '$BOT_TOKEN')

# API Key سایت chat01.ai
CHAT01_API_KEY = os.environ.get('CHAT01_API_KEY', '$CHAT01_API_KEY')

# آیدی ادمین
ADMIN_ID = int(os.environ.get('ADMIN_ID', '$ADMIN_ID'))

# تنظیمات API
API_BASE_URL = "https://chat01.ai"
API_ENDPOINT = f"{API_BASE_URL}/v1/chat/completions"

# مدل پیش‌فرض
DEFAULT_MODEL = os.environ.get('DEFAULT_MODEL', '$DEFAULT_MODEL')

# محدودیت پیش‌فرض پیام روزانه
DEFAULT_DAILY_LIMIT = 20

# تنظیمات دیتابیس
DATABASE_PATH = os.path.join(os.path.dirname(__file__), 'bot_database.db')

# پیام‌های ربات
MESSAGES = {
    'welcome': '🤖 به ربات چت هوش مصنوعی خوش آمدید!\n\nاز دکمه‌های زیر استفاده کنید:',
    'new_chat': '✨ گفتگوی جدید شروع شد!',
    'chat_cleared': '🗑 تاریخچه گفتگو پاک شد.',
    'blocked': '⛔ شما از استفاده از این ربات محروم شده‌اید.',
    'limit_reached': '⚠️ شما به محدودیت پیام روزانه ({limit} پیام) رسیده‌اید.\nفردا دوباره تلاش کنید یا با ادمین تماس بگیرید.',
    'processing': '⏳ در حال پردازش...',
    'error': '❌ خطا در پردازش درخواست. لطفاً دوباره تلاش کنید.',
    'admin_only': '⛔ این دستور فقط برای ادمین است.',
    'user_not_found': '❌ کاربر یافت نشد.',
    'user_blocked': '✅ کاربر {user_id} بلاک شد.',
    'user_unblocked': '✅ کاربر {user_id} آن‌بلاک شد.',
    'limit_set': '✅ محدودیت کاربر {user_id} به {limit} پیام تنظیم شد.',
    'limit_removed': '✅ محدودیت کاربر {user_id} برداشته شد (نامحدود).',
    'select_chat': '📝 یک گفتگو انتخاب کنید:',
    'no_chats': '📭 هیچ گفتگویی وجود ندارد.',
    'chat_switched': '✅ به گفتگوی {chat_name} تغییر یافت.',
    'stats': '📊 آمار شما:\n\n📨 پیام‌های امروز: {today}\n📝 محدودیت روزانه: {limit}\n💬 تعداد گفتگوها: {chats}',
}
CONFIGEOF
print_msg "فایل config.py ایجاد شد"

# ایجاد فایل database.py
print_info "ایجاد فایل database.py..."
cat > database.py << 'DBEOF'
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
DBEOF
print_msg "فایل database.py ایجاد شد"

# ایجاد فایل bot.py
print_info "ایجاد فایل bot.py..."
cat > bot.py << 'BOTEOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ربات تلگرام با API سایت chat01.ai
Telegram Bot with chat01.ai API
"""

import asyncio
import logging
import httpx
from typing import Optional

from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    Application,
    CommandHandler,
    MessageHandler,
    CallbackQueryHandler,
    filters,
    ContextTypes,
)

from config import (
    BOT_TOKEN,
    CHAT01_API_KEY,
    ADMIN_ID,
    API_ENDPOINT,
    DEFAULT_MODEL,
    MESSAGES,
)
from database import db

# تنظیمات لاگ
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)


# ==================== کیبوردها ====================

def get_main_keyboard() -> InlineKeyboardMarkup:
    """کیبورد اصلی"""
    keyboard = [
        [InlineKeyboardButton("✨ گفتگوی جدید", callback_data="new_chat")],
        [InlineKeyboardButton("📝 گفتگوهای من", callback_data="my_chats")],
        [InlineKeyboardButton("🗑 پاک کردن تاریخچه", callback_data="clear_history")],
        [InlineKeyboardButton("📊 آمار من", callback_data="my_stats")],
    ]
    return InlineKeyboardMarkup(keyboard)


def get_admin_keyboard() -> InlineKeyboardMarkup:
    """کیبورد ادمین"""
    keyboard = [
        [InlineKeyboardButton("👥 لیست کاربران", callback_data="admin_users")],
        [InlineKeyboardButton("🔙 بازگشت", callback_data="back_main")],
    ]
    return InlineKeyboardMarkup(keyboard)


def get_chats_keyboard(chats: list) -> InlineKeyboardMarkup:
    """کیبورد لیست گفتگوها"""
    keyboard = []
    for chat in chats[:10]:  # حداکثر 10 گفتگو
        status = "✅" if chat['is_active'] else "⚪"
        keyboard.append([
            InlineKeyboardButton(
                f"{status} {chat['chat_name'][:30]}",
                callback_data=f"switch_chat:{chat['chat_id']}"
            )
        ])
    keyboard.append([InlineKeyboardButton("🔙 بازگشت", callback_data="back_main")])
    return InlineKeyboardMarkup(keyboard)


def get_user_actions_keyboard(user_id: int, is_blocked: bool) -> InlineKeyboardMarkup:
    """کیبورد عملیات روی کاربر"""
    keyboard = [
        [
            InlineKeyboardButton(
                "🔓 آن‌بلاک" if is_blocked else "🔒 بلاک",
                callback_data=f"toggle_block:{user_id}"
            )
        ],
        [
            InlineKeyboardButton("📝 تنظیم محدودیت", callback_data=f"set_limit:{user_id}"),
            InlineKeyboardButton("♾ نامحدود", callback_data=f"unlimited:{user_id}"),
        ],
        [InlineKeyboardButton("🔙 بازگشت", callback_data="admin_users")],
    ]
    return InlineKeyboardMarkup(keyboard)


# ==================== توابع API ====================

async def chat_with_ai(messages: list) -> Optional[str]:
    """ارسال درخواست به API و دریافت پاسخ"""
    headers = {
        "Authorization": f"Bearer {CHAT01_API_KEY}",
        "Content-Type": "application/json",
    }
    
    payload = {
        "model": DEFAULT_MODEL,
        "messages": messages,
    }
    
    try:
        async with httpx.AsyncClient(timeout=120.0) as client:
            response = await client.post(API_ENDPOINT, json=payload, headers=headers)
            response.raise_for_status()
            data = response.json()
            return data['choices'][0]['message']['content']
    except httpx.TimeoutException:
        logger.error("API request timed out")
        return None
    except Exception as e:
        logger.error(f"API error: {e}")
        return None


# ==================== هندلرهای دستورات ====================

async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """دستور /start"""
    user = update.effective_user
    db.get_or_create_user(user.id, user.username, user.first_name)
    
    # بررسی بلاک
    if db.is_user_blocked(user.id):
        await update.message.reply_text(MESSAGES['blocked'])
        return
    
    # ایجاد گفتگوی جدید اگر وجود ندارد
    if not db.get_active_chat(user.id):
        db.create_chat(user.id)
    
    await update.message.reply_text(
        MESSAGES['welcome'],
        reply_markup=get_main_keyboard()
    )


async def admin_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """دستور /admin برای پنل مدیریت"""
    user = update.effective_user
    
    if user.id != ADMIN_ID:
        await update.message.reply_text(MESSAGES['admin_only'])
        return
    
    await update.message.reply_text(
        "🔧 پنل مدیریت:\n\nیک گزینه انتخاب کنید:",
        reply_markup=get_admin_keyboard()
    )


async def block_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """دستور /block [user_id]"""
    user = update.effective_user
    
    if user.id != ADMIN_ID:
        await update.message.reply_text(MESSAGES['admin_only'])
        return
    
    if not context.args:
        await update.message.reply_text("استفاده: /block [user_id]")
        return
    
    try:
        target_id = int(context.args[0])
        if db.block_user(target_id):
            await update.message.reply_text(MESSAGES['user_blocked'].format(user_id=target_id))
        else:
            await update.message.reply_text(MESSAGES['user_not_found'])
    except ValueError:
        await update.message.reply_text("آیدی نامعتبر است.")


async def unblock_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """دستور /unblock [user_id]"""
    user = update.effective_user
    
    if user.id != ADMIN_ID:
        await update.message.reply_text(MESSAGES['admin_only'])
        return
    
    if not context.args:
        await update.message.reply_text("استفاده: /unblock [user_id]")
        return
    
    try:
        target_id = int(context.args[0])
        if db.unblock_user(target_id):
            await update.message.reply_text(MESSAGES['user_unblocked'].format(user_id=target_id))
        else:
            await update.message.reply_text(MESSAGES['user_not_found'])
    except ValueError:
        await update.message.reply_text("آیدی نامعتبر است.")


async def setlimit_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """دستور /setlimit [user_id] [limit]"""
    user = update.effective_user
    
    if user.id != ADMIN_ID:
        await update.message.reply_text(MESSAGES['admin_only'])
        return
    
    if len(context.args) < 2:
        await update.message.reply_text("استفاده: /setlimit [user_id] [limit]\nبرای نامحدود: /setlimit [user_id] -1")
        return
    
    try:
        target_id = int(context.args[0])
        limit = int(context.args[1])
        
        if db.set_user_limit(target_id, limit):
            if limit == -1:
                await update.message.reply_text(MESSAGES['limit_removed'].format(user_id=target_id))
            else:
                await update.message.reply_text(MESSAGES['limit_set'].format(user_id=target_id, limit=limit))
        else:
            await update.message.reply_text(MESSAGES['user_not_found'])
    except ValueError:
        await update.message.reply_text("مقادیر نامعتبر هستند.")


# ==================== هندلرهای Callback ====================

async def callback_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """هندلر callback های دکمه‌ها"""
    query = update.callback_query
    await query.answer()
    
    user = query.from_user
    data = query.data
    
    # بررسی بلاک
    if db.is_user_blocked(user.id):
        await query.edit_message_text(MESSAGES['blocked'])
        return
    
    # گفتگوی جدید
    if data == "new_chat":
        db.create_chat(user.id)
        await query.edit_message_text(
            MESSAGES['new_chat'],
            reply_markup=get_main_keyboard()
        )
    
    # لیست گفتگوها
    elif data == "my_chats":
        chats = db.get_user_chats(user.id)
        if not chats:
            await query.edit_message_text(
                MESSAGES['no_chats'],
                reply_markup=get_main_keyboard()
            )
        else:
            await query.edit_message_text(
                MESSAGES['select_chat'],
                reply_markup=get_chats_keyboard(chats)
            )
    
    # پاک کردن تاریخچه
    elif data == "clear_history":
        active_chat = db.get_active_chat(user.id)
        if active_chat:
            db.clear_chat_history(active_chat['chat_id'])
        await query.edit_message_text(
            MESSAGES['chat_cleared'],
            reply_markup=get_main_keyboard()
        )
    
    # آمار کاربر
    elif data == "my_stats":
        stats = db.get_user_stats(user.id)
        await query.edit_message_text(
            MESSAGES['stats'].format(**stats),
            reply_markup=get_main_keyboard()
        )
    
    # بازگشت به منوی اصلی
    elif data == "back_main":
        await query.edit_message_text(
            MESSAGES['welcome'],
            reply_markup=get_main_keyboard()
        )
    
    # تغییر گفتگو
    elif data.startswith("switch_chat:"):
        chat_id = data.split(":")[1]
        chats = db.get_user_chats(user.id)
        chat = next((c for c in chats if c['chat_id'] == chat_id), None)
        
        if chat:
            db.switch_chat(user.id, chat_id)
            await query.edit_message_text(
                MESSAGES['chat_switched'].format(chat_name=chat['chat_name']),
                reply_markup=get_main_keyboard()
            )
    
    # === عملیات ادمین ===
    
    # لیست کاربران
    elif data == "admin_users":
        if user.id != ADMIN_ID:
            await query.edit_message_text(MESSAGES['admin_only'])
            return
        
        users = db.get_all_users()
        text = "👥 لیست کاربران:\n\n"
        keyboard = []
        
        for u in users[:20]:  # حداکثر 20 کاربر
            status = "🔴" if u['is_blocked'] else "🟢"
            limit = "♾" if u['daily_limit'] == -1 else str(u['daily_limit'])
            name = u['first_name'] or u['username'] or str(u['user_id'])
            text += f"{status} {name} (ID: {u['user_id']}) - محدودیت: {limit}\n"
            keyboard.append([
                InlineKeyboardButton(
                    f"{status} {name[:20]}",
                    callback_data=f"user_actions:{u['user_id']}"
                )
            ])
        
        keyboard.append([InlineKeyboardButton("🔙 بازگشت", callback_data="back_main")])
        await query.edit_message_text(text, reply_markup=InlineKeyboardMarkup(keyboard))
    
    # عملیات روی کاربر
    elif data.startswith("user_actions:"):
        if user.id != ADMIN_ID:
            return
        
        target_id = int(data.split(":")[1])
        is_blocked = db.is_user_blocked(target_id)
        limit = db.get_user_limit(target_id)
        
        text = f"👤 کاربر: {target_id}\n"
        text += f"وضعیت: {'🔴 بلاک شده' if is_blocked else '🟢 فعال'}\n"
        text += f"محدودیت: {'♾ نامحدود' if limit == -1 else f'{limit} پیام'}\n"
        
        await query.edit_message_text(
            text,
            reply_markup=get_user_actions_keyboard(target_id, is_blocked)
        )
    
    # بلاک/آن‌بلاک
    elif data.startswith("toggle_block:"):
        if user.id != ADMIN_ID:
            return
        
        target_id = int(data.split(":")[1])
        if db.is_user_blocked(target_id):
            db.unblock_user(target_id)
        else:
            db.block_user(target_id)
        
        # بروزرسانی منو
        is_blocked = db.is_user_blocked(target_id)
        limit = db.get_user_limit(target_id)
        
        text = f"👤 کاربر: {target_id}\n"
        text += f"وضعیت: {'🔴 بلاک شده' if is_blocked else '🟢 فعال'}\n"
        text += f"محدودیت: {'♾ نامحدود' if limit == -1 else f'{limit} پیام'}\n"
        
        await query.edit_message_text(
            text,
            reply_markup=get_user_actions_keyboard(target_id, is_blocked)
        )
    
    # نامحدود کردن
    elif data.startswith("unlimited:"):
        if user.id != ADMIN_ID:
            return
        
        target_id = int(data.split(":")[1])
        db.set_user_limit(target_id, -1)
        
        is_blocked = db.is_user_blocked(target_id)
        text = f"👤 کاربر: {target_id}\n"
        text += f"وضعیت: {'🔴 بلاک شده' if is_blocked else '🟢 فعال'}\n"
        text += f"محدودیت: ♾ نامحدود\n"
        text += "\n✅ محدودیت برداشته شد."
        
        await query.edit_message_text(
            text,
            reply_markup=get_user_actions_keyboard(target_id, is_blocked)
        )
    
    # تنظیم محدودیت (نیاز به ورود عدد)
    elif data.startswith("set_limit:"):
        if user.id != ADMIN_ID:
            return
        
        target_id = data.split(":")[1]
        context.user_data['setting_limit_for'] = target_id
        
        await query.edit_message_text(
            f"📝 لطفاً محدودیت جدید برای کاربر {target_id} را وارد کنید:\n\n(یک عدد وارد کنید یا -1 برای نامحدود)"
        )


# ==================== هندلر پیام‌ها ====================

async def message_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """هندلر پیام‌های متنی"""
    user = update.effective_user
    message_text = update.message.text
    
    # بررسی بلاک
    if db.is_user_blocked(user.id):
        await update.message.reply_text(MESSAGES['blocked'])
        return
    
    # بررسی اینکه آیا ادمین در حال تنظیم محدودیت است
    if user.id == ADMIN_ID and 'setting_limit_for' in context.user_data:
        try:
            limit = int(message_text)
            target_id = int(context.user_data['setting_limit_for'])
            del context.user_data['setting_limit_for']
            
            if db.set_user_limit(target_id, limit):
                if limit == -1:
                    await update.message.reply_text(
                        MESSAGES['limit_removed'].format(user_id=target_id),
                        reply_markup=get_admin_keyboard()
                    )
                else:
                    await update.message.reply_text(
                        MESSAGES['limit_set'].format(user_id=target_id, limit=limit),
                        reply_markup=get_admin_keyboard()
                    )
            else:
                await update.message.reply_text(MESSAGES['user_not_found'])
            return
        except ValueError:
            await update.message.reply_text("لطفاً یک عدد معتبر وارد کنید.")
            return
    
    # اطمینان از وجود کاربر
    db.get_or_create_user(user.id, user.username, user.first_name)
    
    # بررسی محدودیت
    can_send, limit, usage = db.can_send_message(user.id)
    if not can_send:
        await update.message.reply_text(
            MESSAGES['limit_reached'].format(limit=limit),
            reply_markup=get_main_keyboard()
        )
        return
    
    # دریافت یا ایجاد گفتگوی فعال
    active_chat = db.get_active_chat(user.id)
    if not active_chat:
        chat_id = db.create_chat(user.id)
        active_chat = {'chat_id': chat_id}
    
    # ذخیره پیام کاربر
    db.add_message(active_chat['chat_id'], 'user', message_text)
    
    # نمایش پیام در حال پردازش
    processing_msg = await update.message.reply_text(MESSAGES['processing'])
    
    # دریافت تاریخچه و ارسال به API
    chat_history = db.get_chat_messages(active_chat['chat_id'])
    
    response = await chat_with_ai(chat_history)
    
    if response:
        # افزایش شمارنده استفاده
        db.increment_daily_usage(user.id)
        
        # ذخیره پاسخ
        db.add_message(active_chat['chat_id'], 'assistant', response)
        
        # ویرایش پیام در حال پردازش با پاسخ
        await processing_msg.edit_text(response)
    else:
        await processing_msg.edit_text(MESSAGES['error'])


# ==================== اجرای ربات ====================

def main():
    """تابع اصلی اجرای ربات"""
    # ایجاد اپلیکیشن
    application = Application.builder().token(BOT_TOKEN).build()
    
    # افزودن هندلرها
    application.add_handler(CommandHandler("start", start_command))
    application.add_handler(CommandHandler("admin", admin_command))
    application.add_handler(CommandHandler("block", block_command))
    application.add_handler(CommandHandler("unblock", unblock_command))
    application.add_handler(CommandHandler("setlimit", setlimit_command))
    
    application.add_handler(CallbackQueryHandler(callback_handler))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, message_handler))
    
    # اجرای ربات
    logger.info("Bot started...")
    application.run_polling(allowed_updates=Update.ALL_TYPES)


if __name__ == "__main__":
    main()
BOTEOF
print_msg "فایل bot.py ایجاد شد"

# ایجاد فایل requirements.txt
print_info "ایجاد فایل requirements.txt..."
cat > requirements.txt << 'REQEOF'
python-telegram-bot==21.3
httpx==0.27.0
REQEOF
print_msg "فایل requirements.txt ایجاد شد"

# ==================== نصب وابستگی‌ها ====================

print_header "نصب وابستگی‌ها / Installing Dependencies"

# نصب python3-venv (اجباری قبل از ایجاد محیط مجازی)
print_info "اطمینان از نصب python3-venv..."
if [ -f /etc/debian_version ]; then
    PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    print_info "نسخه پایتون: $PYTHON_VERSION"
    sudo apt-get update
    sudo apt-get install -y python${PYTHON_VERSION}-venv || \
    sudo apt-get install -y python3-venv || \
    sudo apt-get install -y python3.10-venv || \
    sudo apt-get install -y python3.11-venv || \
    sudo apt-get install -y python3.12-venv
    print_msg "python3-venv آماده است"
elif [ -f /etc/redhat-release ]; then
    sudo yum install -y python3-virtualenv
fi

# ایجاد محیط مجازی
print_info "ایجاد محیط مجازی Python..."
python3 -m venv venv || {
    print_error "خطا در ایجاد محیط مجازی!"
    print_info "تلاش مجدد..."
    rm -rf venv
    python3 -m venv venv
}
source venv/bin/activate

# نصب وابستگی‌ها
print_info "نصب کتابخانه‌های مورد نیاز..."
pip install --upgrade pip
pip install -r requirements.txt

print_msg "وابستگی‌ها با موفقیت نصب شدند"

# ==================== ایجاد اسکریپت اجرا ====================

print_info "ایجاد اسکریپت اجرا..."
cat > run.sh << 'RUNEOF'
#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate
python3 bot.py
RUNEOF
chmod +x run.sh

print_msg "اسکریپت run.sh ایجاد شد"

# ==================== پایان ====================

print_header "نصب کامل شد! / Installation Complete!"

echo -e "${GREEN}"
cat << EOF

✅ ربات با موفقیت نصب شد!
   Bot installed successfully!

📂 مسیر نصب: $INSTALL_DIR

🚀 برای اجرای ربات:
   cd $INSTALL_DIR
   ./run.sh

   یا:
   cd $INSTALL_DIR
   source venv/bin/activate
   python3 bot.py

📋 دستورات ادمین:
   /admin - پنل مدیریت
   /block [user_id] - بلاک کردن کاربر
   /unblock [user_id] - آن‌بلاک کردن کاربر
   /setlimit [user_id] [limit] - تنظیم محدودیت

📋 دستورات کاربران:
   /start - شروع ربات

EOF
echo -e "${NC}"

# پرسش برای اجرای فوری
echo -e "${YELLOW}"
read -p "آیا می‌خواهید ربات همین الان اجرا شود؟ (y/n): " RUN_NOW
echo -e "${NC}"

if [[ "$RUN_NOW" == "y" || "$RUN_NOW" == "Y" ]]; then
    print_info "در حال اجرای ربات..."
    ./run.sh
fi
