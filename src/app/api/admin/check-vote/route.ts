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
