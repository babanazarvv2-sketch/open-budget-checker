import { NextRequest, NextResponse } from 'next/server';
import { Bot } from 'grammy';
import { setupBotHandlers } from '@/lib/bot/handlers';

const bot = process.env.TELEGRAM_BOT_TOKEN ? new Bot(process.env.TELEGRAM_BOT_TOKEN) : null;
if (bot) {
  setupBotHandlers(bot);
}

export async function POST(req: NextRequest) {
  try {
    if (!bot) {
      return NextResponse.json(
        { error: 'TELEGRAM_BOT_TOKEN sozlanmagan' },
        { status: 500 }
      );
    }

    if (!bot) {
      return NextResponse.json(
        { error: 'TELEGRAM_BOT_TOKEN sozlanmagan' },
        { status: 500 }
      );
    }

    const update = await req.json();
    await bot.handleUpdate(update);
    return NextResponse.json({ ok: true });
  } catch {
    return NextResponse.json({ error: 'Webhook error' }, { status: 500 });
  }
}
