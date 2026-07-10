import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { MessagesService } from './messages.service';
import { PrismaService } from '../prisma/prisma.service';

describe('MessagesService', () => {
  let service: MessagesService;
  let prisma: {
    conversationMember: { findUnique: jest.Mock; findMany: jest.Mock };
    conversation: { update: jest.Mock };
    message: { create: jest.Mock; findMany: jest.Mock; update: jest.Mock };
    messageReceipt: { createMany: jest.Mock; upsert: jest.Mock };
  };

  beforeEach(() => {
    prisma = {
      conversationMember: {
        findUnique: jest.fn(),
        findMany: jest.fn(),
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
        upsert: jest.fn(),
      },
    };
    service = new MessagesService(prisma as unknown as PrismaService);
  });

  it('persists a text message and creates unread receipts for other members', async () => {
    prisma.conversationMember.findUnique.mockResolvedValue({ conversationId: 'c1', userId: 'u1' });
    prisma.conversationMember.findMany.mockResolvedValue([{ userId: 'u1' }, { userId: 'u2' }]);
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
      data: [{ messageId: 'm1', userId: 'u2', deliveredAt: null, readAt: null }],
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

  it('marks a message delivered for a recipient', async () => {
    prisma.message.update.mockResolvedValue({ id: 'm1', status: 'DELIVERED' });
    prisma.messageReceipt.upsert.mockResolvedValue({ messageId: 'm1', userId: 'u2' });

    await service.markDelivered('u2', 'm1');

    expect(prisma.message.update).toHaveBeenCalledWith({
      where: { id: 'm1' },
      data: { status: 'DELIVERED' },
    });
  });

  it('returns not found when delivered receipt cannot be saved', async () => {
    prisma.messageReceipt.upsert.mockRejectedValue(new Error('missing'));

    await expect(service.markDelivered('u2', 'm1')).rejects.toBeInstanceOf(NotFoundException);
  });
});
