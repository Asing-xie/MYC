import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { ContactsService } from './contacts.service';
import { PrismaService } from '../prisma/prisma.service';

describe('ContactsService', () => {
  let service: ContactsService;
  let prisma: {
    contact: {
      findFirst: jest.Mock;
      findMany: jest.Mock;
      findUnique: jest.Mock;
      create: jest.Mock;
      update: jest.Mock;
      delete: jest.Mock;
    };
    conversation: {
      findFirst: jest.Mock;
      create: jest.Mock;
    };
  };

  const includeUsers = {
    requester: { select: { id: true, email: true, phone: true, nickname: true, avatarUrl: true } },
    addressee: { select: { id: true, email: true, phone: true, nickname: true, avatarUrl: true } },
  };

  beforeEach(() => {
    prisma = {
      contact: {
        findFirst: jest.fn(),
        findMany: jest.fn(),
        findUnique: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
      },
      conversation: {
        findFirst: jest.fn(),
        create: jest.fn(),
      },
    };
    service = new ContactsService(prisma as unknown as PrismaService);
  });

  it('creates a pending friend request', async () => {
    prisma.contact.findFirst.mockResolvedValue(null);
    prisma.contact.create.mockResolvedValue({
      id: 'contact-1',
      requesterId: 'u1',
      addresseeId: 'u2',
      status: 'PENDING',
    });

    const contact = await service.create('u1', 'u2');

    expect(contact.status).toBe('PENDING');
    expect(prisma.contact.create).toHaveBeenCalledWith({
      data: { requesterId: 'u1', addresseeId: 'u2', status: 'PENDING' },
      include: includeUsers,
    });
  });

  it('returns an existing pending or accepted relation instead of duplicating it', async () => {
    prisma.contact.findFirst.mockResolvedValue({
      id: 'contact-1',
      requesterId: 'u2',
      addresseeId: 'u1',
      status: 'PENDING',
    });

    const contact = await service.create('u1', 'u2');

    expect(contact.id).toBe('contact-1');
    expect(prisma.contact.create).not.toHaveBeenCalled();
  });

  it('rejects sending a request to yourself', async () => {
    await expect(service.create('u1', 'u1')).rejects.toBeInstanceOf(BadRequestException);
  });

  it('lists accepted contacts for either side of the relation', async () => {
    prisma.contact.findMany.mockResolvedValue([{ id: 'contact-1', status: 'ACCEPTED' }]);

    const contacts = await service.list('u1');

    expect(contacts).toHaveLength(1);
    expect(prisma.contact.findMany).toHaveBeenCalledWith({
      where: {
        status: 'ACCEPTED',
        OR: [{ requesterId: 'u1' }, { addresseeId: 'u1' }],
      },
      include: includeUsers,
      orderBy: { updatedAt: 'desc' },
    });
  });

  it('lists incoming pending requests', async () => {
    prisma.contact.findMany.mockResolvedValue([{ id: 'contact-1', status: 'PENDING' }]);

    await service.incomingRequests('u2');

    expect(prisma.contact.findMany).toHaveBeenCalledWith({
      where: { addresseeId: 'u2', status: 'PENDING' },
      include: includeUsers,
      orderBy: { updatedAt: 'desc' },
    });
  });

  it('lists outgoing pending requests', async () => {
    prisma.contact.findMany.mockResolvedValue([{ id: 'contact-1', status: 'PENDING' }]);

    await service.outgoingRequests('u1');

    expect(prisma.contact.findMany).toHaveBeenCalledWith({
      where: { requesterId: 'u1', status: 'PENDING' },
      include: includeUsers,
      orderBy: { updatedAt: 'desc' },
    });
  });

  it('allows only the addressee to accept a pending request', async () => {
    prisma.contact.findUnique.mockResolvedValue({
      id: 'contact-1',
      requesterId: 'u1',
      addresseeId: 'u2',
      status: 'PENDING',
    });
    prisma.contact.update.mockResolvedValue({ id: 'contact-1', status: 'ACCEPTED' });
    prisma.conversation.findFirst.mockResolvedValue(null);
    prisma.conversation.create.mockResolvedValue({ id: 'conversation-1' });

    const contact = await service.accept('u2', 'contact-1');

    expect(contact.status).toBe('ACCEPTED');
    expect(prisma.contact.update).toHaveBeenCalledWith({
      where: { id: 'contact-1' },
      data: { status: 'ACCEPTED' },
      include: includeUsers,
    });
    expect(prisma.conversation.create).toHaveBeenCalledWith({
      data: {
        type: 'DIRECT',
        members: {
          create: [{ userId: 'u1' }, { userId: 'u2' }],
        },
      },
    });
  });

  it('does not create a duplicate direct conversation when accepting a request', async () => {
    prisma.contact.findUnique.mockResolvedValue({
      id: 'contact-1',
      requesterId: 'u1',
      addresseeId: 'u2',
      status: 'PENDING',
    });
    prisma.contact.update.mockResolvedValue({ id: 'contact-1', status: 'ACCEPTED' });
    prisma.conversation.findFirst.mockResolvedValue({ id: 'conversation-1' });

    await service.accept('u2', 'contact-1');

    expect(prisma.conversation.create).not.toHaveBeenCalled();
  });

  it('rejects accept when the current user is not the addressee', async () => {
    prisma.contact.findUnique.mockResolvedValue({
      id: 'contact-1',
      requesterId: 'u1',
      addresseeId: 'u2',
      status: 'PENDING',
    });

    await expect(service.accept('u3', 'contact-1')).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('deletes a pending request when either side rejects it', async () => {
    prisma.contact.findUnique.mockResolvedValue({
      id: 'contact-1',
      requesterId: 'u1',
      addresseeId: 'u2',
      status: 'PENDING',
    });
    prisma.contact.delete.mockResolvedValue({ id: 'contact-1' });

    await service.reject('u2', 'contact-1');

    expect(prisma.contact.delete).toHaveBeenCalledWith({ where: { id: 'contact-1' } });
  });

  it('returns not found for missing requests', async () => {
    prisma.contact.findUnique.mockResolvedValue(null);

    await expect(service.accept('u2', 'missing')).rejects.toBeInstanceOf(NotFoundException);
  });
});
