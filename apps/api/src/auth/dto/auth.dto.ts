import { IsOptional, IsString, MinLength } from 'class-validator';

export class AuthDto {
  @IsString()
  identity!: string;

  @IsString()
  @MinLength(6)
  password!: string;

  @IsOptional()
  @IsString()
  nickname?: string;
}
