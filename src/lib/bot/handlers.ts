import { Bot, InlineKeyboard, Keyboard } from 'grammy';
import { prisma } from '../db';
import { storageProvider } from '../storage';
import { getActiveVoteUrl, setActiveVoteUrl } from '../settings';

const OWNER_USERNAME = 'temurbekbahramov1';

function parseUzPhone(input: string): string | null {
  const cleaned = input.replace(/[\s\-\(\)\+]/g, '');
  if (/^\d{9}$/.test(cleaned)) {
    return '+998' + cleaned;
  }
  if (/^998\d{9}$/.test(cleaned)) {
    return '+' + cleaned;
  }
  return null;
}

async function processPhoneNumber(ctx: any, telegramId: string, phone: string, username: string | null) {
  const user = await prisma.user.upsert({
    where: { telegramId },
    update: { phone, username },
    create: { telegramId, phone, username }
  });

  if (user.isBlocked) {
    await ctx.reply('⛔ Siz tizimda bloklangansiz.');
    return;
  }

  await prisma.submission.create({
    data: { userId: user.id, status: 'PHONE_RECEIVED' }
  });

  const currentUrl = await getActiveVoteUrl();
  const voteButton = new InlineKeyboard().url('🗳 OVOZ BERISH SAHIFASIGA O‘TISH', currentUrl);

  await ctx.reply('📱 Telefon raqamingiz qabul qilindi: ' + phone, {
    reply_markup: { remove_keyboard: true }
  });

  await ctx.reply(
    '🌐 Pastdagi tugma orqali Open Budget sahifasiga o‘tib ovoz bering:\n\n👉 ' + currentUrl +
    '\n\n🔢 *Saytda telefoningizga kelgan SMS kodni kiritib bo‘lgach, o‘sha SMS kodni shu yerga xabar qilib yozing:*',
    { reply_markup: voteButton, parse_mode: 'Markdown' }
  );
}

