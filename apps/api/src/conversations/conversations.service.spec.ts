import { ForbiddenException } from '@nestjs/common';
import { ConversationsService } from './conversations.service';
import { PrismaService } from '../prisma/prisma.service';

describe('ConversationsService', () => {
  let service: ConversationsService;
  let prisma: {
    user: { findUnique: jest.Mock };
    contact: { findFirst: jest.Mock };
    conversation: { findFirst: jest.Mock; create: jest.Mock; findMany: jest.Mock };
    messageReceipt: { count: jest.Mock };
  };

  beforeEach(() => {
    delete process.env.GM_IDENTITIES;
    prisma = {
      user: {
        findUnique: jest.fn(),
      },
      contact: {
        findFirst: jest.fn(),
      },
      conversation: {
        findFirst: jest.fn(),
        create: jest.fn(),
        findMany: jest.fn(),
      },
      messageReceipt: {
        count: jest.fn(),
      },
    };
    service = new ConversationsService(prisma as unknown as PrismaService);
  });

  it('rejects direct conversation creation when users are not accepted contacts', async () => {
    prisma.contact.findFirst.mockResolvedValue(null);
    prisma.user.findUnique.mockResolvedValue({ id: 'u1', email: 'user@example.com', phone: null, role: 'USER' });

    await expect(service.createDirect('u1', 'u2')).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('creates a direct conversation when users are accepted contacts', async () => {
    prisma.contact.findFirst.mockResolvedValue({ id: 'contact-1', status: 'ACCEPTED' });
    prisma.conversation.findFirst.mockResolvedValue(null);
    prisma.conversation.create.mockResolvedValue({
      id: 'conversation-1',
      type: 'DIRECT',
      members: [{ userId: 'u1' }, { userId: 'u2' }],
    });

    const conversation = await service.createDirect('u1', 'u2');

    expect(conversation.id).toBe('conversation-1');
    expect(prisma.contact.findFirst).toHaveBeenCalledWith({
      where: {
        status: 'ACCEPTED',
        OR: [
          { requesterId: 'u1', addresseeId: 'u2' },
          { requesterId: 'u2', addresseeId: 'u1' },
        ],
      },
    });
    expect(prisma.conversation.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          type: 'DIRECT',
        }),
      }),
    );
  });

  it('allows a configured GM identity to create a direct conversation without friendship', async () => {
    process.env.GM_IDENTITIES = 'gm@example.com,18800000000';
    prisma.contact.findFirst.mockResolvedValue(null);
    prisma.user.findUnique.mockResolvedValue({ id: 'gm', email: 'gm@example.com', phone: null, role: 'USER' });
    prisma.conversation.findFirst.mockResolvedValue(null);
    prisma.conversation.create.mockResolvedValue({
      id: 'conversation-gm',
      type: 'DIRECT',
      members: [{ userId: 'gm' }, { userId: 'u2' }],
    });

    const conversation = await service.createDirect('gm', 'u2');

    expect(conversation.id).toBe('conversation-gm');
    expect(prisma.conversation.create).toHaveBeenCalled();
  });

  it('allows a GM role user to create a direct conversation without friendship', async () => {
    prisma.contact.findFirst.mockResolvedValue(null);
    prisma.user.findUnique.mockResolvedValue({ id: 'gm', email: null, phone: 'kkgm', role: 'GM' });
    prisma.conversation.findFirst.mockResolvedValue(null);
    prisma.conversation.create.mockResolvedValue({
      id: 'conversation-role-gm',
      type: 'DIRECT',
      members: [{ userId: 'gm' }, { userId: 'u2' }],
    });

    const conversation = await service.createDirect('gm', 'u2');

    expect(conversation.id).toBe('conversation-role-gm');
    expect(prisma.conversation.create).toHaveBeenCalled();
  });
});
