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
