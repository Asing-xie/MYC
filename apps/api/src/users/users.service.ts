import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AddAlbumPhotoDto } from './dto/add-album-photo.dto';
import { UpdateProfileDto } from './dto/update-profile.dto';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async me(userId: string) {
    return this.profile(userId);
  }

  async profile(userId: string) {
    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: this.safeSelect(),
    });
    return user;
  }

  async updateMe(userId: string, dto: UpdateProfileDto) {
    return this.prisma.user.update({
      where: { id: userId },
      data: {
        nickname: dto.nickname,
        avatarUrl: dto.avatarUrl,
        signature: dto.signature,
      },
      select: this.safeSelect(),
    });
  }

  async albumPhotos(userId: string) {
    return this.prisma.userAlbumPhoto.findMany({
      where: { ownerId: userId },
      orderBy: { createdAt: 'desc' },
      take: 60,
    });
  }

  async addAlbumPhoto(userId: string, dto: AddAlbumPhotoDto) {
    return this.prisma.userAlbumPhoto.create({
      data: {
        ownerId: userId,
        url: dto.url,
        caption: dto.caption,
      },
    });
  }

  async search(query: string, requesterId: string) {
    const q = query.trim();
    if (q.length < 2) {
      return [];
    }
    return this.prisma.user.findMany({
      where: {
        id: { not: requesterId },
        OR: [
          { email: { contains: q, mode: 'insensitive' } },
          { phone: { contains: q } },
          { nickname: { contains: q, mode: 'insensitive' } },
        ],
      },
      select: this.safeSelect(),
      take: 20,
      orderBy: { createdAt: 'desc' },
    });
  }

  private safeSelect() {
    return {
      id: true,
      email: true,
      phone: true,
      nickname: true,
      avatarUrl: true,
      signature: true,
      role: true,
      createdAt: true,
      updatedAt: true,
    } as const;
  }
}
