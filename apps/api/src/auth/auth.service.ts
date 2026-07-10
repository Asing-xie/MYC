import { ConflictException, ForbiddenException, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { User } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuthDto } from './dto/auth.dto';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
  ) {}

  async register(dto: AuthDto) {
    return this.registerWithRole(dto, 'USER');
  }

  async registerGm(dto: AuthDto, bootstrapToken?: string) {
    const expectedToken = process.env.GM_BOOTSTRAP_TOKEN;
    if (!expectedToken || bootstrapToken !== expectedToken) {
      throw new ForbiddenException('Invalid GM bootstrap token');
    }
    return this.registerWithRole(dto, 'GM');
  }

  private async registerWithRole(dto: AuthDto, role: 'USER' | 'GM') {
    const identity = this.normalizeIdentity(dto.identity);
    const existing = await this.prisma.user.findFirst({
      where: this.identityWhere(identity),
    });
    if (existing) {
      throw new ConflictException('Identity already exists');
    }

    const passwordHash = await bcrypt.hash(dto.password, 10);
    const user = await this.prisma.user.create({
      data: {
        email: identity.kind === 'email' ? identity.value : undefined,
        phone: identity.kind === 'phone' ? identity.value : undefined,
        nickname: dto.nickname?.trim() || this.defaultNickname(identity.value),
        passwordHash,
        role,
      },
    });

    return this.toAuthResponse(user);
  }

  async login(dto: AuthDto) {
    const identity = this.normalizeIdentity(dto.identity);
    const user = await this.prisma.user.findFirst({
      where: this.identityWhere(identity),
    });
    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const valid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!valid) {
      throw new UnauthorizedException('Invalid credentials');
    }

    return this.toAuthResponse(user);
  }

  private async toAuthResponse(user: User) {
    const payload = { id: user.id, email: user.email, phone: user.phone };
    const accessToken = await this.jwtService.signAsync(payload);
    return {
      accessToken,
      user: this.safeUser(user),
    };
  }

  private normalizeIdentity(identity: string): { kind: 'email' | 'phone'; value: string } {
    const value = identity.trim().toLowerCase();
    return value.includes('@') ? { kind: 'email', value } : { kind: 'phone', value };
  }

  private identityWhere(identity: { kind: 'email' | 'phone'; value: string }) {
    return identity.kind === 'email' ? { email: identity.value } : { phone: identity.value };
  }

  private defaultNickname(identity: string) {
    return identity.includes('@') ? identity.split('@')[0] : `user_${identity.slice(-4)}`;
  }

  private safeUser(user: User) {
    const { passwordHash: _passwordHash, ...safe } = user;
    return safe;
  }
}
