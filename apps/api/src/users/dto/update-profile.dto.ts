import { IsOptional, IsString, IsUrl } from 'class-validator';

export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  nickname?: string;

  @IsOptional()
  @IsUrl({ require_tld: false })
  avatarUrl?: string;
}
