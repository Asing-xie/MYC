import { IsArray, IsIn, IsOptional, IsString } from 'class-validator';

export class SendMessageDto {
  @IsString()
  conversationId!: string;

  @IsIn(['TEXT', 'IMAGE', 'VOICE'])
  type!: 'TEXT' | 'IMAGE' | 'VOICE';

  @IsOptional()
  @IsString()
  content?: string;

  @IsOptional()
  @IsArray()
  attachmentIds?: string[];
}
