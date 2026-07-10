import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../common/current-user.decorator';
import type { AuthUser } from '../common/current-user.decorator';
import { ConversationsService } from './conversations.service';
import { CreateDirectConversationDto } from './dto/create-direct-conversation.dto';

@UseGuards(JwtAuthGuard)
@Controller('conversations')
export class ConversationsController {
  constructor(private readonly conversationsService: ConversationsService) {}

  @Post('direct')
  createDirect(@CurrentUser() user: AuthUser, @Body() dto: CreateDirectConversationDto) {
    return this.conversationsService.createDirect(user.id, dto.userId);
  }

  @Get()
  list(@CurrentUser() user: AuthUser) {
    return this.conversationsService.list(user.id);
  }
}
