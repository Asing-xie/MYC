import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateGroupConversationDto } from './dto/create-group-conversation.dto';

@Injectable()
export class ConversationsService {
  constructor(private readonly prisma: PrismaService) {}

  private readonly userSelect = {
    id: true,
    nickname: true,
    avatarUrl: true,
    email: true,
    phone: true,
    signature: true,
    role: true,
  } as const;

  private readonly conversationInclude = {
    members: {
      include: {
        user: { select: this.userSelect },
      },
    },
  } as const;

  async createDirect(currentUserId: string, otherUserId: string) {
    if (currentUserId === otherUserId) {
      throw new BadRequestException('Cannot chat with yourself');
    }

    const contact = await this.prisma.contact.findFirst({
      where: {
        status: 'ACCEPTED',
        OR: [
          { requesterId: currentUserId, addresseeId: otherUserId },
          { requesterId: otherUserId, addresseeId: currentUserId },
        ],
      },
    });
    if (!contact && !(await this.isGmUser(currentUserId))) {
      throw new ForbiddenException(
        'You must be friends before starting a chat',
      );
    }

    const existing = await this.prisma.conversation.findFirst({
      where: {
        type: 'DIRECT',
        members: {
          every: {
            userId: { in: [currentUserId, otherUserId] },
          },
        },
      },
      include: {
        members: {
          include: {
            user: { select: this.userSelect },
          },
        },
      },
    });

    if (existing && existing.members.length === 2) {
      return existing;
    }

    return this.prisma.conversation.create({
      data: {
        type: 'DIRECT',
        members: {
          create: [{ userId: currentUserId }, { userId: otherUserId }],
        },
      },
      include: this.conversationInclude,
    });
  }

  async createGroup(currentUserId: string, dto: CreateGroupConversationDto) {
    const memberIds = [
      ...new Set(dto.memberIds.filter((id) => id !== currentUserId)),
    ];
    if (memberIds.length < 2) {
      throw new BadRequestException(
        'Group chat requires at least two other members',
      );
    }

    if (!(await this.isGmUser(currentUserId))) {
      const acceptedContacts = await this.prisma.contact.findMany({
        where: {
          status: 'ACCEPTED',
          OR: memberIds.flatMap((memberId) => [
            { requesterId: currentUserId, addresseeId: memberId },
            { requesterId: memberId, addresseeId: currentUserId },
          ]),
        },
        select: { requesterId: true, addresseeId: true },
      });
      const acceptedMemberIds = new Set(
        acceptedContacts.map((contact) =>
          contact.requesterId === currentUserId
            ? contact.addresseeId
            : contact.requesterId,
        ),
      );
      const missing = memberIds.filter(
        (memberId) => !acceptedMemberIds.has(memberId),
      );
      if (missing.length > 0) {
        throw new ForbiddenException('Group members must be your friends');
      }
    }

    const users = await this.prisma.user.findMany({
      where: { id: { in: [currentUserId, ...memberIds] } },
      select: this.userSelect,
    });
    if (users.length !== memberIds.length + 1) {
      throw new BadRequestException('Some group members do not exist');
    }

    const title =
      dto.title?.trim() ||
      users
        .map((user) => user.nickname)
        .slice(0, 4)
        .join(', ');
    return this.prisma.conversation.create({
      data: {
        type: 'GROUP',
        title,
        members: {
          create: [
            { userId: currentUserId, role: 'OWNER' },
            ...memberIds.map((userId) => ({ userId, role: 'MEMBER' as const })),
          ],
        },
      },
      include: this.conversationInclude,
    });
  }

  async getOne(userId: string, conversationId: string) {
    const conversation = await this.prisma.conversation.findUnique({
      where: { id: conversationId },
      include: this.conversationInclude,
    });
    if (!conversation) {
      throw new NotFoundException('Conversation not found');
    }
    if (
      !conversation.members.some((member) => member.userId === userId) &&
      !(await this.isGmUser(userId))
    ) {
      throw new ForbiddenException('Not a conversation member');
    }
    return conversation;
  }

  async updateGroupTitle(
    userId: string,
    conversationId: string,
    title: string,
  ) {
    const conversation = await this.loadGroupConversation(conversationId);
    await this.assertGroupManager(userId, conversation);
    const trimmedTitle = title.trim();
    if (!trimmedTitle) {
      throw new BadRequestException('Group name is required');
    }
    return this.prisma.conversation.update({
      where: { id: conversationId },
      data: { title: trimmedTitle },
      include: this.conversationInclude,
    });
  }

  async addGroupMembers(
    userId: string,
    conversationId: string,
    memberIds: string[],
  ) {
    const conversation = await this.loadGroupConversation(conversationId);
    await this.assertGroupManager(userId, conversation);
    const uniqueMemberIds = [...new Set(memberIds)]
      .filter((memberId) => memberId !== userId)
      .filter(
        (memberId) =>
          !conversation.members.some((member) => member.userId === memberId),
      );
    if (uniqueMemberIds.length === 0) {
      return this.getOne(userId, conversationId);
    }

    if (!(await this.isGmUser(userId))) {
      await this.assertAcceptedContacts(userId, uniqueMemberIds);
    }

    const users = await this.prisma.user.findMany({
      where: { id: { in: uniqueMemberIds } },
      select: { id: true },
    });
    if (users.length !== uniqueMemberIds.length) {
      throw new BadRequestException('Some group members do not exist');
    }

    await this.prisma.conversationMember.createMany({
      data: uniqueMemberIds.map((memberId) => ({
        conversationId,
        userId: memberId,
        role: 'MEMBER' as const,
      })),
      skipDuplicates: true,
    });

    return this.prisma.conversation.update({
      where: { id: conversationId },
      data: { updatedAt: new Date() },
      include: this.conversationInclude,
    });
  }

