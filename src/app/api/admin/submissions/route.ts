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
