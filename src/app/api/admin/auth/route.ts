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