  async removeGroupMember(
    userId: string,
    conversationId: string,
    targetUserId: string,
  ) {
    const conversation = await this.loadGroupConversation(conversationId);
    await this.assertGroupManager(userId, conversation);
    if (userId === targetUserId) {
      throw new BadRequestException('Use leave group instead');
    }

    const target = conversation.members.find(
      (member) => member.userId === targetUserId,
    );
    if (!target) {
      throw new NotFoundException('Group member not found');
    }
    if (target.role === 'OWNER') {
      throw new ForbiddenException('Group owner cannot be removed');
    }

    await this.prisma.conversationMember.delete({
      where: {
        conversationId_userId: { conversationId, userId: targetUserId },
      },
    });
    return this.prisma.conversation.update({
      where: { id: conversationId },
      data: { updatedAt: new Date() },
      include: this.conversationInclude,
    });
  }

  async leaveGroup(userId: string, conversationId: string) {
    const conversation = await this.loadGroupConversation(conversationId);
    const membership = conversation.members.find(
      (member) => member.userId === userId,
    );
    if (!membership) {
      throw new ForbiddenException('Not a group member');
    }
    if (membership.role === 'OWNER') {
      throw new ForbiddenException('Group owner must dissolve the group');
    }
    await this.prisma.conversationMember.delete({
      where: { conversationId_userId: { conversationId, userId } },
    });
    return { ok: true };
  }

  async deleteGroup(userId: string, conversationId: string) {
    const conversation = await this.loadGroupConversation(conversationId);
    await this.assertGroupManager(userId, conversation);
    await this.prisma.conversation.delete({ where: { id: conversationId } });
    return { ok: true };
  }

  async list(userId: string) {
    const conversations = await this.prisma.conversation.findMany({
      where: { members: { some: { userId } } },
      include: {
        members: {
          include: {
            user: { select: this.userSelect },
          },
        },
        messages: {
          orderBy: { createdAt: 'desc' },
          take: 1,
          include: { attachments: true, receipts: true },
        },
      },
      orderBy: { updatedAt: 'desc' },
    });

    return Promise.all(
      conversations.map(async (conversation) => {
        const unread = await this.prisma.messageReceipt.count({
          where: {
            userId,
            readAt: null,
            message: {
              conversationId: conversation.id,
              senderId: { not: userId },
            },
          },
        });

        return {
          ...conversation,
          latestMessage: conversation.messages[0]
            ? this.withReadState(conversation.messages[0], userId)
            : null,
          unread,
          messages: undefined,
        };
      }),
    );
  }

  private async isGmUser(userId: string) {
    const identities = (process.env.GM_IDENTITIES ?? '')
      .split(',')
      .map((identity) => identity.trim().toLowerCase())
      .filter(Boolean);

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { email: true, phone: true, role: true },
    });
    if (!user) return false;
    if (user.role === 'GM') return true;
    if (identities.length === 0) return false;

    const email = user.email?.toLowerCase();
    const phone = user.phone?.toLowerCase();
    return Boolean(
      (email && identities.includes(email)) ||
      (phone && identities.includes(phone)),
    );
  }

  private async loadGroupConversation(conversationId: string) {
    const conversation = await this.prisma.conversation.findUnique({
      where: { id: conversationId },
      include: this.conversationInclude,
    });
    if (!conversation) {
      throw new NotFoundException('Conversation not found');
    }
    if (conversation.type !== 'GROUP') {
      throw new BadRequestException('Conversation is not a group');
    }
    return conversation;
  }

  private async assertGroupManager(
    userId: string,
    conversation: Awaited<
      ReturnType<ConversationsService['loadGroupConversation']>
    >,
  ) {
    const membership = conversation.members.find(
      (member) => member.userId === userId,
    );
    if (membership?.role === 'OWNER') return;
    if (await this.isGmUser(userId)) return;
    throw new ForbiddenException('Only the group owner can manage this group');
  }

  private async assertAcceptedContacts(userId: string, memberIds: string[]) {
    const acceptedContacts = await this.prisma.contact.findMany({
      where: {
        status: 'ACCEPTED',
        OR: memberIds.flatMap((memberId) => [
          { requesterId: userId, addresseeId: memberId },
          { requesterId: memberId, addresseeId: userId },
        ]),
      },
      select: { requesterId: true, addresseeId: true },
    });
    const acceptedMemberIds = new Set(
      acceptedContacts.map((contact) =>
        contact.requesterId === userId
          ? contact.addresseeId
          : contact.requesterId,
      ),
    );
    const missing = memberIds.filter(
      (memberId) => !acceptedMemberIds.has(memberId),
    );
    if (missing.length > 0) {
      throw new ForbiddenException('Group members must be your friends');
    }
  }

  private withReadState<
    T extends { senderId: string; receipts?: { readAt: Date | null }[] },
  >(message: T, userId: string) {
    return {
      ...message,
      readByOthers:
        message.senderId === userId &&
        (message.receipts ?? []).some((receipt) => receipt.readAt),
    };
  }
}
