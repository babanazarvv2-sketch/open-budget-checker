cat << 'EOF' > code.sh
#!/bin/bash
set -e

echo "🚀 Open Budget Full Enterprise Tizimi 0 dan o'rnatilmoqda..."

# 1. Papkalar strukturasini yaratish
mkdir -p prisma public/uploads scripts
mkdir -p src/lib/bot src/lib/storage
mkdir -p src/app/admin/login
mkdir -p src/app/api/admin/auth
mkdir -p src/app/api/admin/broadcast
mkdir -p src/app/api/admin/check-vote
mkdir -p src/app/api/admin/settings
mkdir -p src/app/api/admin/submissions/'[id]'
mkdir -p src/app/api/bot/webhook
mkdir -p src/app/api/uploads/'[...path]'

# 2. package.json
cat << 'FILEEOF' > package.json
{
  "name": "openbudget-checker",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "bot": "tsx bot.ts"
  },
  "dependencies": {
    "@prisma/client": "^6.19.0",
    "dotenv": "^16.4.5",
    "grammy": "^1.35.0",
    "jose": "^5.9.6",
    "next": "14.2.23",
    "react": "^18.3.1",
    "react-dom": "^18.3.1"
  },
  "devDependencies": {
    "@types/node": "^20",
    "@types/react": "^18",
    "@types/react-dom": "^18",
    "autoprefixer": "^10.4.20",
    "postcss": "^8.4.49",
    "prisma": "^6.19.0",
    "tailwindcss": "^3.4.17",
    "tsx": "^4.19.2",
    "typescript": "^5"
  }
}
FILEEOF

# 3. tsconfig.json
cat << 'FILEEOF' > tsconfig.json
{
  "compilerOptions": {
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
FILEEOF

# 4. tailwind & postcss
cat << 'FILEEOF' > tailwind.config.ts
import type { Config } from "tailwindcss";
const config: Config = {
  content: ["./src/**/*.{js,ts,jsx,tsx,mdx}"],
  theme: { extend: {} },
  plugins: [],
};
export default config;
FILEEOF

cat << 'FILEEOF' > postcss.config.js
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
FILEEOF

# 5. .env
cat << 'FILEEOF' > .env
DATABASE_URL="file:./dev.db"
TELEGRAM_BOT_TOKEN="8858160486:AAEYr2SEMLkJCL7vm0oj51lLkkE-Xz4znSU"

ADMIN_USERNAME="temurbekbahramov1"
ADMIN_PASSWORD="temurbek2026"
ADMIN_SESSION_SECRET="temurbekbahramov1_super_secret_jwt_key_2026_length_32"

STORAGE_PATH="./public/uploads"
NEXT_PUBLIC_APP_URL="http://localhost:3000"
FILEEOF

# 6. prisma/schema.prisma
cat << 'FILEEOF' > prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "sqlite"
  url      = env("DATABASE_URL")
}

model User {
  id          String       @id @default(cuid())
  telegramId  String       @unique
  username    String?
  phone       String?
  isBlocked   Boolean      @default(false)
  submissions Submission[]
  createdAt   DateTime     @default(now())
  updatedAt   DateTime     @updatedAt
}

model Submission {
  id                String   @id @default(cuid())
  userId            String
  user              User     @relation(fields: [userId], references: [id], onDelete: Cascade)
  voteCode          String?  // Ovoz SMS kodi
  adminNote         String?  // Admin izohi
  rewardPaid        Boolean  @default(false) // Mukofot to'langanligi
  status            String   // PHONE_RECEIVED, CODE_RECEIVED, SCREENSHOT_CODE_RECEIVED, SCREENSHOT_CONFIRM_RECEIVED, APPROVED, REJECTED
  screenshotCode    String?  // 1-screenshot (Kod kiritilgan holat)
  screenshotConfirm String?  // 2-screenshot (Tasdiqlash holati)
  createdAt         DateTime @default(now())
  updatedAt         DateTime @updatedAt

  @@index([userId])
  @@index([status])
}

model Setting {
  id        String   @id @default(cuid())
  key       String   @unique
  value     String
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}
FILEEOF

# 7. src/lib/db.ts
cat << 'FILEEOF' > src/lib/db.ts
import { PrismaClient } from '@prisma/client';

const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined;
};

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: process.env.NODE_ENV === 'development' ? ['error', 'warn'] : ['error']
  });

if (process.env.NODE_ENV !== 'production') {
  globalForPrisma.prisma = prisma;
}
FILEEOF

# 8. src/lib/settings.ts
cat << 'FILEEOF' > src/lib/settings.ts
import { prisma } from './db';

const DEFAULT_URL = 'https://new.openbudget.uz/uz/initiative-budget/active-initiatives/55/be62aab0-3a4f-41a9-b59a-46e2022c710b';
let cachedUrl = DEFAULT_URL;

export async function getActiveVoteUrl(): Promise<string> {
  try {
    const setting = await prisma.setting.findUnique({
      where: { key: 'VOTE_URL' }
    });
    if (setting?.value) {
      cachedUrl = setting.value;
    }
  } catch {
    // Default fallback
  }
  return cachedUrl;
}

export async function setActiveVoteUrl(newUrl: string): Promise<string> {
  cachedUrl = newUrl.trim();
  try {
    await prisma.setting.upsert({
      where: { key: 'VOTE_URL' },
      update: { value: cachedUrl },
      create: { key: 'VOTE_URL', value: cachedUrl }
    });
  } catch (e) {
    console.error('Error saving URL setting:', e);
  }
  return cachedUrl;
}
FILEEOF

# 9. src/lib/auth.ts
cat << 'FILEEOF' > src/lib/auth.ts
import { SignJWT, jwtVerify } from 'jose';
import { cookies } from 'next/headers';

const SECRET_KEY = new TextEncoder().encode(
  process.env.ADMIN_SESSION_SECRET || 'fallback-secret-key-must-be-32-chars-long!'
);

export async function signAdminSession(username: string) {
  return new SignJWT({ username, role: 'OWNER' })
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime('24h')
    .sign(SECRET_KEY);
}

export async function verifyAdminSession() {
  const cookieStore = cookies();
  const token = cookieStore.get('admin_token')?.value;
  if (!token) return null;

  try {
    const { payload } = await jwtVerify(token, SECRET_KEY);
    return payload;
  } catch {
    return null;
  }
}
FILEEOF

# 10. src/lib/storage
cat << 'FILEEOF' > src/lib/storage/types.ts
export interface IStorageProvider {
  uploadFile(buffer: Buffer, originalFilename: string, mimeType: string): Promise<string>;
  getFileUrl(filePath: string): string;
}
FILEEOF

cat << 'FILEEOF' > src/lib/storage/local.ts
import fs from 'fs/promises';
import path from 'path';
import crypto from 'crypto';
import { IStorageProvider } from './types';

export class LocalStorageProvider implements IStorageProvider {
  private uploadDir: string;

  constructor() {
    this.uploadDir = process.env.STORAGE_PATH || path.join(process.cwd(), 'public', 'uploads');
  }

