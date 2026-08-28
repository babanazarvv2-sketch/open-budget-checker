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
