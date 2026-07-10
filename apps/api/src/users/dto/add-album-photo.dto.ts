import { IsIn, IsInt, IsOptional, IsString, IsUrl, Min } from 'class-validator';

export class AddAlbumPhotoDto {
  @IsUrl({ require_tld: false })
  url!: string;

  @IsOptional()
  @IsString()
  caption?: string;

  @IsOptional()
  @IsIn(['IMAGE', 'VIDEO'])
  type?: 'IMAGE' | 'VIDEO';

  @IsOptional()
  @IsInt()
  @Min(0)
  durationMs?: number;
}
