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
