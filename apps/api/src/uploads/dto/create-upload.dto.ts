import { IsIn, IsInt, IsOptional, IsString, IsUrl, Min } from 'class-validator';

export class CreateUploadDto {
  @IsIn(['IMAGE', 'VOICE', 'VIDEO'])
  type!: 'IMAGE' | 'VOICE' | 'VIDEO';

  @IsUrl({ require_tld: false })
  url!: string;

  @IsOptional()
  @IsString()
  key?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  size?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  duration?: number;
}
