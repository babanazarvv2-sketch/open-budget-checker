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