  async uploadFile(buffer: Buffer, originalFilename: string, _mimeType: string): Promise<string> {
    await fs.mkdir(this.uploadDir, { recursive: true });
    const ext = path.extname(originalFilename) || '.jpg';
    const uniqueName = `${Date.now()}-${crypto.randomBytes(6).toString('hex')}${ext}`;
    const fullPath = path.join(this.uploadDir, uniqueName);

    await fs.writeFile(fullPath, buffer);
    return uniqueName;
  }

  getFileUrl(filePath: string): string {
    return `/api/uploads/${filePath}`;
  }
}
FILEEOF

cat << 'FILEEOF' > src/lib/storage/index.ts
import { IStorageProvider } from './types';
import { LocalStorageProvider } from './local';

export const storageProvider: IStorageProvider = new LocalStorageProvider();
FILEEOF

# 11. src/lib/bot/handlers.ts
cat << 'FILEEOF' > src/lib/bot/handlers.ts
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
    const text = ctx.message.text.trim();
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
FILEEOF

# 12. bot.ts
cat << 'FILEEOF' > bot.ts
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
FILEEOF

# 13. API Marshrutlari
cat << 'FILEEOF' > src/app/api/admin/auth/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { signAdminSession } from '@/lib/auth';

const REQUIRED_OWNER = 'temurbekbahramov1';

export async function POST(req: NextRequest) {
  try {
    const { username, password } = await req.json();

    if (username.trim().toLowerCase() !== REQUIRED_OWNER) {
      return NextResponse.json({ error: 'Faqat temurbekbahramov1 kira oladi.' }, { status: 403 });
    }

    const validPassword = process.env.ADMIN_PASSWORD || 'temurbek2026';
    if (password !== validPassword) {
      return NextResponse.json({ error: 'Parol noto‘g‘ri!' }, { status: 401 });
    }

    const token = await signAdminSession(REQUIRED_OWNER);
    const response = NextResponse.json({ success: true, message: 'Xush kelibsiz!' });

    response.cookies.set('admin_token', token, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      path: '/',
      maxAge: 60 * 60 * 24
    });

    return response;
  } catch {
    return NextResponse.json({ error: 'Server xatosi' }, { status: 500 });
  }
}
FILEEOF

cat << 'FILEEOF' > src/app/api/admin/check-vote/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { verifyAdminSession } from '@/lib/auth';
import { getActiveVoteUrl } from '@/lib/settings';

export async function POST(req: NextRequest) {
  const session = await verifyAdminSession();
  if (!session) return NextResponse.json({ error: 'Ruxsat yo‘q' }, { status: 401 });

  const { phone } = await req.json();
  if (!phone) {
    return NextResponse.json({ status: 'NOT_FOUND', message: 'Telefon raqam mavjud emas' });
  }

  const cleanPhone = phone.replace(/[^0-9]/g, '');
  const shortPhone = cleanPhone.startsWith('998') ? cleanPhone.slice(3) : cleanPhone;

  const currentUrl = await getActiveVoteUrl();
  const parts = currentUrl.split('/');
  const initiativeId = parts[parts.length - 1] || parts[parts.length - 2];

  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 6000);

    const targetApi = `https://openbudget.uz/api/v1/vote/check?phone=${encodeURIComponent(cleanPhone)}&initiative=${encodeURIComponent(initiativeId)}`;
    const fallbackApi = `https://new.openbudget.uz/api/v1/initiatives/${encodeURIComponent(initiativeId)}/votes?search=${encodeURIComponent(shortPhone)}`;

    let response: any = null;
    try {
      response = await fetch(targetApi, {
        signal: controller.signal,
        headers: { 'User-Agent': 'Mozilla/5.0 (OpenBudget-Checker-Bot)' }
      });
    } catch {
      response = await fetch(fallbackApi, {
        signal: controller.signal,
        headers: { 'User-Agent': 'Mozilla/5.0 (OpenBudget-Checker-Bot)' }
      });
    }
    clearTimeout(timeoutId);

    if (!response || !response.ok) {
      if (response && response.status === 404) {
        return NextResponse.json({ status: 'NOT_FOUND', message: 'Ovoz o‘tmagan' });
      }
      return NextResponse.json({ status: 'SITE_DOWN', message: 'Sayt vaqtinchalik ishlamayapti' });
    }

    const data = await response.json();

    if (data && (data.voted === true || data.hasVoted === true || (Array.isArray(data.items) && data.items.length > 0) || (Array.isArray(data) && data.length > 0))) {
      return NextResponse.json({ status: 'FOUND', message: 'Ovoz o‘tgan' });
    } else {
      return NextResponse.json({ status: 'NOT_FOUND', message: 'Ovoz o‘tmagan' });
    }
  } catch {
    return NextResponse.json({ status: 'SITE_DOWN', message: 'Sayt vaqtinchalik ishlamayapti' });
  }
}
FILEEOF

cat << 'FILEEOF' > src/app/api/admin/broadcast/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/db';
import { verifyAdminSession } from '@/lib/auth';
import { Bot } from 'grammy';

const bot = new Bot(process.env.TELEGRAM_BOT_TOKEN || '');

export async function POST(req: NextRequest) {
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
FILEEOF

cat << 'FILEEOF' > src/app/api/admin/settings/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { verifyAdminSession } from '@/lib/auth';
import { getActiveVoteUrl, setActiveVoteUrl } from '@/lib/settings';

export async function GET() {
  const url = await getActiveVoteUrl();
  return NextResponse.json({ url });
}

export async function POST(req: NextRequest) {
  const session = await verifyAdminSession();
  if (!session) return NextResponse.json({ error: 'Ruxsatsiz kirish' }, { status: 401 });

  const { url } = await req.json();
  if (!url || !url.startsWith('http')) {
    return NextResponse.json({ error: 'Noto‘g‘ri havola formati' }, { status: 400 });
  }

  const updatedUrl = await setActiveVoteUrl(url);
  return NextResponse.json({ success: true, url: updatedUrl });
}
FILEEOF

cat << 'FILEEOF' > src/app/api/admin/submissions/route.ts
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/db';
import { verifyAdminSession } from '@/lib/auth';

export async function GET() {
  const session = await verifyAdminSession();
  if (!session) return NextResponse.json({ error: 'Ruxsat yo‘q' }, { status: 401 });

  const submissions = await prisma.submission.findMany({
    include: { user: true },
    orderBy: { createdAt: 'desc' }
  });

  return NextResponse.json({ submissions });
}
FILEEOF

cat << 'FILEEOF' > src/app/api/admin/submissions/'[id]'/route.ts
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
FILEEOF

cat << 'FILEEOF' > src/app/api/uploads/'[...path]'/route.ts
import { NextRequest, NextResponse } from 'next/server';
import fs from 'fs/promises';
import path from 'path';

export async function GET(_req: NextRequest, { params }: { params: { path: string[] } }) {
  try {
    const filePath = params.path.join('/');
    const uploadDir = process.env.STORAGE_PATH || path.join(process.cwd(), 'public', 'uploads');
    const fullPath = path.join(uploadDir, filePath);

    const file = await fs.readFile(fullPath);
    return new NextResponse(file, {
      headers: {
        'Content-Type': 'image/jpeg',
        'Cache-Control': 'public, max-age=86400'
      }
    });
  } catch {
    return new NextResponse('Rasm topilmadi', { status: 404 });
  }
}
FILEEOF

cat << 'FILEEOF' > src/app/api/bot/webhook/route.ts
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
FILEEOF

# 14. UI Sahifalar
cat << 'FILEEOF' > src/app/globals.css
@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  background-color: #020617;
  color: #f8fafc;
}
FILEEOF

