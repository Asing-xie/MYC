import { ForbiddenException } from '@nestjs/common';
import { ConversationsService } from './conversations.service';
import { PrismaService } from '../prisma/prisma.service';

describe('ConversationsService', () => {
  let service: ConversationsService;
  let prisma: {
    user: { findMany: jest.Mock; findUnique: jest.Mock };
    contact: { findFirst: jest.Mock; findMany: jest.Mock };
    conversation: {
      findFirst: jest.Mock;
      create: jest.Mock;
      findMany: jest.Mock;
      findUnique: jest.Mock;
      update: jest.Mock;
      delete: jest.Mock;
    };
    conversationMember: {
      findUnique: jest.Mock;
      findMany: jest.Mock;
      createMany: jest.Mock;
      delete: jest.Mock;
      deleteMany: jest.Mock;
      count: jest.Mock;
    };
    messageReceipt: { count: jest.Mock };
  };

  beforeEach(() => {
    delete process.env.GM_IDENTITIES;
    prisma = {
      user: {
        findMany: jest.fn(),
        findUnique: jest.fn(),
      },
      contact: {
        findFirst: jest.fn(),
        findMany: jest.fn(),
      },
      conversation: {
        findFirst: jest.fn(),
        create: jest.fn(),
        findMany: jest.fn(),
        findUnique: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
      },
      conversationMember: {
        findUnique: jest.fn(),
        findMany: jest.fn(),
        createMany: jest.fn(),
        delete: jest.fn(),
        deleteMany: jest.fn(),
        count: jest.fn(),
      },
      messageReceipt: {
        count: jest.fn(),
      },
    };
    service = new ConversationsService(prisma as unknown as PrismaService);
  });

  it('rejects direct conversation creation when users are not accepted contacts', async () => {
    prisma.contact.findFirst.mockResolvedValue(null);
    prisma.user.findUnique.mockResolvedValue({
      id: 'u1',
      email: 'user@example.com',
      phone: null,
      role: 'USER',
    });

    await expect(service.createDirect('u1', 'u2')).rejects.toBeInstanceOf(
      ForbiddenException,
    );
  });

  it('creates a direct conversation when users are accepted contacts', async () => {
    prisma.contact.findFirst.mockResolvedValue({
      id: 'contact-1',
      status: 'ACCEPTED',
    });
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
    prisma.user.findUnique.mockResolvedValue({
      id: 'gm',
      email: 'gm@example.com',
      phone: null,
      role: 'USER',
    });
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
    prisma.user.findUnique.mockResolvedValue({
      id: 'gm',
      email: null,
      phone: 'kkgm',
      role: 'GM',
    });
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

  it('creates a group conversation with accepted contacts', async () => {
    prisma.user.findUnique.mockResolvedValue({
      id: 'u1',
      email: 'u1@example.com',
      phone: null,
      role: 'USER',
    });
    prisma.contact.findMany.mockResolvedValue([
      { requesterId: 'u1', addresseeId: 'u2' },
      { requesterId: 'u3', addresseeId: 'u1' },
    ]);
    prisma.user.findMany.mockResolvedValue([
      { id: 'u1', nickname: 'A' },
      { id: 'u2', nickname: 'B' },
      { id: 'u3', nickname: 'C' },
    ]);
    prisma.conversation.create.mockResolvedValue({
      id: 'group-1',
      type: 'GROUP',
      title: 'Friends',
      members: [{ userId: 'u1' }, { userId: 'u2' }, { userId: 'u3' }],
    });

    const conversation = await service.createGroup('u1', {
      title: 'Friends',
      memberIds: ['u2', 'u3'],
    });

    expect(conversation.id).toBe('group-1');
    expect(prisma.conversation.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          type: 'GROUP',
          title: 'Friends',
          members: {
            create: [
              { userId: 'u1', role: 'OWNER' },
              { userId: 'u2', role: 'MEMBER' },
              { userId: 'u3', role: 'MEMBER' },
            ],
          },
        }),
      }),
    );
  });

  it('allows the group owner to rename a group', async () => {
    prisma.conversation.findUnique.mockResolvedValue({
      id: 'group-1',
      type: 'GROUP',
      members: [{ userId: 'u1', role: 'OWNER' }],
    });
    prisma.conversation.update.mockResolvedValue({
      id: 'group-1',
      type: 'GROUP',
      title: 'New name',
      members: [],
    });

    const conversation = await service.updateGroupTitle(
      'u1',
      'group-1',
      'New name',
    );

    expect(conversation.title).toBe('New name');
    expect(prisma.conversation.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'group-1' },
        data: { title: 'New name' },
      }),
    );
  });

  it('rejects group rename from a regular member', async () => {
    prisma.conversation.findUnique.mockResolvedValue({
      id: 'group-1',
      type: 'GROUP',
      members: [{ userId: 'u2', role: 'MEMBER' }],
    });
    prisma.user.findUnique.mockResolvedValue({
      id: 'u2',
      email: null,
      phone: null,
      role: 'USER',
    });

    await expect(
      service.updateGroupTitle('u2', 'group-1', 'Nope'),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('allows a GM to remove a group member', async () => {
    prisma.conversation.findUnique.mockResolvedValue({
      id: 'group-1',
      type: 'GROUP',
      members: [
        { userId: 'gm', role: 'MEMBER' },
        { userId: 'u2', role: 'MEMBER' },
      ],
    });
    prisma.user.findUnique.mockResolvedValue({
      id: 'gm',
      email: null,
      phone: 'kkgm',
      role: 'GM',
    });
    prisma.conversationMember.delete.mockResolvedValue({ id: 'member-2' });
    prisma.conversation.update.mockResolvedValue({
      id: 'group-1',
      type: 'GROUP',
      members: [],
    });

    await service.removeGroupMember('gm', 'group-1', 'u2');

    expect(prisma.conversationMember.delete).toHaveBeenCalledWith({
      where: {
        conversationId_userId: { conversationId: 'group-1', userId: 'u2' },
      },
    });
  });

  it('allows a regular member to leave a group', async () => {
    prisma.conversation.findUnique.mockResolvedValue({
      id: 'group-1',
      type: 'GROUP',
      members: [{ userId: 'u2', role: 'MEMBER' }],
    });
    prisma.conversationMember.delete.mockResolvedValue({ id: 'member-2' });

    await service.leaveGroup('u2', 'group-1');

    expect(prisma.conversationMember.delete).toHaveBeenCalledWith({
      where: {
        conversationId_userId: { conversationId: 'group-1', userId: 'u2' },
      },
    });
  });

  it('rejects owner leaving without dissolving the group', async () => {
    prisma.conversation.findUnique.mockResolvedValue({
      id: 'group-1',
      type: 'GROUP',
      members: [{ userId: 'u1', role: 'OWNER' }],
    });

    await expect(service.leaveGroup('u1', 'group-1')).rejects.toBeInstanceOf(
      ForbiddenException,
    );
  });
});
