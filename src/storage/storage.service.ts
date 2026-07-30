import {
  BadRequestException,
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { randomUUID } from 'crypto';

/** A single uploaded file (multer memory storage shape). */
export interface UploadFile {
  buffer: Buffer;
  mimetype: string;
  originalname?: string;
  size?: number;
}

const MIME_EXT: Record<string, string> = {
  'image/jpeg': '.jpg',
  'image/jpg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
  'image/heic': '.heic',
  'image/heif': '.heif',
};

/**
 * Cloudflare R2 image storage (S3-compatible). Uploads bytes proxied through
 * the backend and returns a public URL. R2/DO Spaces/AWS S3 all speak S3, so
 * switching providers is just an env-var change (endpoint + creds).
 */
@Injectable()
export class StorageService {
  private readonly logger = new Logger(StorageService.name);
  private readonly client: S3Client | null;
  private readonly bucket: string;
  private readonly publicBaseUrl: string;

  constructor(private readonly config: ConfigService) {
    const accountId = config.get<string>('R2_ACCOUNT_ID');
    const accessKeyId = config.get<string>('R2_ACCESS_KEY_ID');
    const secretAccessKey = config.get<string>('R2_SECRET_ACCESS_KEY');
    this.bucket = config.get<string>('R2_BUCKET') ?? '';
    this.publicBaseUrl = (config.get<string>('R2_PUBLIC_BASE_URL') ?? '').replace(
      /\/+$/,
      '',
    );

    if (accountId && accessKeyId && secretAccessKey && this.bucket) {
      this.client = new S3Client({
        region: 'auto',
        endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
        credentials: { accessKeyId, secretAccessKey },
      });
      this.logger.log(`R2 storage configured (bucket: ${this.bucket}).`);
    } else {
      this.client = null;
      this.logger.warn(
        'R2 not configured — image uploads will fail until R2_* env vars are set.',
      );
    }
  }

  /** True once all R2 env vars are present. */
  get isConfigured(): boolean {
    return this.client !== null;
  }

  /**
   * Upload a single image to R2 and return its public URL.
   * @param keyPrefix folder-like prefix, e.g. `kitchens/<uid>`
   */
  async uploadImage(file: UploadFile, keyPrefix = 'uploads'): Promise<string> {
    if (!this.client) {
      throw new ServiceUnavailableException(
        'Image storage (R2) is not configured on the server.',
      );
    }
    if (!file?.buffer?.length) {
      throw new BadRequestException('Empty file.');
    }
    if (!file.mimetype?.startsWith('image/')) {
      throw new BadRequestException(
        `Only image files are allowed (got "${file.mimetype}").`,
      );
    }

    const ext = MIME_EXT[file.mimetype] ?? '';
    const key = `${keyPrefix.replace(/\/+$/, '')}/${randomUUID()}${ext}`;

    await this.client.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: file.buffer,
        ContentType: file.mimetype,
      }),
    );

    if (!this.publicBaseUrl) {
      throw new ServiceUnavailableException(
        'R2_PUBLIC_BASE_URL is not set — cannot build a public image URL.',
      );
    }
    return `${this.publicBaseUrl}/${key}`;
  }

  /** Upload many images in parallel, preserving order. */
  uploadImages(files: UploadFile[], keyPrefix = 'uploads'): Promise<string[]> {
    return Promise.all(files.map((f) => this.uploadImage(f, keyPrefix)));
  }
}
