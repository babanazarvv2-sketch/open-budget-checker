import { prisma } from './db';

const DEFAULT_URL = 'https://new.openbudget.uz/uz/initiative-budget/active-initiatives/55/be62aab0-3a4f-41a9-b59a-46e2022c710b';
let cachedUrl = DEFAULT_URL;

export async function getActiveVoteUrl(): Promise<string> {
  try {
    const setting = await prisma.setting.findUnique({
      where: { key: 'VOTE_URL' }
    });
    if (setting?.value) {
      cachedUrl = setting.value;
    }
  } catch {
    // Default fallback
  }
  return cachedUrl;
}

export async function setActiveVoteUrl(newUrl: string): Promise<string> {
  cachedUrl = newUrl.trim();
  try {
    await prisma.setting.upsert({
      where: { key: 'VOTE_URL' },
      update: { value: cachedUrl },
      create: { key: 'VOTE_URL', value: cachedUrl }
    });
  } catch (e) {
    console.error('Error saving URL setting:', e);
  }
  return cachedUrl;
}
