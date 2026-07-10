import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { MAX_SHORT_VIDEO_DURATION_MS } from '../common/media-limits';
import { SendMessageDto } from './dto/send-message.dto';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class MessagesService {
  constructor(private readonly prisma: PrismaService) {}

  async list(userId: string, conversationId: string, take = 50) {
    await this.assertMember(userId, conversationId);
    const messages = await this.prisma.message.findMany({
      where: { conversationId },
      include: { attachments: true, receipts: true },
      orderBy: { createdAt: 'desc' },
      take,
    });
    return messages.map((message) => this.withReadState(message, userId));
  }

  async send(senderId: string, dto: SendMessageDto) {
    await this.assertMember(senderId, dto.conversationId);
    if (dto.type === 'VIDEO') {
      if (dto.durationMs == null) {
        throw new BadRequestException('Video duration is required');
      }
      if (dto.durationMs > MAX_SHORT_VIDEO_DURATION_MS) {
        throw new BadRequestException(
          'Video messages must be 15 seconds or shorter',
        );
      }
    }
    const message = await this.prisma.message.create({
      data: {
        conversationId: dto.conversationId,
        senderId,
        type: dto.type,
        content: dto.content,
        durationMs: dto.durationMs,
        attachments: dto.attachmentIds?.length
          ? {
              connect: dto.attachmentIds.map((id) => ({ id })),
            }
          : undefined,
      },
      include: { attachments: true, receipts: true },
    });

    const members = await this.prisma.conversationMember.findMany({
      where: { conversationId: dto.conversationId },
      select: { userId: true },
    });
    const receipts = members
      .filter((member) => member.userId !== senderId)
      .map((member) => ({
        messageId: message.id,
        userId: member.userId,
        deliveredAt: null,
        readAt: null,
      }));

    if (receipts.length > 0) {
      await this.prisma.messageReceipt.createMany({
        data: receipts,
        skipDuplicates: true,
      });
    }

    await this.prisma.conversation.update({
      where: { id: dto.conversationId },
      data: { updatedAt: new Date() },
    });

    return this.withReadState(message, senderId);
  }

  async markDelivered(userId: string, messageId: string) {
    try {
      await this.prisma.messageReceipt.upsert({
        where: { messageId_userId: { messageId, userId } },
        update: { deliveredAt: new Date() },
        create: { messageId, userId, deliveredAt: new Date() },
      });
    } catch {
      throw new NotFoundException('Message receipt not found');
    }

    return this.prisma.message.update({
      where: { id: messageId },
      data: { status: 'DELIVERED' },
    });
  }

  async markRead(userId: string, conversationId: string) {
    await this.assertMember(userId, conversationId);
    const now = new Date();
    const unreadReceipts = await this.prisma.messageReceipt.findMany({
      where: {
        userId,
        readAt: null,
        message: { conversationId, senderId: { not: userId } },
      },
      select: { messageId: true },
    });
    await this.prisma.messageReceipt.updateMany({
      where: {
        userId,
        readAt: null,
        message: { conversationId, senderId: { not: userId } },
      },
      data: { readAt: now, deliveredAt: now },
    });
    await this.prisma.conversationMember.update({
      where: { conversationId_userId: { conversationId, userId } },
      data: { lastReadAt: now },
    });
    return {
      ok: true,
      conversationId,
      readerId: userId,
      messageIds: unreadReceipts.map((receipt) => receipt.messageId),
    };
  }

  async conversationMemberIds(conversationId: string) {
    const members = await this.prisma.conversationMember.findMany({
      where: { conversationId },
      select: { userId: true },
    });
    return members.map((member) => member.userId);
  }

  private async assertMember(userId: string, conversationId: string) {
    const member = await this.prisma.conversationMember.findUnique({
      where: { conversationId_userId: { conversationId, userId } },
    });
    if (!member) {
      throw new ForbiddenException('Not a conversation member');
    }
  }

  private withReadState<
    T extends { senderId: string; receipts?: { readAt: Date | null }[] },
  >(message: T, userId: string) {
    return {
      ...message,
      readByOthers:
        message.senderId === userId &&
        (message.receipts ?? []).some((receipt) => receipt.readAt),
    };
  }
}
