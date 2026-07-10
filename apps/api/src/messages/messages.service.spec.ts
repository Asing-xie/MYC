import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { MessagesService } from './messages.service';
import { PrismaService } from '../prisma/prisma.service';

describe('MessagesService', () => {
  let service: MessagesService;
  let prisma: {
    conversationMember: {
      findUnique: jest.Mock;
      findMany: jest.Mock;
      update: jest.Mock;
    };
    conversation: { update: jest.Mock };
    message: { create: jest.Mock; findMany: jest.Mock; update: jest.Mock };
    messageReceipt: {
      createMany: jest.Mock;
      findMany: jest.Mock;
      upsert: jest.Mock;
      updateMany: jest.Mock;
    };
  };

  beforeEach(() => {
    prisma = {
      conversationMember: {
        findUnique: jest.fn(),
        findMany: jest.fn(),
        update: jest.fn(),
      },
      conversation: {
        update: jest.fn(),
      },
      message: {
        create: jest.fn(),
        findMany: jest.fn(),
        update: jest.fn(),
      },
      messageReceipt: {
        createMany: jest.fn(),
        findMany: jest.fn(),
        upsert: jest.fn(),
        updateMany: jest.fn(),
      },
    };
    service = new MessagesService(prisma as unknown as PrismaService);
  });

  it('persists a text message and creates unread receipts for other members', async () => {
    prisma.conversationMember.findUnique.mockResolvedValue({
      conversationId: 'c1',
      userId: 'u1',
    });
    prisma.conversationMember.findMany.mockResolvedValue([
      { userId: 'u1' },
      { userId: 'u2' },
    ]);
    prisma.message.create.mockResolvedValue({
      id: 'm1',
      conversationId: 'c1',
      senderId: 'u1',
      type: 'TEXT',
      content: 'hello',
      status: 'SENT',
      createdAt: new Date(),
      attachments: [],
    });

    const message = await service.send('u1', {
      conversationId: 'c1',
      type: 'TEXT',
      content: 'hello',
    });

    expect(message.id).toBe('m1');
    expect(prisma.messageReceipt.createMany).toHaveBeenCalledWith({
      data: [
        { messageId: 'm1', userId: 'u2', deliveredAt: null, readAt: null },
      ],
      skipDuplicates: true,
    });
    expect(prisma.conversation.update).toHaveBeenCalledWith({
      where: { id: 'c1' },
      data: { updatedAt: expect.any(Date) },
    });
  });

  it('rejects sending to a conversation the user is not a member of', async () => {
    prisma.conversationMember.findUnique.mockResolvedValue(null);

    await expect(
      service.send('u1', {
        conversationId: 'c1',
        type: 'TEXT',
        content: 'hello',
      }),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('rejects video messages longer than 15 seconds', async () => {
    prisma.conversationMember.findUnique.mockResolvedValue({
      conversationId: 'c1',
      userId: 'u1',
    });

    await expect(
      service.send('u1', {
        conversationId: 'c1',
        type: 'VIDEO',
        content: 'https://example.com/v.mp4',
        durationMs: 16000,
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects video messages without duration metadata', async () => {
    prisma.conversationMember.findUnique.mockResolvedValue({
      conversationId: 'c1',
      userId: 'u1',
    });

    await expect(
      service.send('u1', {
        conversationId: 'c1',
        type: 'VIDEO',
        content: 'https://example.com/v.mp4',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('marks a message delivered for a recipient', async () => {
    prisma.message.update.mockResolvedValue({ id: 'm1', status: 'DELIVERED' });
    prisma.messageReceipt.upsert.mockResolvedValue({
      messageId: 'm1',
      userId: 'u2',
    });

    await service.markDelivered('u2', 'm1');

    expect(prisma.message.update).toHaveBeenCalledWith({
      where: { id: 'm1' },
      data: { status: 'DELIVERED' },
    });
  });

  it('returns not found when delivered receipt cannot be saved', async () => {
    prisma.messageReceipt.upsert.mockRejectedValue(new Error('missing'));

    await expect(service.markDelivered('u2', 'm1')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('marks unread receipts in a conversation as read for the current user', async () => {
    prisma.conversationMember.findUnique.mockResolvedValue({
      conversationId: 'c1',
      userId: 'u2',
    });
    prisma.messageReceipt.findMany.mockResolvedValue([
      { messageId: 'm1' },
      { messageId: 'm2' },
    ]);
    prisma.messageReceipt.updateMany.mockResolvedValue({ count: 2 });
    prisma.conversationMember.update.mockResolvedValue({
      conversationId: 'c1',
      userId: 'u2',
    });

    const result = await service.markRead('u2', 'c1');

    expect(prisma.messageReceipt.findMany).toHaveBeenCalledWith({
      where: {
        userId: 'u2',
        readAt: null,
        message: { conversationId: 'c1', senderId: { not: 'u2' } },
      },
      select: { messageId: true },
    });
    expect(prisma.messageReceipt.updateMany).toHaveBeenCalledWith({
      where: {
        userId: 'u2',
        readAt: null,
        message: { conversationId: 'c1', senderId: { not: 'u2' } },
      },
      data: { readAt: expect.any(Date), deliveredAt: expect.any(Date) },
    });
    expect(prisma.conversationMember.update).toHaveBeenCalledWith({
      where: { conversationId_userId: { conversationId: 'c1', userId: 'u2' } },
      data: { lastReadAt: expect.any(Date) },
    });
    expect(result.messageIds).toEqual(['m1', 'm2']);
  });
});
