import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/db';
import { verifyAdminSession } from '@/lib/auth';
import { Bot } from 'grammy';

const bot = new Bot(process.env.TELEGRAM_BOT_TOKEN || '');

export async function PATCH(req: NextRequest, { params }: { params: { id: string } }) {
  const session = await verifyAdminSession();
  if (!session) return NextResponse.json({ error: 'Ruxsat yo‘q' }, { status: 401 });

  const { id } = params;
  const body = await req.json();
  const { action, reason, note, dmMessage } = body;

  const current = await prisma.submission.findUnique({ where: { id }, include: { user: true } });
  if (!current) return NextResponse.json({ error: 'Ariza topilmadi' }, { status: 404 });

  if (action === 'SAVE_NOTE') {
    const updated = await prisma.submission.update({
      where: { id },
      data: { adminNote: note },
      include: { user: true }
    });
    return NextResponse.json({ success: true, submission: updated });
  }

  if (action === 'TOGGLE_REWARD') {
    const updated = await prisma.submission.update({
      where: { id },
      data: { rewardPaid: !current.rewardPaid },
      include: { user: true }
    });
    return NextResponse.json({ success: true, submission: updated });
  }

  if (action === 'TOGGLE_BLOCK') {
    await prisma.user.update({
      where: { id: current.userId },
      data: { isBlocked: !current.user.isBlocked }
    });
    const updated = await prisma.submission.findUnique({ where: { id }, include: { user: true } });
    return NextResponse.json({ success: true, submission: updated });
  }

  if (action === 'SEND_DM') {
    try {
      await bot.api.sendMessage(current.user.telegramId, dmMessage);
      return NextResponse.json({ success: true });
    } catch {
      return NextResponse.json({ error: 'Xabar yetkazilmadi' }, { status: 500 });
    }
  }

  const newStatus = action === 'APPROVE' ? 'APPROVED' : 'REJECTED';
  const submission = await prisma.submission.update({
    where: { id },
    data: { status: newStatus },
    include: { user: true }
  });

  try {
    if (process.env.TELEGRAM_BOT_TOKEN) {
      if (newStatus === 'APPROVED') {
        await bot.api.sendMessage(
          submission.user.telegramId,
          '✅ *Ovozingiz muvaffaqiyatli tasdiqlandi!*\\n\\nTashabbusimizni qo‘llab-quvvatlaganingiz uchun minnatdormiz! 🎉',
          { parse_mode: 'Markdown' }
        );
      } else {
        const reasonText = reason ? `\\n\\n📋 *Sababi:* ${reason}` : '';
        await bot.api.sendMessage(
          submission.user.telegramId,
          `❌ *Arizangiz rad etildi.*${reasonText}\\n\\nIltimos, qaytadan to‘g‘ri ma'lumotlarni yuboring (/start).`,
          { parse_mode: 'Markdown' }
        );
      }
    }
  } catch (err) {
    console.error('Notification error:', err);
  }

  return NextResponse.json({ success: true, submission });
}
