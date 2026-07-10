import { UsersService } from './users.service';
import { PrismaService } from '../prisma/prisma.service';

describe('UsersService', () => {
  let service: UsersService;
  let prisma: {
    user: { findUniqueOrThrow: jest.Mock; update: jest.Mock; findMany: jest.Mock };
    userAlbumPhoto: { findMany: jest.Mock; create: jest.Mock };
  };

  beforeEach(() => {
    prisma = {
      user: {
        findUniqueOrThrow: jest.fn(),
        update: jest.fn(),
        findMany: jest.fn(),
      },
      userAlbumPhoto: {
        findMany: jest.fn(),
        create: jest.fn(),
      },
    };
    service = new UsersService(prisma as unknown as PrismaService);
  });

  it('returns a public user profile including signature', async () => {
    prisma.user.findUniqueOrThrow.mockResolvedValue({
      id: 'u1',
      nickname: 'Alice',
      signature: 'hello',
    });

    const user = await service.profile('u1');

    expect(user.signature).toBe('hello');
    expect(prisma.user.findUniqueOrThrow).toHaveBeenCalledWith({
      where: { id: 'u1' },
      select: expect.objectContaining({ signature: true }),
    });
  });

  it('updates nickname avatar and signature', async () => {
    prisma.user.update.mockResolvedValue({
      id: 'u1',
      nickname: 'Alice 2',
      avatarUrl: 'https://example.com/a.png',
      signature: 'new bio',
    });

    const user = await service.updateMe('u1', {
      nickname: 'Alice 2',
      avatarUrl: 'https://example.com/a.png',
      signature: 'new bio',
    });

    expect(user.signature).toBe('new bio');
    expect(prisma.user.update).toHaveBeenCalledWith({
      where: { id: 'u1' },
      data: {
        nickname: 'Alice 2',
        avatarUrl: 'https://example.com/a.png',
        signature: 'new bio',
      },
      select: expect.objectContaining({ signature: true }),
    });
  });

  it('adds and lists album photos', async () => {
    prisma.userAlbumPhoto.create.mockResolvedValue({ id: 'p1', ownerId: 'u1', url: 'https://example.com/p.png' });
    prisma.userAlbumPhoto.findMany.mockResolvedValue([{ id: 'p1', url: 'https://example.com/p.png' }]);

    await service.addAlbumPhoto('u1', { url: 'https://example.com/p.png' });
    const photos = await service.albumPhotos('u1');

    expect(photos).toHaveLength(1);
    expect(prisma.userAlbumPhoto.create).toHaveBeenCalledWith({
      data: { ownerId: 'u1', url: 'https://example.com/p.png', caption: undefined },
    });
    expect(prisma.userAlbumPhoto.findMany).toHaveBeenCalledWith({
      where: { ownerId: 'u1' },
      orderBy: { createdAt: 'desc' },
      take: 60,
    });
  });
});
