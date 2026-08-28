import { NextRequest, NextResponse } from 'next/server';
import { Bot } from 'grammy';
import { setupBotHandlers } from '@/lib/bot/handlers';

const bot = new Bot(process.env.TELEGRAM_BOT_TOKEN || '');
setupBotHandlers(bot);

export async function POST(req: NextRequest) {
  try {
    const update = await req.json();
    await bot.handleUpdate(update);
    return NextResponse.json({ ok: true });
  } catch {
    return NextResponse.json({ error: 'Webhook error' }, { status: 500 });
  }
}
