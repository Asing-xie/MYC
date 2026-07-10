import { ArrayMinSize, IsArray, IsOptional, IsString } from 'class-validator';

export class CreateGroupConversationDto {
  @IsOptional()
  @IsString()
  title?: string;

  @IsArray()
  @ArrayMinSize(2)
  @IsString({ each: true })
  memberIds!: string[];
}
