import { BadRequestException, ForbiddenException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ConversationsService {
  constructor(private readonly prisma: PrismaService) {}

  async createDirect(currentUserId: string, otherUserId: string) {
    if (currentUserId === otherUserId) {
      throw new BadRequestException('Cannot chat with yourself');
    }

    const contact = await this.prisma.contact.findFirst({
      where: {
        status: 'ACCEPTED',
        OR: [
          { requesterId: currentUserId, addresseeId: otherUserId },
          { requesterId: otherUserId, addresseeId: currentUserId },
        ],
      },
    });
    if (!contact && !(await this.isGmUser(currentUserId))) {
      throw new ForbiddenException('You must be friends before starting a chat');
    }

    const existing = await this.prisma.conversation.findFirst({
      where: {
        type: 'DIRECT',
        members: {
          every: {
            userId: { in: [currentUserId, otherUserId] },
          },
        },
      },
      include: {
        members: {
          include: {
            user: { select: { id: true, nickname: true, avatarUrl: true, email: true, phone: true } },
          },
        },
      },
    });

    if (existing && existing.members.length === 2) {
      return existing;
    }

    return this.prisma.conversation.create({
      data: {
        type: 'DIRECT',
        members: {
          create: [{ userId: currentUserId }, { userId: otherUserId }],
        },
      },
      include: {
        members: {
          include: {
            user: { select: { id: true, nickname: true, avatarUrl: true, email: true, phone: true } },
          },
        },
      },
    });
  }

  async list(userId: string) {
    const conversations = await this.prisma.conversation.findMany({
      where: { members: { some: { userId } } },
      include: {
        members: {
          include: {
            user: { select: { id: true, nickname: true, avatarUrl: true, email: true, phone: true } },
          },
        },
        messages: {
          orderBy: { createdAt: 'desc' },
          take: 1,
          include: { attachments: true },
        },
      },
      orderBy: { updatedAt: 'desc' },
    });

    return Promise.all(
      conversations.map(async (conversation) => {
        const unread = await this.prisma.messageReceipt.count({
          where: {
            userId,
            readAt: null,
            message: { conversationId: conversation.id, senderId: { not: userId } },
          },
        });

        return {
          ...conversation,
          latestMessage: conversation.messages[0] ?? null,
          unread,
          messages: undefined,
        };
      }),
    );
  }

  private async isGmUser(userId: string) {
    const identities = (process.env.GM_IDENTITIES ?? '')
      .split(',')
      .map((identity) => identity.trim().toLowerCase())
      .filter(Boolean);

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { email: true, phone: true, role: true },
    });
    if (!user) return false;
    if (user.role === 'GM') return true;
    if (identities.length === 0) return false;

    const email = user.email?.toLowerCase();
    const phone = user.phone?.toLowerCase();
    return Boolean((email && identities.includes(email)) || (phone && identities.includes(phone)));
  }
}
