import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../common/current-user.decorator';
import type { AuthUser } from '../common/current-user.decorator';
import { ContactsService } from './contacts.service';
import { CreateContactDto } from './dto/create-contact.dto';

@UseGuards(JwtAuthGuard)
@Controller('contacts')
export class ContactsController {
  constructor(private readonly contactsService: ContactsService) {}

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateContactDto) {
    return this.contactsService.create(user.id, dto.userId);
  }

  @Get()
  list(@CurrentUser() user: AuthUser) {
    return this.contactsService.list(user.id);
  }

  @Get('requests/incoming')
  incomingRequests(@CurrentUser() user: AuthUser) {
    return this.contactsService.incomingRequests(user.id);
  }

  @Get('requests/outgoing')
  outgoingRequests(@CurrentUser() user: AuthUser) {
    return this.contactsService.outgoingRequests(user.id);
  }

  @Post(':id/accept')
  accept(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.contactsService.accept(user.id, id);
  }

  @Post(':id/reject')
  reject(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.contactsService.reject(user.id, id);
  }
}
