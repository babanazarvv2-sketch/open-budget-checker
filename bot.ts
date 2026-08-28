import 'dotenv/config';
import { Bot } from 'grammy';
import { setupBotHandlers } from './src/lib/bot/handlers';

const token = process.env.TELEGRAM_BOT_TOKEN;

if (!token || token.includes('BOT_TOKENINGIZNI')) {
  console.error('❌ XATO: .env faylida TELEGRAM_BOT_TOKEN kiritilmagan!');
  process.exit(1);
}

const bot = new Bot(token);

async function start() {
  console.log('🔄 Eski webhook tozalanmoqda...');
  await bot.api.deleteWebhook({ drop_pending_updates: true });

  setupBotHandlers(bot);

  console.log('--------------------------------------------------');
  console.log('🚀 BOT ISHGA TUSHDI! Telegramda /start bosing.');
  console.log('👑 Loyiha egasi: @temurbekbahramov1');
  console.log('--------------------------------------------------');

  bot.start({
    onStart: (botInfo) => {
      console.log(`🤖 Bot nomi: @${botInfo.username}`);
    }
  });
}

start().catch(console.error);
