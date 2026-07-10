import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ContactsService {
  constructor(private readonly prisma: PrismaService) {}

  private readonly includeUsers = {
    requester: { select: { id: true, email: true, phone: true, nickname: true, avatarUrl: true } },
    addressee: { select: { id: true, email: true, phone: true, nickname: true, avatarUrl: true } },
  };

  async create(requesterId: string, addresseeId: string) {
    if (requesterId === addresseeId) {
      throw new BadRequestException('Cannot add yourself');
    }

    const existing = await this.prisma.contact.findFirst({
      where: {
        OR: [
          { requesterId, addresseeId },
          { requesterId: addresseeId, addresseeId: requesterId },
        ],
      },
      include: this.includeUsers,
    });
    if (existing) return existing;

    return this.prisma.contact.create({
      data: { requesterId, addresseeId, status: 'PENDING' },
      include: this.includeUsers,
    });
  }

  async list(userId: string) {
    return this.prisma.contact.findMany({
      where: {
        status: 'ACCEPTED',
        OR: [{ requesterId: userId }, { addresseeId: userId }],
      },
      include: this.includeUsers,
      orderBy: { updatedAt: 'desc' },
    });
  }

  async incomingRequests(userId: string) {
    return this.prisma.contact.findMany({
      where: { addresseeId: userId, status: 'PENDING' },
      include: this.includeUsers,
      orderBy: { updatedAt: 'desc' },
    });
  }

  async outgoingRequests(userId: string) {
    return this.prisma.contact.findMany({
      where: { requesterId: userId, status: 'PENDING' },
      include: this.includeUsers,
      orderBy: { updatedAt: 'desc' },
    });
  }

  async accept(userId: string, contactId: string) {
    const contact = await this.findRequest(contactId);
    if (contact.addresseeId !== userId) {
      throw new ForbiddenException('Only the addressee can accept this request');
    }
    if (contact.status !== 'PENDING') {
      throw new BadRequestException('Request is not pending');
    }

    return this.prisma.contact.update({
      where: { id: contactId },
      data: { status: 'ACCEPTED' },
      include: this.includeUsers,
    });
  }

  async reject(userId: string, contactId: string) {
    const contact = await this.findRequest(contactId);
    if (contact.requesterId !== userId && contact.addresseeId !== userId) {
      throw new ForbiddenException('Only request participants can reject this request');
    }
    if (contact.status !== 'PENDING') {
      throw new BadRequestException('Request is not pending');
    }

    await this.prisma.contact.delete({ where: { id: contactId } });
    return { ok: true };
  }

  private async findRequest(contactId: string) {
    const contact = await this.prisma.contact.findUnique({ where: { id: contactId } });
    if (!contact) {
      throw new NotFoundException('Contact request not found');
    }
    return contact;
  }
}
