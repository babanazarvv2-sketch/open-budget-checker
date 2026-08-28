import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/db';
import { verifyAdminSession } from '@/lib/auth';
import { Bot } from 'grammy';



export async function POST(req: NextRequest) {
  const token = process.env.TELEGRAM_BOT_TOKEN;
  if (!token) {
    return NextResponse.json(
      { error: 'TELEGRAM_BOT_TOKEN sozlanmagan' },
      { status: 500 }
    );
  }

  const bot = new Bot(token);
  const session = await verifyAdminSession();
  if (!session) return NextResponse.json({ error: 'Ruxsat yo‘q' }, { status: 401 });

  const { message, target } = await req.json();
  if (!message) return NextResponse.json({ error: 'Xabar matni kiritilmadi' }, { status: 400 });

  let users = [];
  if (target === 'APPROVED') {
    const submissions = await prisma.submission.findMany({
      where: { status: 'APPROVED' },
      include: { user: true }
    });
    users = submissions.map((s) => s.user);
  } else {
    users = await prisma.user.findMany();
  }

  const uniqueUsers = Array.from(new Map(users.map((u) => [u.telegramId, u])).values());

  let successCount = 0;
  for (const u of uniqueUsers) {
    try {
      await bot.api.sendMessage(u.telegramId, message);
      successCount++;
    } catch {}
  }

  return NextResponse.json({ success: true, count: successCount });
}
