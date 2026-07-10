import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../common/current-user.decorator';
import type { AuthUser } from '../common/current-user.decorator';
import { ConversationsService } from './conversations.service';
import { CreateDirectConversationDto } from './dto/create-direct-conversation.dto';
import { CreateGroupConversationDto } from './dto/create-group-conversation.dto';
import { UpdateGroupMembersDto } from './dto/update-group-members.dto';
import { UpdateGroupTitleDto } from './dto/update-group-title.dto';

@UseGuards(JwtAuthGuard)
@Controller('conversations')
export class ConversationsController {
  constructor(private readonly conversationsService: ConversationsService) {}

  @Post('direct')
  createDirect(
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateDirectConversationDto,
  ) {
    return this.conversationsService.createDirect(user.id, dto.userId);
  }

  @Post('group')
  createGroup(
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateGroupConversationDto,
  ) {
    return this.conversationsService.createGroup(user.id, dto);
  }

  @Get()
  list(@CurrentUser() user: AuthUser) {
    return this.conversationsService.list(user.id);
  }

  @Get(':id')
  getOne(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.conversationsService.getOne(user.id, id);
  }

  @Patch(':id/group-title')
  updateGroupTitle(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateGroupTitleDto,
  ) {
    return this.conversationsService.updateGroupTitle(user.id, id, dto.title);
  }

  @Post(':id/group-members')
  addGroupMembers(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateGroupMembersDto,
  ) {
    return this.conversationsService.addGroupMembers(
      user.id,
      id,
      dto.memberIds,
    );
  }

  @Delete(':id/group-members/:userId')
  removeGroupMember(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('userId') userId: string,
  ) {
    return this.conversationsService.removeGroupMember(user.id, id, userId);
  }

  @Post(':id/leave')
  leaveGroup(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.conversationsService.leaveGroup(user.id, id);
  }

  @Delete(':id')
  deleteGroup(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.conversationsService.deleteGroup(user.id, id);
  }
}
