import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../common/current-user.decorator';
import type { AuthUser } from '../common/current-user.decorator';
import { SendMessageDto } from './dto/send-message.dto';
import { MessagesService } from './messages.service';

@UseGuards(JwtAuthGuard)
@Controller('messages')
export class MessagesController {
  constructor(private readonly messagesService: MessagesService) {}

  @Get(':conversationId')
  list(
    @CurrentUser() user: AuthUser,
    @Param('conversationId') conversationId: string,
    @Query('take') take?: string,
  ) {
    return this.messagesService.list(user.id, conversationId, take ? Number(take) : 50);
  }

  @Post()
  send(@CurrentUser() user: AuthUser, @Body() dto: SendMessageDto) {
    return this.messagesService.send(user.id, dto);
  }
}
