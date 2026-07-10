import { Body, Controller, Get, Patch, Query, UseGuards } from '@nestjs/common';
import { CurrentUser } from '../common/current-user.decorator';
import type { AuthUser } from '../common/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { UsersService } from './users.service';

@UseGuards(JwtAuthGuard)
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me')
  me(@CurrentUser() user: AuthUser) {
    return this.usersService.me(user.id);
  }

  @Patch('me')
  updateMe(@CurrentUser() user: AuthUser, @Body() dto: UpdateProfileDto) {
    return this.usersService.updateMe(user.id, dto);
  }

  @Get('search')
  search(@CurrentUser() user: AuthUser, @Query('q') query = '') {
    return this.usersService.search(query, user.id);
  }
}
