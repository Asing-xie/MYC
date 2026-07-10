import { ConflictException, ForbiddenException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { AuthService } from './auth.service';
import { PrismaService } from '../prisma/prisma.service';

describe('AuthService', () => {
  let service: AuthService;
  let prisma: {
    user: {
      findFirst: jest.Mock;
      findUnique: jest.Mock;
      create: jest.Mock;
    };
  };

  beforeEach(() => {
    delete process.env.GM_BOOTSTRAP_TOKEN;
    prisma = {
      user: {
        findFirst: jest.fn(),
        findUnique: jest.fn(),
        create: jest.fn(),
      },
    };
    service = new AuthService(
      prisma as unknown as PrismaService,
      { signAsync: jest.fn().mockResolvedValue('jwt-token') } as unknown as JwtService,
    );
  });

  it('registers a user with email and returns a token', async () => {
    prisma.user.findFirst.mockResolvedValue(null);
    prisma.user.create.mockResolvedValue({
      id: 'user-1',
      email: 'a@example.com',
      phone: null,
      nickname: 'Alice',
      avatarUrl: null,
      passwordHash: 'hash',
      createdAt: new Date(),
      updatedAt: new Date(),
      role: 'USER',
    });

    const result = await service.register({
      identity: 'a@example.com',
      password: 'secret123',
      nickname: 'Alice',
    });

    expect(prisma.user.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          email: 'a@example.com',
          nickname: 'Alice',
        }),
      }),
    );
    expect(result.accessToken).toBe('jwt-token');
    expect(result.user.passwordHash).toBeUndefined();
    expect(result.user.role).toBe('USER');
  });

  it('registers a GM user when the bootstrap token matches', async () => {
    process.env.GM_BOOTSTRAP_TOKEN = 'bootstrap-secret';
    prisma.user.findFirst.mockResolvedValue(null);
    prisma.user.create.mockResolvedValue({
      id: 'gm-1',
      email: null,
      phone: 'kkgm',
      nickname: 'kkgm',
      avatarUrl: null,
      passwordHash: 'hash',
      role: 'GM',
      createdAt: new Date(),
      updatedAt: new Date(),
    });

    const result = await service.registerGm(
      {
        identity: 'kkgm',
        password: 'secret123',
        nickname: 'kkgm',
      },
      'bootstrap-secret',
    );

    expect(prisma.user.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          phone: 'kkgm',
          nickname: 'kkgm',
          role: 'GM',
        }),
      }),
    );
    expect(result.user.role).toBe('GM');
  });

  it('rejects GM registration without the bootstrap token', async () => {
    process.env.GM_BOOTSTRAP_TOKEN = 'bootstrap-secret';

    await expect(
      service.registerGm(
        {
          identity: 'kkgm',
          password: 'secret123',
          nickname: 'kkgm',
        },
        'wrong',
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('rejects duplicate email or phone identities', async () => {
    prisma.user.findFirst.mockResolvedValue({ id: 'existing' });

    await expect(
      service.register({
        identity: 'a@example.com',
        password: 'secret123',
      }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('rejects login with an invalid password', async () => {
    prisma.user.findFirst.mockResolvedValue({
      id: 'user-1',
      email: 'a@example.com',
      phone: null,
      nickname: 'Alice',
      avatarUrl: null,
      passwordHash: '$2b$10$XBrJ3Bxm7tdrTc6IV3EQAevdUc3KeiU2kcm8K7In/T2Bqub03bS1W',
      createdAt: new Date(),
      updatedAt: new Date(),
    });

    await expect(
      service.login({
        identity: 'a@example.com',
        password: 'wrong-password',
      }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });
});
