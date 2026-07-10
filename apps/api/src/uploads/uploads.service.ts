import { BadRequestException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import COS = require('cos-nodejs-sdk-v5');
import { randomUUID } from 'crypto';
import { extname } from 'path';
import { PrismaService } from '../prisma/prisma.service';
import { CreateUploadDto } from './dto/create-upload.dto';

@Injectable()
export class UploadsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  async create(ownerId: string, dto: CreateUploadDto) {
    return this.prisma.attachment.create({
      data: {
        ownerId,
        type: dto.type,
        url: dto.url,
        key: dto.key,
        size: dto.size,
        duration: dto.duration,
      },
    });
  }

  async uploadFile(ownerId: string, type: 'IMAGE' | 'VOICE', file?: Express.Multer.File) {
    if (!file) {
      throw new BadRequestException('File is required');
    }

    const bucket = this.requiredConfig('COS_BUCKET');
    const region = this.requiredConfig('COS_REGION');
    const publicBaseUrl =
      this.config.get<string>('COS_PUBLIC_BASE_URL') || `https://${bucket}.cos.${region}.myqcloud.com`;
    const key = this.objectKey(type, file.originalname);

    await this.putObject(bucket, region, key, file);

    return this.prisma.attachment.create({
      data: {
        ownerId,
        type,
        url: `${publicBaseUrl.replace(/\/$/, '')}/${key}`,
        key,
        size: file.size,
      },
    });
  }

  async putObject(bucket: string, region: string, key: string, file: Express.Multer.File): Promise<void> {
    const cos = new COS({
      SecretId: this.requiredConfig('COS_SECRET_ID'),
      SecretKey: this.requiredConfig('COS_SECRET_KEY'),
    });

    await new Promise<void>((resolve, reject) => {
      cos.putObject(
        {
          Bucket: bucket,
          Region: region,
          Key: key,
          Body: file.buffer,
          ContentType: file.mimetype,
          ACL: 'public-read',
        },
        (error) => {
          if (error) reject(error);
          else resolve();
        },
      );
    });
  }

  cosConfig() {
    return {
      bucket: this.config.get<string>('COS_BUCKET') ?? '',
      region: this.config.get<string>('COS_REGION') ?? '',
      publicBaseUrl: this.config.get<string>('COS_PUBLIC_BASE_URL') ?? '',
      directUploadEnabled: Boolean(this.config.get<string>('COS_BUCKET')),
    };
  }

  private requiredConfig(key: string) {
    const value = this.config.get<string>(key);
    if (!value) {
      throw new BadRequestException(`${key} is not configured`);
    }
    return value;
  }

  private objectKey(type: 'IMAGE' | 'VOICE', originalName: string) {
    const folder = type === 'IMAGE' ? 'images' : 'voices';
    const extension = extname(originalName || '').toLowerCase();
    return `chat/${folder}/${new Date().toISOString().slice(0, 10)}/${randomUUID()}${extension}`;
  }
}