export function setupBotHandlers(bot: Bot) {
  bot.command('setlink', async (ctx) => {
    const sender = ctx.from?.username?.toLowerCase();
    if (sender !== OWNER_USERNAME) {
      return ctx.reply('⛔ Faqat @temurbekbahramov1 loyiha havolasini o‘zgartira oladi.');
    }
    const text = ctx.message?.text || '';
    const parts = text.split(' ');
    if (parts.length < 2 || !parts[1].startsWith('http')) {
      return ctx.reply('⚠️ Format: /setlink https://new.openbudget.uz/...');
    }
    const newUrl = parts[1].trim();
    await setActiveVoteUrl(newUrl);
    await ctx.reply('✅ Yangi havola o‘rnatildi:\n' + newUrl);
  });

  bot.command('start', async (ctx) => {
    const telegramId = ctx.from?.id.toString();
    if (!telegramId) return;

    await prisma.user.upsert({
      where: { telegramId },
      update: { username: ctx.from?.username || null },
      create: { telegramId, username: ctx.from?.username || null }
    });

    const contactKeyboard = new Keyboard().requestContact('📱 Telefon raqamni yuborish').resized().oneTime();
    await ctx.reply(
      'Assalomu alaykum! 👋\n\nOpen Budget tashabbusimizga ovoz berish uchun telefon raqamingizni pastdagi tugma orqali yuboring yoki qo‘lda yozing (masalan: 973103333):',
      { reply_markup: contactKeyboard }
    );
  });

  bot.on(':contact', async (ctx) => {
    const telegramId = ctx.from?.id.toString();
    const contact = ctx.message?.contact;
    if (!telegramId || !contact) return;

    const phone = contact.phone_number.startsWith('+') ? contact.phone_number : '+' + contact.phone_number;
    await processPhoneNumber(ctx, telegramId, phone, ctx.from?.username || null);
  });

  bot.on(':text', async (ctx) => {
    const text = ctx.message?.text?.trim();
    if (!text) return;
    if (text.startsWith('/')) return;

    const telegramId = ctx.from?.id.toString();
    if (!telegramId) return;

    const username = ctx.from?.username || null;
    const detectedPhone = parseUzPhone(text);

    let user = await prisma.user.findUnique({ where: { telegramId } });
    if (!user) {
      user = await prisma.user.create({ data: { telegramId, username } });
    }

    if (user.isBlocked) {
      return ctx.reply('⛔ Siz tizimda bloklangansiz.');
    }

    if (detectedPhone) {
      await processPhoneNumber(ctx, telegramId, detectedPhone, username);
      return;
    }

    const submission = await prisma.submission.findFirst({
      where: { userId: user.id, status: { in: ['PHONE_RECEIVED', 'CODE_RECEIVED', 'REJECTED'] } },
      orderBy: { createdAt: 'desc' }
    });

    if (!submission) {
      return ctx.reply('Iltimos, avval telefon raqamingizni yuboring (masalan: 973103333) yoki /start buyrug‘ini bosing.');
    }

    await prisma.submission.update({
      where: { id: submission.id },
      data: { voteCode: text, status: 'CODE_RECEIVED' }
    });

    await ctx.reply(
      '✅ Ovoz kodi qabul qilindi: *' + text + '*\n\n' +
      '📸 Endi 1-screenshotni yuboring (Saytda kod kiritilgan holatdagi rasm):',
      { parse_mode: 'Markdown' }
    );
  });

  bot.on(':photo', async (ctx) => {
    const telegramId = ctx.from?.id.toString();
    if (!telegramId) return;

    const user = await prisma.user.findUnique({ where: { telegramId } });
    if (!user) return ctx.reply('Iltimos, avval /start buyrug‘ini bosing.');

    if (user.isBlocked) {
      return ctx.reply('⛔ Siz tizimda bloklangansiz.');
    }

    const submission = await prisma.submission.findFirst({
      where: { userId: user.id, status: { in: ['PHONE_RECEIVED', 'CODE_RECEIVED', 'SCREENSHOT_CODE_RECEIVED', 'REJECTED'] } },
      orderBy: { createdAt: 'desc' }
    });

    if (!submission) return ctx.reply('Yangi ariza uchun /start bosing.');

    const photos = ctx.message?.photo;
    if (!photos || photos.length === 0) return;
    const bestPhoto = photos[photos.length - 1];
    const file = await ctx.api.getFile(bestPhoto.file_id);

    const fileUrl = 'https://api.telegram.org/file/bot' + process.env.TELEGRAM_BOT_TOKEN + '/' + file.file_path;
    const response = await fetch(fileUrl);
    const buffer = Buffer.from(await response.arrayBuffer());
    const savedFileName = await storageProvider.uploadFile(buffer, `${Date.now()}.jpg`, 'image/jpeg');

    if (!submission.screenshotCode || submission.status === 'CODE_RECEIVED' || submission.status === 'PHONE_RECEIVED' || submission.status === 'REJECTED') {
      await prisma.submission.update({
        where: { id: submission.id },
        data: { screenshotCode: savedFileName, status: 'SCREENSHOT_CODE_RECEIVED' }
      });
      await ctx.reply('✅ 1-screenshot qabul qilindi.\n\n📸 Endi 2-screenshotni yuboring (Ovoz tasdiqlangan yakuniy holat):');
    } else if (submission.status === 'SCREENSHOT_CODE_RECEIVED') {
      await prisma.submission.update({
        where: { id: submission.id },
        data: { screenshotConfirm: savedFileName, status: 'SCREENSHOT_CONFIRM_RECEIVED' }
      });
      await ctx.reply('✅ Barcha ma\'lumotlar va ovoz muvaffaqiyatli qabul qilindi!\n⏳ @temurbekbahramov1 tomonidan tekshiriladi.');
    }
  });

  bot.on('message', async (ctx) => {
    if (!ctx.message?.photo && !ctx.message?.contact && !ctx.message?.text?.startsWith('/')) {
      await ctx.reply('Iltimos, telefon raqam, SMS kod yoki screenshot yuboring.');
    }
  });
}
