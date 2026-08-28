export interface IStorageProvider {
  uploadFile(buffer: Buffer, originalFilename: string, mimeType: string): Promise<string>;
  getFileUrl(filePath: string): string;
}
