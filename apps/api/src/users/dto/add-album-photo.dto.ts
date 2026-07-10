import { IsOptional, IsString, IsUrl } from 'class-validator';

export class AddAlbumPhotoDto {
  @IsUrl({ require_tld: false })
  url!: string;

  @IsOptional()
  @IsString()
  caption?: string;
}
