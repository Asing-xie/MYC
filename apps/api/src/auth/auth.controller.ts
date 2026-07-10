import { Body, Controller, Headers, Post } from '@nestjs/common';
import { AuthService } from './auth.service';
import { AuthDto } from './dto/auth.dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  register(@Body() dto: AuthDto) {
    return this.authService.register(dto);
  }

  @Post('gm/register')
  registerGm(@Body() dto: AuthDto, @Headers('x-gm-bootstrap-token') bootstrapToken?: string) {
    return this.authService.registerGm(dto, bootstrapToken);
  }

  @Post('login')
  login(@Body() dto: AuthDto) {
    return this.authService.login(dto);
  }
}