cat << 'FILEEOF' > src/app/layout.tsx
import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Open Budget Ovoz Tizimi',
  description: 'Open Budget Ovoz va Kodlarni Tasdiqlash Tizimi',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="uz">
      <body>{children}</body>
    </html>
  );
}
FILEEOF

cat << 'FILEEOF' > src/app/page.tsx
import Link from 'next/link';

export default function HomePage() {
  return (
    <div className="min-h-screen flex flex-col items-center justify-center p-6 text-center">
      <h1 className="text-3xl md:text-4xl font-extrabold mb-3">Open Budget Ovoz Tizimi</h1>
      <p className="text-slate-400 max-w-md mb-8">
        Telegram bot orqali ovozlar, SMS kodlar va screenshotlarni qabul qilish hamda tasdiqlash paneli.
      </p>
      <Link
        href="/admin"
        className="px-6 py-3 bg-blue-600 hover:bg-blue-500 text-white rounded-xl font-semibold transition shadow-lg shadow-blue-500/20"
      >
        Admin Panelga Kirish
      </Link>
    </div>
  );
}
FILEEOF

cat << 'FILEEOF' > src/app/admin/login/page.tsx
'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';

export default function AdminLoginPage() {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const router = useRouter();

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      const res = await fetch('/api/admin/auth', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password })
      });

      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Xatolik yuz berdi');

      router.push('/admin');
      router.refresh();
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-slate-950 flex items-center justify-center p-4">
      <div className="bg-slate-900 border border-slate-800 p-8 rounded-2xl w-full max-w-md shadow-2xl">
        <h1 className="text-2xl font-bold text-white mb-2 text-center">Open Budget Admin</h1>
        <p className="text-sm text-slate-400 mb-6 text-center">Boshqaruv paneli (@temurbekbahramov1)</p>

        {error && (
          <div className="bg-rose-500/10 border border-rose-500/30 text-rose-400 p-3 rounded-lg text-sm mb-4">
            {error}
          </div>
        )}

        <form onSubmit={handleLogin} className="space-y-4">
          <div>
            <label className="block text-xs font-semibold text-slate-300 mb-1">Foydalanuvchi nomi</label>
            <input
              type="text"
              required
              placeholder="temurbekbahramov1"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              className="w-full bg-slate-950 border border-slate-700 px-4 py-2.5 rounded-lg text-white focus:outline-none focus:border-blue-500 text-sm"
            />
          </div>

          <div>
            <label className="block text-xs font-semibold text-slate-300 mb-1">Parol</label>
            <input
              type="password"
              required
              placeholder="••••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full bg-slate-950 border border-slate-700 px-4 py-2.5 rounded-lg text-white focus:outline-none focus:border-blue-500 text-sm"
            />
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-blue-600 hover:bg-blue-500 text-white font-medium py-2.5 rounded-lg text-sm transition disabled:opacity-50"
          >
            {loading ? 'Kirilmoqda...' : 'Kirish'}
          </button>
        </form>
      </div>
    </div>
  );
}
FILEEOF

cat << 'FILEEOF' > src/app/admin/page.tsx
import { redirect } from 'next/navigation';
import { prisma } from '@/lib/db';
import { verifyAdminSession } from '@/lib/auth';
import { getActiveVoteUrl } from '@/lib/settings';
import AdminSubmissionsClient from './AdminSubmissionsClient';

export const dynamic = 'force-dynamic';

export default async function AdminPage() {
  const session = await verifyAdminSession();
  if (!session) {
    redirect('/admin/login');
  }

  const submissions = await prisma.submission.findMany({
    include: { user: true },
    orderBy: { createdAt: 'desc' }
  });

  const activeUrl = await getActiveVoteUrl();

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 p-6 md:p-8">
      <div className="max-w-7xl mx-auto space-y-6">
        <header className="flex flex-col md:flex-row md:items-center justify-between gap-4 pb-6 border-b border-slate-800">
          <div>
            <h1 className="text-2xl font-bold text-white flex items-center gap-2">
              <span>Open Budget Ovozlar Paneli</span>
              <span className="text-xs bg-blue-500/20 text-blue-400 border border-blue-500/30 px-2.5 py-0.5 rounded-full">
                👑 @temurbekbahramov1
              </span>
            </h1>
            <p className="text-sm text-slate-400">Ovoz SMS kodlari va screenshotlarni tekshirish</p>
          </div>
        </header>

        <AdminSubmissionsClient initialSubmissions={submissions} initialUrl={activeUrl} />
      </div>
    </div>
  );
}
FILEEOF

cat << 'FILEEOF' > src/app/admin/AdminSubmissionsClient.tsx
'use client';

import { useState, useEffect, useRef } from 'react';

