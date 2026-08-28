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
