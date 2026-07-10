import { Body, Controller, Get, Post, Query, UploadedFile, UseGuards, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../common/current-user.decorator';
import type { AuthUser } from '../common/current-user.decorator';
import { CreateUploadDto } from './dto/create-upload.dto';
import { UploadsService } from './uploads.service';

@UseGuards(JwtAuthGuard)
@Controller('uploads')
export class UploadsController {
  constructor(private readonly uploadsService: UploadsService) {}

  @Get('config')
  config() {
    return this.uploadsService.cosConfig();
  }

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateUploadDto) {
    return this.uploadsService.create(user.id, dto);
  }

  @Post('file')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 20 * 1024 * 1024 } }))
  uploadFile(
    @CurrentUser() user: AuthUser,
    @Query('type') type: 'IMAGE' | 'VOICE' = 'IMAGE',
    @UploadedFile() file?: Express.Multer.File,
  ) {
    return this.uploadsService.uploadFile(user.id, type, file);
  }
}
