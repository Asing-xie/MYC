import { IsString, MinLength } from 'class-validator';

export class UpdateGroupTitleDto {
  @IsString()
  @MinLength(1)
  title!: string;
}
