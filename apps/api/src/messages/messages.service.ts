import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { SendMessageDto } from './dto/send-message.dto';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class MessagesService {
  constructor(private readonly prisma: PrismaService) {}

  async list(userId: string, conversationId: string, take = 50) {
    await this.assertMember(userId, conversationId);
    return this.prisma.message.findMany({
      where: { conversationId },
      include: { attachments: true },
      orderBy: { createdAt: 'desc' },
      take,
    });
  }

  async send(senderId: string, dto: SendMessageDto) {
    await this.assertMember(senderId, dto.conversationId);
    const message = await this.prisma.message.create({
      data: {
        conversationId: dto.conversationId,
        senderId,
        type: dto.type,
        content: dto.content,
        attachments: dto.attachmentIds?.length
          ? {
              connect: dto.attachmentIds.map((id) => ({ id })),
            }
          : undefined,
      },
      include: { attachments: true },
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

    return message;
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
    await this.prisma.messageReceipt.updateMany({
      where: {
        userId,
        readAt: null,
        message: { conversationId, senderId: { not: userId } },
      },
      data: { readAt: now, deliveredAt: now },
    });
    return { ok: true };
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
}
