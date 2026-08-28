import { IStorageProvider } from './types';
import { LocalStorageProvider } from './local';

export const storageProvider: IStorageProvider = new LocalStorageProvider();
