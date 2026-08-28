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
