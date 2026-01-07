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
