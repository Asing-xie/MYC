import { BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { UploadsService } from './uploads.service';
import { PrismaService } from '../prisma/prisma.service';

describe('UploadsService', () => {
  it('rejects empty file uploads', async () => {
    const service = new UploadsService(
      {} as PrismaService,
      new ConfigService(),
    );

    await expect(
      service.uploadFile('u1', 'IMAGE', undefined),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('records uploaded COS file metadata', async () => {
    const prisma = {
      attachment: {
        create: jest.fn().mockResolvedValue({
          id: 'a1',
          url: 'https://cdn.example.com/key.jpg',
        }),
      },
    };
    const service = new UploadsService(
      prisma as unknown as PrismaService,
      new ConfigService({
        COS_SECRET_ID: 'sid',
        COS_SECRET_KEY: 'skey',
        COS_BUCKET: 'bucket-125',
        COS_REGION: 'ap-guangzhou',
        COS_PUBLIC_BASE_URL: 'https://cdn.example.com',
      }),
    );

    jest.spyOn(service, 'putObject').mockResolvedValue(undefined);

    const result = await service.uploadFile('u1', 'IMAGE', {
      originalname: 'avatar.jpg',
      mimetype: 'image/jpeg',
      buffer: Buffer.from('file'),
      size: 4,
    } as Express.Multer.File);

    expect(result.id).toBe('a1');
    expect(prisma.attachment.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        ownerId: 'u1',
        type: 'IMAGE',
        url: expect.stringContaining('https://cdn.example.com/chat/'),
        key: expect.stringContaining('chat/'),
        size: 4,
      }),
    });
  });

  it('rejects video uploads longer than 15 seconds', async () => {
    const service = new UploadsService(
      {} as PrismaService,
      new ConfigService(),
    );

    await expect(
      service.uploadFile(
        'u1',
        'VIDEO',
        {
          originalname: 'clip.mp4',
          mimetype: 'video/mp4',
          buffer: Buffer.from('file'),
          size: 4,
        } as Express.Multer.File,
        16000,
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects video uploads without duration metadata', async () => {
    const service = new UploadsService(
      {} as PrismaService,
      new ConfigService(),
    );

    await expect(
      service.uploadFile('u1', 'VIDEO', {
        originalname: 'clip.mp4',
        mimetype: 'video/mp4',
        buffer: Buffer.from('file'),
        size: 4,
      } as Express.Multer.File),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});
