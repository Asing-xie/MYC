import { IsArray, IsIn, IsInt, IsOptional, IsString, Min } from 'class-validator';

export class SendMessageDto {
  @IsString()
  conversationId!: string;

  @IsIn(['TEXT', 'IMAGE', 'VOICE'])
  type!: 'TEXT' | 'IMAGE' | 'VOICE';

  @IsOptional()
  @IsString()
  content?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  durationMs?: number;

  @IsOptional()
  @IsArray()
  attachmentIds?: string[];
}
