import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateProfileDto } from './dto/update-profile.dto';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async me(userId: string) {
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
      },
      select: this.safeSelect(),
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
      role: true,
      createdAt: true,
      updatedAt: true,
    } as const;
  }
}
