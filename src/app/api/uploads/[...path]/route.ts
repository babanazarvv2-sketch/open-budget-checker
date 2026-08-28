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