export default function AdminSubmissionsClient({
  initialSubmissions,
  initialUrl
}: {
  initialSubmissions: any[];
  initialUrl: string;
}) {
  const [submissions, setSubmissions] = useState(initialSubmissions);
  const [voteUrl, setVoteUrl] = useState(initialUrl);
  const [savingUrl, setSavingUrl] = useState(false);
  const [urlMessage, setUrlMessage] = useState('');
  const [filter, setFilter] = useState('ALL');
  const [dateFilter, setDateFilter] = useState('ALL');
  const [search, setSearch] = useState('');
  const [loadingId, setLoadingId] = useState<string | null>(null);
  const [copyToast, setCopyToast] = useState<string | null>(null);

  const [isLive, setIsLive] = useState(true);
  const [soundEnabled, setSoundEnabled] = useState(true);
  const prevCountRef = useRef(initialSubmissions.length);

  const [checkResults, setCheckResults] = useState<Record<string, { status: 'FOUND' | 'NOT_FOUND' | 'SITE_DOWN'; message: string }>>({});
  const [checkingIds, setCheckingIds] = useState<Record<string, boolean>>({});

  const [previewImage, setPreviewImage] = useState<string | null>(null);
  const [rotation, setRotation] = useState(0);

  const [rejectModalId, setRejectModalId] = useState<string | null>(null);
  const [rejectReason, setRejectReason] = useState("Screenshotdagi ma'lumotlar xato yoki ko'rinmayapti");

  const [dmModalUser, setDmModalUser] = useState<any | null>(null);
  const [dmMessage, setDmMessage] = useState('');
  const [sendingDm, setSendingDm] = useState(false);

  const [noteModalSub, setNoteModalSub] = useState<any | null>(null);
  const [noteText, setNoteText] = useState('');

  const [broadcastOpen, setBroadcastOpen] = useState(false);
  const [broadcastMsg, setBroadcastMsg] = useState('');
  const [broadcastTarget, setBroadcastTarget] = useState('ALL');
  const [broadcasting, setBroadcasting] = useState(false);
  const [broadcastResult, setBroadcastResult] = useState<string | null>(null);

  const playBeep = () => {
    if (!soundEnabled) return;
    try {
      const ctx = new (window.AudioContext || (window as any).webkitAudioContext)();
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(880, ctx.currentTime);
      gain.gain.setValueAtTime(0.15, ctx.currentTime);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start();
      osc.stop(ctx.currentTime + 0.25);
    } catch {}
  };

  useEffect(() => {
    if (!isLive) return;
    const interval = setInterval(async () => {
      try {
        const res = await fetch('/api/admin/submissions');
        if (res.ok) {
          const data = await res.json();
          if (data.submissions.length > prevCountRef.current) {
            playBeep();
            setCopyToast(`🔔 ${data.submissions.length - prevCountRef.current} ta yangi ovoz keldi!`);
            setTimeout(() => setCopyToast(null), 3000);
          }
          prevCountRef.current = data.submissions.length;
          setSubmissions(data.submissions);
        }
      } catch {}
    }, 5000);
    return () => clearInterval(interval);
  }, [isLive, soundEnabled]);

  const handleCheckOnline = async (subId: string, phone: string | null) => {
    if (!phone) {
      setCheckResults((prev) => ({ ...prev, [subId]: { status: 'NOT_FOUND', message: 'Raqam yo‘q' } }));
      return;
    }

    setCheckingIds((prev) => ({ ...prev, [subId]: true }));
    try {
      const res = await fetch('/api/admin/check-vote', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone })
      });
      const data = await res.json();
      setCheckResults((prev) => ({
        ...prev,
        [subId]: { status: data.status, message: data.message }
      }));
    } catch {
      setCheckResults((prev) => ({
        ...prev,
        [subId]: { status: 'SITE_DOWN', message: 'Sayt vaqtinchalik ishlamayapti' }
      }));
    } finally {
      setCheckingIds((prev) => ({ ...prev, [subId]: false }));
    }
  };

  const copyToClipboard = (text: string, label: string) => {
    navigator.clipboard.writeText(text);
    setCopyToast(`${label} nusxalandi: ${text}`);
    setTimeout(() => setCopyToast(null), 2500);
  };

  const total = submissions.length;
  const approved = submissions.filter((s) => s.status === 'APPROVED').length;
  const rejected = submissions.filter((s) => s.status === 'REJECTED').length;
  const pending = submissions.filter((s) => s.status === 'SCREENSHOT_CONFIRM_RECEIVED' || s.status === 'SCREENSHOT_CODE_RECEIVED').length;
  const totalRewardsPaid = submissions.filter((s) => s.rewardPaid).length;

  const now = new Date();
  const todayStr = now.toDateString();
  const todayCount = submissions.filter((s) => new Date(s.createdAt).toDateString() === todayStr).length;
  const todayApproved = submissions.filter((s) => new Date(s.createdAt).toDateString() === todayStr && s.status === 'APPROVED').length;
  const conversionRate = total > 0 ? Math.round((approved / total) * 100) : 0;

  const hoursMap: number[] = new Array(24).fill(0);
  submissions.forEach((s) => {
    const h = new Date(s.createdAt).getHours();
    hoursMap[h]++;
  });
  const maxHourCount = Math.max(...hoursMap, 1);

  const handleAction = async (id: string, action: string, payload: any = {}) => {
    setLoadingId(id);
    try {
      const res = await fetch(`/api/admin/submissions/${id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action, ...payload })
      });
      const data = await res.json();
      if (res.ok && data.submission) {
        setSubmissions((prev) => prev.map((s) => (s.id === id ? data.submission : s)));
      }
    } finally {
      setLoadingId(null);
      setRejectModalId(null);
      setNoteModalSub(null);
    }
  };

  const handleSendDM = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!dmModalUser || !dmMessage) return;
    setSendingDm(true);
    try {
      await handleAction(dmModalUser.submissionId, 'SEND_DM', { dmMessage });
      setCopyToast('✅ Shaxsiy xabar Telegramga yetkazildi!');
      setTimeout(() => setCopyToast(null), 2500);
      setDmModalUser(null);
      setDmMessage('');
    } finally {
      setSendingDm(false);
    }
  };

  const handleUpdateUrl = async (e: React.FormEvent) => {
    e.preventDefault();
    setSavingUrl(true);
    setUrlMessage('');
    try {
      const res = await fetch('/api/admin/settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ url: voteUrl })
      });
      if (res.ok) setUrlMessage('✅ Havola saqlandi!');
      else setUrlMessage('❌ Xato');
    } finally {
      setSavingUrl(false);
    }
  };

  const handleSendBroadcast = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!broadcastMsg) return;
    setBroadcasting(true);
    setBroadcastResult(null);
    try {
      const res = await fetch('/api/admin/broadcast', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: broadcastMsg, target: broadcastTarget })
      });
      const data = await res.json();
      if (res.ok) {
        setBroadcastResult(`✅ ${data.count} ta foydalanuvchiga yuborildi!`);
        setBroadcastMsg('');
      } else {
        setBroadcastResult('❌ Xatolik: ' + data.error);
      }
    } finally {
      setBroadcasting(false);
    }
  };

  const exportToCSV = () => {
    const rows = [
      ['ID', 'Telefon', 'Ovoz Kodi', 'Izoh', 'Mukofot', 'Telegram ID', 'Username', 'Status', 'Sana'],
      ...filtered.map((s) => [
        s.id,
        s.user.phone || '',
        s.voteCode || '',
        s.adminNote || '',
        s.rewardPaid ? 'To‘langan' : 'Yo‘q',
        s.user.telegramId,
        s.user.username || '',
        s.status,
        new Date(s.createdAt).toLocaleString('uz-UZ')
      ])
    ];
    const csvContent = 'data:text/csv;charset=utf-8,' + rows.map((e) => e.join(',')).join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', `openbudget_full_${Date.now()}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const phoneCounts: Record<string, number> = {};
  submissions.forEach((s) => {
    if (s.user.phone) phoneCounts[s.user.phone] = (phoneCounts[s.user.phone] || 0) + 1;
  });

  const filtered = submissions.filter((sub) => {
    const matchesFilter = filter === 'ALL' || sub.status === filter;
    const phone = sub.user?.phone || '';
    const code = sub.voteCode || '';
    const note = sub.adminNote || '';
    const username = sub.user?.username || '';
    const tgId = sub.user?.telegramId || '';
    const matchesSearch =
      phone.includes(search) ||
      code.includes(search) ||
      note.toLowerCase().includes(search.toLowerCase()) ||
      username.toLowerCase().includes(search.toLowerCase()) ||
      tgId.includes(search);

    let matchesDate = true;
    const subDate = new Date(sub.createdAt);
    if (dateFilter === 'TODAY') matchesDate = subDate.toDateString() === todayStr;
    else if (dateFilter === 'WEEK') {
      const weekAgo = new Date();
      weekAgo.setDate(weekAgo.getDate() - 7);
      matchesDate = subDate >= weekAgo;
    }

    return matchesFilter && matchesSearch && matchesDate;
  });

  return (
    <div className="space-y-6 pb-20">
      {copyToast && (
        <div className="fixed bottom-6 right-6 z-50 bg-slate-900 border border-emerald-500/50 text-emerald-400 px-5 py-3 rounded-2xl shadow-2xl font-semibold text-xs flex items-center gap-2">
          {copyToast}
        </div>
      )}

      {/* Control bar */}
      <div className="flex flex-wrap items-center justify-between gap-3 bg-slate-900/80 backdrop-blur border border-slate-800 p-3.5 rounded-2xl">
        <div className="flex items-center gap-3">
          <button
            onClick={() => setIsLive(!isLive)}
            className={`px-3 py-1.5 rounded-xl text-xs font-bold flex items-center gap-2 transition ${
              isLive ? 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/30' : 'bg-slate-800 text-slate-400'
            }`}
          >
            <span className={`w-2 h-2 rounded-full ${isLive ? 'bg-emerald-400 animate-ping' : 'bg-slate-500'}`} />
            {isLive ? 'JONLI MONITORING: YONIQ' : 'JONLI REJIM: O‘CHIQ'}
          </button>

          <button
            onClick={() => setSoundEnabled(!soundEnabled)}
            className={`px-3 py-1.5 rounded-xl text-xs font-semibold border transition ${
              soundEnabled ? 'bg-indigo-500/20 text-indigo-300 border-indigo-500/30' : 'bg-slate-800 text-slate-400 border-slate-700'
            }`}
          >
            {soundEnabled ? '🔔 Ovozli Signal: Bor' : '🔕 Ovoz: O‘chiq'}
          </button>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={() => setBroadcastOpen(true)}
            className="px-3.5 py-1.5 bg-purple-600/20 hover:bg-purple-600/30 border border-purple-500/30 text-purple-300 rounded-xl text-xs font-bold transition"
          >
            📢 Ommaviy Xabar (Broadcast)
          </button>
          <button
            onClick={exportToCSV}
            className="px-3.5 py-1.5 bg-slate-800 hover:bg-slate-700 text-slate-200 rounded-xl text-xs font-bold border border-slate-700 transition"
          >
            📥 Excel CSV
          </button>
        </div>
      </div>

      {/* 1. Statistika kartalari */}
      <div className="grid grid-cols-2 lg:grid-cols-6 gap-3">
        <div className="bg-slate-900 border border-slate-800 p-4 rounded-2xl">
          <p className="text-[11px] text-slate-400 font-semibold uppercase">Jami Ovozlar</p>
          <p className="text-2xl font-black text-white mt-1">{total}</p>
          <span className="text-[10px] text-slate-500">Barcha arizalar</span>
        </div>

        <div className="bg-slate-900 border border-slate-800 p-4 rounded-2xl">
          <p className="text-[11px] text-blue-400 font-semibold uppercase">Bugun Kelgan</p>
          <p className="text-2xl font-black text-blue-400 mt-1">{todayCount}</p>
          <span className="text-[10px] text-emerald-400">+{todayApproved} tasdiq</span>
        </div>

        <div className="bg-slate-900 border border-slate-800 p-4 rounded-2xl">
          <p className="text-[11px] text-amber-400 font-semibold uppercase">Kutilayotgan</p>
          <p className="text-2xl font-black text-amber-400 mt-1">{pending}</p>
          <span className="text-[10px] text-amber-500/70">Tekshirishga tayyor</span>
        </div>

        <div className="bg-slate-900 border border-slate-800 p-4 rounded-2xl">
          <p className="text-[11px] text-emerald-400 font-semibold uppercase">Tasdiqlangan</p>
          <p className="text-2xl font-black text-emerald-400 mt-1">{approved}</p>
          <span className="text-[10px] text-emerald-500/70">{conversionRate}% toza ovoz</span>
        </div>

        <div className="bg-slate-900 border border-slate-800 p-4 rounded-2xl">
          <p className="text-[11px] text-rose-400 font-semibold uppercase">Rad etilgan</p>
          <p className="text-2xl font-black text-rose-400 mt-1">{rejected}</p>
          <span className="text-[10px] text-rose-500/70">Xato/Soxta</span>
        </div>

        <div className="bg-slate-900 border border-slate-800 p-4 rounded-2xl col-span-2 lg:col-span-1">
          <p className="text-[11px] text-yellow-400 font-semibold uppercase">Mukofot Berildi</p>
          <p className="text-2xl font-black text-yellow-400 mt-1">{totalRewardsPaid}</p>
          <span className="text-[10px] text-slate-400">To‘lov qilindi</span>
        </div>
      </div>

      {/* 2. Faol havola va soatlar bo'yicha grafik */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div className="bg-slate-900 border border-slate-800 p-4 rounded-2xl space-y-2">
          <div className="flex items-center justify-between">
            <h2 className="text-xs font-bold text-slate-200">🔗 Faol Open Budget Havolasi</h2>
            {urlMessage && <span className="text-xs text-emerald-400">{urlMessage}</span>}
          </div>
          <form onSubmit={handleUpdateUrl} className="flex gap-2">
            <input
              type="text"
              value={voteUrl}
              onChange={(e) => setVoteUrl(e.target.value)}
              className="flex-1 bg-slate-950 border border-slate-700 px-3 py-2 rounded-xl text-xs text-white focus:outline-none focus:border-blue-500"
              placeholder="https://new.openbudget.uz/..."
            />
            <button
              type="submit"
              disabled={savingUrl}
              className="px-4 py-2 bg-blue-600 hover:bg-blue-500 text-white rounded-xl text-xs font-bold transition"
            >
              {savingUrl ? '...' : 'Saqlash'}
            </button>
          </form>
        </div>

        <div className="bg-slate-900 border border-slate-800 p-4 rounded-2xl lg:col-span-2 space-y-2">
          <div className="flex justify-between items-center text-xs">
            <h2 className="font-bold text-slate-200">📊 24 Soatlik Ovozlar Dinamikasi</h2>
            <span className="text-slate-400 text-[10px]">00:00 dan 23:00 gacha</span>
          </div>
          <div className="flex items-end gap-1 h-14 pt-2">
            {hoursMap.map((count, h) => {
              const heightPercent = Math.round((count / maxHourCount) * 100);
              return (
                <div key={h} className="flex-1 flex flex-col items-center gap-1 group relative">
                  <div
                    style={{ height: `${Math.max(heightPercent, 8)}%` }}
                    className={`w-full rounded-t-sm transition ${
                      count > 0 ? 'bg-blue-500 group-hover:bg-blue-400' : 'bg-slate-800'
                    }`}
                  />
                  <span className="text-[8px] text-slate-500 font-mono">{h % 4 === 0 ? h : ''}</span>
                  <div className="absolute -top-7 bg-slate-950 border border-slate-700 text-white text-[9px] px-1.5 py-0.5 rounded opacity-0 group-hover:opacity-100 pointer-events-none whitespace-nowrap z-20">
                    {h}:00 - {count} ta
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>

      {/* 3. Filtrlar va qidiruv */}
      <div className="bg-slate-900 p-4 rounded-2xl border border-slate-800 space-y-3">
        <div className="flex flex-col md:flex-row gap-3 justify-between items-center">
          <input
            type="text"
            placeholder="Qidiruv (telefon, kod, izoh, username)..."
            className="bg-slate-950 border border-slate-800 px-4 py-2 rounded-xl text-xs w-full md:w-80 text-white focus:outline-none focus:border-blue-500"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />

          <div className="flex gap-1.5 w-full md:w-auto overflow-x-auto pb-1 md:pb-0">
            {[
              { key: 'ALL', label: 'Barcha sana' },
              { key: 'TODAY', label: 'Bugun' },
              { key: 'WEEK', label: '7 kun' }
            ].map((d) => (
              <button
                key={d.key}
                onClick={() => setDateFilter(d.key)}
                className={`px-3 py-1.5 rounded-xl text-xs font-semibold transition ${
                  dateFilter === d.key ? 'bg-slate-700 text-white' : 'bg-slate-950 text-slate-400 hover:bg-slate-800'
                }`}
              >
                {d.label}
              </button>
            ))}
          </div>
        </div>

        <div className="flex gap-2 flex-wrap border-t border-slate-800/80 pt-3">
          {[
            { key: 'ALL', label: 'Barchasi', count: total },
            { key: 'SCREENSHOT_CONFIRM_RECEIVED', label: 'Kutilayotgan', count: pending },
            { key: 'APPROVED', label: 'Tasdiqlangan', count: approved },
            { key: 'REJECTED', label: 'Rad etilgan', count: rejected }
          ].map((st) => (
            <button
              key={st.key}
              onClick={() => setFilter(st.key)}
              className={`px-3 py-1.5 rounded-xl text-xs font-medium transition flex items-center gap-1.5 ${
                filter === st.key ? 'bg-blue-600 text-white shadow-lg shadow-blue-500/20' : 'bg-slate-800 text-slate-400 hover:bg-slate-700'
              }`}
            >
              <span>{st.label}</span>
              <span className="text-[10px] bg-slate-950/50 px-1.5 py-0.5 rounded-md">{st.count}</span>
            </button>
          ))}
        </div>
      </div>

      {/* 4. Arizalar ro'yxati */}
      <div className="space-y-3">
        <div className="flex items-center justify-between px-2 text-xs text-slate-400">
          <p>Topildi: <span className="text-white font-bold">{filtered.length}</span> ta</p>
        </div>

        {filtered.length === 0 ? (
          <div className="text-center py-20 bg-slate-900/40 rounded-3xl border border-slate-900 text-slate-500 text-sm">
            Hech qanday ariza topilmadi.
          </div>
        ) : (
          filtered.map((sub) => {
            const isDuplicate = sub.user.phone && phoneCounts[sub.user.phone] > 1;
            const checkRes = checkResults[sub.id];
            const isChecking = checkingIds[sub.id];

            return (
              <div
                key={sub.id}
                className={`bg-slate-900 border rounded-2xl p-5 flex flex-col lg:flex-row gap-5 items-start justify-between transition ${
                  sub.user.isBlocked ? 'border-rose-900/50 bg-rose-950/10 opacity-70' : 'border-slate-800 hover:border-slate-700'
                }`}
              >
                {/* Ma'lumotlar qismi */}
                <div className="space-y-2.5">
                  <div className="flex items-center gap-2.5 flex-wrap">
                    <span
                      onClick={() => sub.user.phone && copyToClipboard(sub.user.phone, 'Telefon')}
                      className="text-base font-bold text-white tracking-wide cursor-pointer hover:text-blue-400 transition flex items-center gap-1"
                    >
                      {sub.user.phone || 'Raqam yo‘q'} 📋
                    </span>

                    <span
                      className={`px-2.5 py-0.5 rounded-full text-[11px] font-bold ${
                        sub.status === 'APPROVED'
                          ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20'
                          : sub.status === 'REJECTED'
                          ? 'bg-rose-500/10 text-rose-400 border border-rose-500/20'
                          : 'bg-amber-500/10 text-amber-400 border border-amber-500/20'
                      }`}
                    >
                      {sub.status === 'APPROVED' ? 'Tasdiqlangan' : sub.status === 'REJECTED' ? 'Rad etilgan' : 'Kutilmoqda'}
                    </span>

                    {isDuplicate && (
                      <span className="bg-orange-500/20 text-orange-400 border border-orange-500/30 text-[10px] font-bold px-2 py-0.5 rounded-full">
                        ⚠️ Dublikat ({phoneCounts[sub.user.phone]} ta)
                      </span>
                    )}

                    {sub.user.isBlocked && (
                      <span className="bg-rose-600 text-white text-[10px] font-bold px-2 py-0.5 rounded-full">
                        🚫 BLOKLANGAN
                      </span>
                    )}
                  </div>

                  {/* Ovoz SMS Kodi */}
                  <div className="flex items-center gap-2">
                    <span className="text-xs text-slate-400 font-medium">Ovoz SMS Kodi:</span>
                    <span
                      onClick={() => sub.voteCode && copyToClipboard(sub.voteCode, 'Kod')}
                      className="px-2.5 py-0.5 bg-blue-500/15 border border-blue-500/30 text-blue-300 font-mono font-bold text-xs rounded-md cursor-pointer hover:bg-blue-500/25 transition"
                    >
                      {sub.voteCode || 'Kiritilmagan'} 📋
                    </span>
                  </div>

                  {/* Telegram username va DM */}
                  <div className="flex items-center gap-3 text-xs text-slate-400 flex-wrap">
                    <span>TG ID: {sub.user.telegramId}</span>
                    {sub.user.username && (
                      <a href={`https://t.me/${sub.user.username}`} target="_blank" rel="noreferrer" className="text-blue-400 hover:underline">
                        @{sub.user.username} ↗
                      </a>
                    )}
                    <button
                      onClick={() => {
                        setDmModalUser({ submissionId: sub.id, telegramId: sub.user.telegramId, username: sub.user.username });
                        setDmMessage('');
                      }}
                      className="text-indigo-400 hover:underline text-[11px] flex items-center gap-1 font-semibold"
                    >
                      ✉️ Telegramda Xabar
                    </button>
                  </div>

                  {/* Mukofot va Izoh */}
                  <div className="flex items-center gap-2 pt-1">
                    <button
                      onClick={() => handleAction(sub.id, 'TOGGLE_REWARD')}
                      className={`px-2.5 py-1 rounded-lg text-[11px] font-bold border transition flex items-center gap-1 ${
                        sub.rewardPaid
                          ? 'bg-emerald-500/20 text-emerald-300 border-emerald-500/30'
                          : 'bg-slate-800 text-slate-400 border-slate-700 hover:bg-slate-700'
                      }`}
                    >
                      {sub.rewardPaid ? '💰 Mukofot Berildi ✅' : '⏳ Mukofot Berilmadi'}
                    </button>

                    <button
                      onClick={() => {
                        setNoteModalSub(sub);
                        setNoteText(sub.adminNote || '');
                      }}
                      className="px-2.5 py-1 bg-slate-800 hover:bg-slate-700 text-slate-300 rounded-lg text-[11px] font-semibold border border-slate-700 transition"
                    >
                      📝 {sub.adminNote ? `Izoh: "${sub.adminNote}"` : '+ Izoh'}
                    </button>

                    <button
                      onClick={() => handleAction(sub.id, 'TOGGLE_BLOCK')}
                      className="px-2.5 py-1 text-slate-500 hover:text-rose-400 text-[11px] transition"
                    >
                      {sub.user.isBlocked ? '🔓 Ochish' : '🚫 Bloklash'}
                    </button>
                  </div>

                  <p className="text-[11px] text-slate-500">
                    🕒 {new Date(sub.createdAt).toLocaleString('uz-UZ')}
                  </p>
                </div>

                {/* 2 Ta Screenshot */}
                <div className="flex gap-4">
                  {sub.screenshotCode ? (
                    <div
                      className="text-center group cursor-pointer"
                      onClick={() => {
                        setPreviewImage(`/api/uploads/${sub.screenshotCode}`);
                        setRotation(0);
                      }}
                    >
                      <p className="text-[10px] text-slate-400 mb-1 font-semibold group-hover:text-blue-400">1. Kod kiritilgan 🔍</p>
                      <img
                        src={`/api/uploads/${sub.screenshotCode}`}
                        alt="1-screenshot"
                        className="w-20 h-20 object-cover rounded-xl border border-slate-700 group-hover:scale-105 transition shadow-md"
                      />
                    </div>
                  ) : (
                    <div className="w-20 h-20 bg-slate-950 rounded-xl flex items-center justify-center text-[10px] text-slate-600 border border-dashed border-slate-800">
                      1-rasm yo‘q
                    </div>
                  )}

                  {sub.screenshotConfirm ? (
                    <div
                      className="text-center group cursor-pointer"
                      onClick={() => {
                        setPreviewImage(`/api/uploads/${sub.screenshotConfirm}`);
                        setRotation(0);
                      }}
                    >
                      <p className="text-[10px] text-slate-400 mb-1 font-semibold group-hover:text-blue-400">2. Tasdiqlangan 🔍</p>
                      <img
                        src={`/api/uploads/${sub.screenshotConfirm}`}
                        alt="2-screenshot"
                        className="w-20 h-20 object-cover rounded-xl border border-slate-700 group-hover:scale-105 transition shadow-md"
                      />
                    </div>
                  ) : (
                    <div className="w-20 h-20 bg-slate-950 rounded-xl flex items-center justify-center text-[10px] text-slate-600 border border-dashed border-slate-800">
                      2-rasm yo‘q
                    </div>
                  )}
                </div>

                {/* Approve / Reject / Saytdan Tekshirish Tugmalari */}
                <div className="flex lg:flex-col gap-2 w-full lg:w-auto min-w-[140px]">
                  {/* Saytdan Tekshirish Natijasi Ko'rsatkichi */}
                  {checkRes && (
                    <div
                      className={`p-1.5 rounded-lg text-[10px] font-bold text-center border animate-fade-in ${
                        checkRes.status === 'FOUND'
                          ? 'bg-emerald-500/20 text-emerald-300 border-emerald-500/40'
                          : checkRes.status === 'NOT_FOUND'
                          ? 'bg-rose-500/20 text-rose-300 border-rose-500/40'
                          : 'bg-amber-500/20 text-amber-300 border-amber-500/40'
                      }`}
                    >
                      {checkRes.status === 'FOUND' && '✅ Ovoz o‘tgan'}
                      {checkRes.status === 'NOT_FOUND' && '❌ Ovoz o‘tmagan'}
                      {checkRes.status === 'SITE_DOWN' && '⚠️ Sayt vaqtinchalik ishlamayapti'}
                    </div>
                  )}

                  {/* Saytdan Jonli Tekshirish Tugmasi */}
                  <button
                    disabled={isChecking}
                    onClick={() => handleCheckOnline(sub.id, sub.user.phone)}
                    className="flex-1 lg:flex-none px-3.5 py-2 bg-blue-600/20 hover:bg-blue-600/30 text-blue-300 border border-blue-500/40 rounded-xl text-xs font-bold transition flex items-center justify-center gap-1 disabled:opacity-50"
                  >
                    {isChecking ? '⏳ Tekshirilmoqda...' : '🔍 Saytdan Tekshirish'}
                  </button>

                  <button
                    disabled={loadingId === sub.id || sub.status === 'APPROVED'}
                    onClick={() => handleAction(sub.id, 'APPROVE')}
                    className="flex-1 lg:flex-none px-4 py-2 bg-emerald-600 hover:bg-emerald-500 disabled:opacity-40 text-white rounded-xl text-xs font-bold transition shadow-lg shadow-emerald-950/50"
                  >
                    Approve
                  </button>
                  <button
                    disabled={loadingId === sub.id || sub.status === 'REJECTED'}
                    onClick={() => setRejectModalId(sub.id)}
                    className="flex-1 lg:flex-none px-4 py-2 bg-rose-600 hover:bg-rose-500 disabled:opacity-40 text-white rounded-xl text-xs font-bold transition shadow-lg shadow-rose-950/50"
                  >
                    Reject
                  </button>
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* DM MODAL */}
      {dmModalUser && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-700 p-6 rounded-2xl max-w-md w-full space-y-4 shadow-2xl">
            <div className="flex justify-between items-center">
              <h3 className="text-base font-bold text-white">✉️ Foydalanuvchiga Telegramda Xabar</h3>
              <button onClick={() => setDmModalUser(null)} className="text-slate-400 hover:text-white">✕</button>
            </div>
            <p className="text-xs text-slate-400">
              Qabul qiluvchi: <span className="text-white font-semibold">TG: {dmModalUser.telegramId} {dmModalUser.username ? `(@${dmModalUser.username})` : ''}</span>
            </p>

            <form onSubmit={handleSendDM} className="space-y-3">
              <textarea
                rows={3}
                required
                placeholder="Xabaringizni yozing..."
                value={dmMessage}
                onChange={(e) => setDmMessage(e.target.value)}
                className="w-full bg-slate-950 border border-slate-700 p-3 rounded-xl text-xs text-white focus:outline-none focus:border-indigo-500"
              />
              <div className="flex justify-end gap-2">
                <button
                  type="button"
                  onClick={() => setDmModalUser(null)}
                  className="px-4 py-2 bg-slate-800 text-slate-300 rounded-xl text-xs font-semibold"
                >
                  Bekor qilish
                </button>
                <button
                  type="submit"
                  disabled={sendingDm}
                  className="px-4 py-2 bg-indigo-600 hover:bg-indigo-500 text-white rounded-xl text-xs font-bold disabled:opacity-50"
                >
                  {sendingDm ? 'Yuborilmoqda...' : 'Yuborish'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* IZOH MODAL */}
      {noteModalSub && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-700 p-6 rounded-2xl max-w-md w-full space-y-4 shadow-2xl">
            <h3 className="text-base font-bold text-white">📝 Ushbu ovozga izoh yozish</h3>
            <p className="text-xs text-slate-400">Ushbu izoh faqat admin panelda o‘zingiz uchun saqlanadi:</p>

            <input
              type="text"
              placeholder="Masalan: Karta raqamiga 10 000 so'm o'tkazildi..."
              value={noteText}
              onChange={(e) => setNoteText(e.target.value)}
              className="w-full bg-slate-950 border border-slate-700 p-3 rounded-xl text-xs text-white focus:outline-none focus:border-blue-500"
            />

            <div className="flex justify-end gap-2">
              <button
                onClick={() => setNoteModalSub(null)}
                className="px-4 py-2 bg-slate-800 text-slate-300 rounded-xl text-xs font-semibold"
              >
                Bekor qilish
              </button>
              <button
                onClick={() => handleAction(noteModalSub.id, 'SAVE_NOTE', { note: noteText })}
                className="px-4 py-2 bg-blue-600 hover:bg-blue-500 text-white rounded-xl text-xs font-bold"
              >
                Saqlash
              </button>
            </div>
          </div>
        </div>
      )}

      {/* REJECT MODAL */}
      {rejectModalId && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-700 p-6 rounded-2xl max-w-md w-full space-y-4 shadow-2xl">
            <h3 className="text-base font-bold text-white">Rad etish sababini tanlang</h3>
            <p className="text-xs text-slate-400">Ushbu sabab foydalanuvchiga Telegramda xabar qilinadi:</p>

            <select
              value={rejectReason}
              onChange={(e) => setRejectReason(e.target.value)}
              className="w-full bg-slate-950 border border-slate-700 p-3 rounded-xl text-xs text-white focus:outline-none focus:border-rose-500"
            >
              <option value="Screenshotdagi ma'lumotlar xato yoki ko'rinmayapti">Screenshotdagi ma'lumotlar xato yoki ko'rinmayapti</option>
              <option value="SMS kod mos kelmadi">SMS kod mos kelmadi</option>
              <option value="2-screenshotda ovoz berilgani tasdiqlanmagan">2-screenshotda ovoz berilgani tasdiqlanmagan</option>
              <option value="Ushbu raqam boshqa tashabbusga ovoz bergan">Ushbu raqam boshqa tashabbusga ovoz bergan</option>
              <option value="Soxta yoki takroriy screenshot yuborilgan">Soxta yoki takroriy screenshot yuborilgan</option>
            </select>

            <div className="flex gap-2 justify-end">
              <button onClick={() => setRejectModalId(null)} className="px-4 py-2 bg-slate-800 text-slate-300 rounded-xl text-xs font-semibold">
                Bekor qilish
              </button>
              <button
                onClick={() => handleAction(rejectModalId, 'REJECT', { reason: rejectReason })}
                className="px-4 py-2 bg-rose-600 hover:bg-rose-500 text-white rounded-xl text-xs font-bold"
              >
                Rad etish va Jo‘natish
              </button>
            </div>
          </div>
        </div>
      )}

      {/* BROADCAST MODAL */}
      {broadcastOpen && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-700 p-6 rounded-2xl max-w-lg w-full space-y-4 shadow-2xl">
            <div className="flex justify-between items-center">
              <h3 className="text-base font-bold text-white">📢 Ommaviy Xabar (Broadcast)</h3>
              <button onClick={() => setBroadcastOpen(false)} className="text-slate-400 hover:text-white">✕</button>
            </div>

            <form onSubmit={handleSendBroadcast} className="space-y-3">
              <div>
                <label className="text-xs text-slate-400 block mb-1">Kimlarga yuborilsin?</label>
                <select
                  value={broadcastTarget}
                  onChange={(e) => setBroadcastTarget(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-700 p-2.5 rounded-xl text-xs text-white"
                >
                  <option value="ALL">Barcha foydalanuvchilarga</option>
                  <option value="APPROVED">Faqat ovozi tasdiqlanganlarga</option>
                </select>
              </div>

              <div>
                <label className="text-xs text-slate-400 block mb-1">Xabar matni:</label>
                <textarea
                  rows={4}
                  required
                  placeholder="Hurmatli yurtdoshlar, ovozingiz uchun katta rahmat..."
                  value={broadcastMsg}
                  onChange={(e) => setBroadcastMsg(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-700 p-3 rounded-xl text-xs text-white focus:outline-none focus:border-indigo-500"
                />
              </div>

              {broadcastResult && <p className="text-xs font-semibold text-emerald-400">{broadcastResult}</p>}

              <div className="flex gap-2 justify-end pt-2">
                <button
                  type="button"
                  onClick={() => setBroadcastOpen(false)}
                  className="px-4 py-2 bg-slate-800 text-slate-300 rounded-xl text-xs font-semibold"
                >
                  Yopish
                </button>
                <button
                  type="submit"
                  disabled={broadcasting}
                  className="px-5 py-2 bg-indigo-600 hover:bg-indigo-500 text-white rounded-xl text-xs font-bold disabled:opacity-50"
                >
                  {broadcasting ? 'Jo‘natilmoqda...' : 'Jo‘natish'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* LIGHTBOX */}
      {previewImage && (
        <div
          className="fixed inset-0 z-50 bg-black/95 backdrop-blur-md flex items-center justify-center p-4"
          onClick={() => setPreviewImage(null)}
        >
          <div className="relative max-w-4xl max-h-[90vh] bg-slate-900 p-3 rounded-2xl border border-slate-700 shadow-2xl" onClick={(e) => e.stopPropagation()}>
            <div className="absolute top-4 right-4 flex gap-2 z-10">
              <button
                onClick={() => setRotation((r) => r + 90)}
                className="bg-slate-800 text-white px-3 py-1.5 rounded-xl text-xs font-bold hover:bg-slate-700 shadow"
              >
                🔄 90° Aylantirish
              </button>
              <button
                onClick={() => setPreviewImage(null)}
                className="bg-rose-600 text-white w-8 h-8 rounded-full font-bold flex items-center justify-center shadow"
              >
                ✕
              </button>
            </div>
            <img
              src={previewImage}
              alt="Preview"
              style={{ transform: `rotate(${rotation}deg)`, transition: 'transform 0.2s ease' }}
              className="max-h-[80vh] max-w-full object-contain rounded-xl mx-auto"
            />
          </div>
        </div>
      )}
    </div>
  );
}
FILEEOF

echo "📦 Paketlar o'rnatilmoqda..."
npm install

echo "🗄 Ma'lumotlar bazasi sinxronlanmoqda..."
npx prisma generate
npx prisma db push

echo "--------------------------------------------------------"
echo "🎉 O'RNATISH TO'LIQ VA MUVAFFAQIYATLI YAKUNLANDI!"
echo "--------------------------------------------------------"
echo "👑 Yagona Owner: @temurbekbahramov1"
echo "🤖 Telegram Bot Token: O'rnatildi!"
echo ""
echo "🚀 ENDI ISHGA TUSHIRISH:"
echo "1. Botni yoqish:"
echo "   npm run bot"
echo ""
echo "2. Admin Panelni ochish (alohida terminalda):"
echo "   npm run dev"
echo "   👉 Havola: http://localhost:3000/admin"
echo "   👉 Login: temurbekbahramov1 | Parol: temurbek2026"
echo "--------------------------------------------------------"
EOF

chmod +x code.sh
bash code.sh